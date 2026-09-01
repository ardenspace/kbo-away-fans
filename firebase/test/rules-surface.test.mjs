// Firestore 보안 규칙 — 규칙이 닫는 "표면"을 잰다.
//
// rules.test.mjs 가 문서 한 장의 모양(필드·문서 id·소유권)을 재는 데 비해, 이 파일은
// 그 모양을 우회하려는 경로를 공격한다: 통째로 쓰지 않고 부분 수정(update)으로
// 끼워 넣기, 삭제, 계약에 없는 경로, 목록·컬렉션 그룹 질의.
//
// 실행: npm --prefix firebase test  (run-rules-tests.sh 가 에뮬레이터를 감싼다)

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

import {
  OTHER_UID,
  OWNER_UID,
  asGuest,
  asUser,
  createTestEnv,
  likeDoc,
  paths,
  seed,
  stampDoc,
  stampIdOf,
  userDoc,
} from './helpers.mjs';

let env;
const SEED_STAMP = stampDoc();
const SEED_LIKE = likeDoc();

before(async () => {
  env = await createTestEnv();
});
after(async () => {
  await env?.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
  await seed(env, async (db) => {
    await setDoc(doc(db, paths.user(OWNER_UID)), userDoc());
    await setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP))), SEED_STAMP);
    await setDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId)), SEED_LIKE);
  });
});

describe('남의 문서에 대한 update·delete', () => {
  it('남의 문서를 지울 수 없다 (세 경로 · 인증·미인증 모두)', async () => {
    for (const db of [asUser(env, OTHER_UID), asGuest(env)]) {
      await assertFails(deleteDoc(doc(db, paths.user(OWNER_UID))));
      await assertFails(deleteDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP)))));
      await assertFails(deleteDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId))));
    }
  });

  it('남의 문서를 부분 수정할 수 없다 (세 경로 · 인증·미인증 모두)', async () => {
    for (const db of [asUser(env, OTHER_UID), asGuest(env)]) {
      await assertFails(updateDoc(doc(db, paths.user(OWNER_UID)), { nickname: '가로챔' }));
      await assertFails(
        updateDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP))), { gameDate: '2026-01-01' }),
      );
      await assertFails(
        updateDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId)), { category: 'cafe' }),
      );
    }
  });
});

describe('부분 수정(update)으로 화이트리스트를 우회할 수 있는가', () => {
  it('본인 문서라도 update 로 계약 밖 필드를 끼워 넣을 수 없다', async () => {
    const db = asUser(env, OWNER_UID);

    await assertFails(updateDoc(doc(db, paths.user(OWNER_UID)), { lat: 37.512 }));
    await assertFails(updateDoc(doc(db, paths.user(OWNER_UID)), { lastSpot: '37.512,127.072' }));
    await assertFails(
      updateDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP))), { lng: 127.072 }),
    );
    await assertFails(
      updateDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId)), { spot: [37.5, 127.0] }),
    );
  });

  it('칸 요약 안쪽(중첩 map)에도 계약 밖 키를 넣을 수 없다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(
      updateDoc(doc(db, paths.user(OWNER_UID)), {
        'board.jamsil_lg': { count: 1, tier: 'first', lat: 37.512 },
      }),
    );
  });

  it('칸 요약을 update 로 갱신할 때도 등급 사다리가 강제된다', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));

    await assertFails(updateDoc(ref, { 'board.jamsil_lg': { count: 1, tier: 'master' } }));
    await assertFails(updateDoc(ref, { 'board.jamsil_lg': { count: 10, tier: 'first' } }));
    await assertSucceeds(updateDoc(ref, { 'board.jamsil_lg': { count: 1, tier: 'first' } }));
  });

  it('필수 필드를 update 로 지울 수 없다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(updateDoc(doc(db, paths.user(OWNER_UID)), { nickname: '' }));
    await assertFails(updateDoc(doc(db, paths.user(OWNER_UID)), { nickname: 'x'.repeat(21) }));
  });
});

describe('문서 id 계약을 update 로 어긋나게 할 수 있는가', () => {
  it('기존 도장의 stadiumId·gameId 만 바꿔 id 와 어긋나게 할 수 없다', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP)));

    await assertFails(updateDoc(ref, { gameId: 'g-other-1' }));
    await assertFails(updateDoc(ref, { stadiumId: 'sajik', homeTeamId: 'lotte' }));
  });

  it("gameId 에 '_' 를 넣어 id 를 두 갈래로 읽히게 할 수 없다", async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'daejeon', homeTeamId: 'hanwha', gameId: 'g_1' });
    assert.equal(stampIdOf(stamp), 'daejeon_g_1');
    await assertFails(setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp));
  });

  it('좋아요 문서 id 는 본문 placeId 와 같아야 한다', async () => {
    const db = asUser(env, OWNER_UID);
    const like = likeDoc({ placeId: 'sajik-milmyeon', stadiumId: 'sajik' });

    await assertFails(setDoc(doc(db, paths.like(OWNER_UID, 'other-place')), like));
    await assertFails(
      setDoc(doc(db, paths.like(OWNER_UID, 'Sajik-Milmyeon')), likeDoc({ placeId: 'Sajik-Milmyeon' })),
    );
    await assertSucceeds(setDoc(doc(db, paths.like(OWNER_UID, like.placeId)), like));
  });
});

describe('규칙에 열거되지 않은 경로', () => {
  it('본인 계정 아래여도 계약에 없는 하위 컬렉션은 거부된다', async () => {
    const db = asUser(env, OWNER_UID);

    await assertFails(setDoc(doc(db, `users/${OWNER_UID}/spots/s1`), { at: 'x' }));
    await assertFails(
      setDoc(doc(db, `users/${OWNER_UID}/stamps/${stampIdOf(SEED_STAMP)}/trail/t1`), { at: 'x' }),
    );
  });

  it('최상위 stamps·likes 컬렉션은 존재하지 않는다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(setDoc(doc(db, 'stamps/s1'), stampDoc()));
    await assertFails(setDoc(doc(db, 'likes/l1'), likeDoc()));
  });
});

describe('목록 질의', () => {
  it('본인 하위 컬렉션 질의는 허용된다 (인덱스 계약이 노리는 질의 그대로)', async () => {
    const db = asUser(env, OWNER_UID);

    await assertSucceeds(
      getDocs(
        query(
          collection(db, `users/${OWNER_UID}/stamps`),
          where('stadiumId', '==', 'jamsil'),
          where('homeTeamId', '==', 'lg'),
          orderBy('gameDate', 'desc'),
        ),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(
          collection(db, `users/${OWNER_UID}/likes`),
          where('category', '==', 'food'),
          orderBy('likedAt', 'desc'),
        ),
      ),
    );
  });

  it('남의 하위 컬렉션 질의와 users 컬렉션 훑기는 거부된다', async () => {
    const other = asUser(env, OTHER_UID);
    await assertFails(getDocs(collection(other, `users/${OWNER_UID}/stamps`)));
    await assertFails(getDocs(collection(other, `users/${OWNER_UID}/likes`)));
    await assertFails(getDocs(collection(other, 'users')));
    await assertFails(getDocs(collection(asUser(env, OWNER_UID), 'users')));
  });

  it('컬렉션 그룹 질의는 본인 것이라도 거부된다 (중첩 match 는 그룹 질의에 걸리지 않는다)', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(getDocs(collectionGroup(db, 'stamps')));
    await assertFails(getDocs(collectionGroup(db, 'likes')));
  });
});
