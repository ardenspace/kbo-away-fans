// Firestore 보안 규칙 단위 테스트 — 에뮬레이터 위에서 실제 규칙 파일을 평가한다.
//
// 실행: npm --prefix firebase test  (run-rules-tests.sh 가 에뮬레이터를 감싼다)

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  runTransaction,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

import {
  CELL_IDS,
  OTHER_UID,
  OWNER_UID,
  asGuest,
  asUser,
  boardCell,
  cellIdOf,
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

describe('소유권 — 세 컬렉션 모두 본인만 읽고 쓴다', () => {
  it('본인 문서는 세 경로 모두 읽고 쓸 수 있다', async () => {
    const db = asUser(env, OWNER_UID);

    await assertSucceeds(getDoc(doc(db, paths.user(OWNER_UID))));
    await assertSucceeds(getDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP)))));
    await assertSucceeds(getDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId))));

    await assertSucceeds(setDoc(doc(db, paths.user(OWNER_UID)), userDoc({ nickname: '바뀐 닉' })));

    const stamp = stampDoc({ stadiumId: 'sajik', homeTeamId: 'lotte', gameId: 'g-sajik-1' });
    await assertSucceeds(setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp));

    const like = likeDoc({ placeId: 'sajik-milmyeon', stadiumId: 'sajik' });
    await assertSucceeds(setDoc(doc(db, paths.like(OWNER_UID, like.placeId)), like));
  });

  it('남의 문서는 세 경로 모두 읽을 수 없다', async () => {
    const db = asUser(env, OTHER_UID);

    await assertFails(getDoc(doc(db, paths.user(OWNER_UID))));
    await assertFails(getDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP)))));
    await assertFails(getDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId))));
  });

  it('남의 도장에는 쓸 수 없다 (덮어쓰기·새 도장·삭제 전부)', async () => {
    const db = asUser(env, OTHER_UID);

    const fresh = stampDoc({ stadiumId: 'daegu', homeTeamId: 'samsung', gameId: 'g-daegu-1' });
    await assertFails(setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(fresh))), fresh));
    await assertFails(
      setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP))), stampDoc()),
    );
    await assertFails(
      updateDoc(doc(db, paths.user(OWNER_UID)), { board: { jamsil_lg: boardCell(9) } }),
    );
    await assertFails(
      setDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId)), likeDoc()),
    );
  });

  it('미인증 요청은 읽기도 쓰기도 거부된다', async () => {
    const db = asGuest(env);

    await assertFails(getDoc(doc(db, paths.user(OWNER_UID))));
    await assertFails(getDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP)))));
    await assertFails(getDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId))));

    await assertFails(setDoc(doc(db, paths.user(OWNER_UID)), userDoc()));
    await assertFails(
      setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP))), stampDoc()),
    );
    await assertFails(setDoc(doc(db, paths.like(OWNER_UID, SEED_LIKE.placeId)), likeDoc()));
  });
});

describe('도장 문서 id 는 `{stadiumId}_{gameId}` 한 형태뿐이다', () => {
  it('id 가 본문의 stadiumId·gameId 와 맞으면 통과한다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'gwangju', homeTeamId: 'kia', gameId: 'g-gwangju-7' });
    assert.equal(stampIdOf(stamp), 'gwangju_g-gwangju-7');
    await assertSucceeds(setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp));
  });

  it('다른 형태의 id 는 전부 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'gwangju', homeTeamId: 'kia', gameId: 'g-gwangju-7' });

    for (const wrongId of [
      'auto-generated-id', // 자동 생성 id
      'g-gwangju-7', // gameId 만
      'gwangju', // stadiumId 만
      'gwangju_g-gwangju-8', // 다른 경기
      'daegu_g-gwangju-7', // 다른 구장
      'gwangju-g-gwangju-7', // 구분자가 다름
    ]) {
      await assertFails(setDoc(doc(db, paths.stamp(OWNER_UID, wrongId)), stamp));
    }
  });

  it('같은 경기에 같은 id 로 다시 쓰면 문서가 하나로 수렴한다 (멱등)', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'suwon', homeTeamId: 'kt', gameId: 'g-suwon-3' });
    const ref = doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp)));

    await assertSucceeds(setDoc(ref, stamp));
    await assertSucceeds(setDoc(ref, stamp));

    const snap = await getDoc(ref);
    assert.equal(snap.data().gameId, 'g-suwon-3');
  });

  it('구장과 홈팀의 짝이 판의 10칸에 없으면 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'gocheok', homeTeamId: 'lg', gameId: 'g-gocheok-1' });
    await assertFails(setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp));
  });
});

describe('필드 화이트리스트 — 계약 밖 필드는 서버에 닿지 못한다', () => {
  it('기기의 현재 지점을 담은 필드가 섞이면 세 경로 모두 쓰기가 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const spot = { lat: 37.512, lng: 127.072 };

    await assertFails(setDoc(doc(db, paths.user(OWNER_UID)), userDoc(spot)));

    const stamp = stampDoc({ ...spot, stadiumId: 'munhak', homeTeamId: 'ssg', gameId: 'g-munhak-1' });
    await assertFails(setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp));

    const like = likeDoc({ ...spot, placeId: 'munhak-cafe', stadiumId: 'munhak' });
    await assertFails(setDoc(doc(db, paths.like(OWNER_UID, like.placeId)), like));
  });

  it('이름을 바꿔 숨긴 좌표도 화이트리스트에 없으므로 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(
      setDoc(doc(db, paths.user(OWNER_UID)), userDoc({ lastSpot: [37.512, 127.072] })),
    );
  });

  it('필수 필드가 빠지거나 로스터 밖 값이면 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));

    const withoutNickname = userDoc();
    delete withoutNickname.nickname;
    await assertFails(setDoc(ref, withoutNickname));

    await assertFails(setDoc(ref, userDoc({ favoriteTeamId: 'yankees' })));
    await assertFails(
      setDoc(doc(db, paths.like(OWNER_UID, 'x-place')), likeDoc({ placeId: 'x-place', category: 'bar' })),
    );
  });
});

describe('칸별 요약 — 사용자 문서 하나만 읽고 판을 그린다', () => {
  it('10칸 전부를 요약으로 들 수 있고 등급 세 값이 통과한다', async () => {
    const db = asUser(env, OWNER_UID);
    const board = {};
    for (const [i, cellId] of CELL_IDS.entries()) {
      board[cellId] = boardCell([1, 3, 10][i % 3], '2026-09-01');
    }
    await assertSucceeds(setDoc(doc(db, paths.user(OWNER_UID)), userDoc({ board })));

    const snap = await getDoc(doc(db, paths.user(OWNER_UID)));
    assert.equal(Object.keys(snap.data().board).length, 10);
  });

  it('판에 없는 칸 id·등급·개수는 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));

    await assertFails(setDoc(ref, userDoc({ board: { gocheok_lg: boardCell(1) } })));
    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: { count: 1, tier: 'gold' } } })));
    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: { count: 0, tier: 'first' } } })));
    await assertFails(
      setDoc(ref, userDoc({ board: { jamsil_lg: { count: 1, tier: 'first', visits: 1 } } })),
    );
  });

  it('도장과 요약을 같은 트랜잭션으로 함께 쓸 수 있다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'changwon', homeTeamId: 'nc', gameId: 'g-changwon-4' });
    const cellId = cellIdOf(stamp);
    assert.equal(cellId, 'changwon_nc');

    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const userRef = doc(db, paths.user(OWNER_UID));
        const stampRef = doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp)));
        const before = await tx.get(userRef);
        const count = (before.data()?.board?.[cellId]?.count ?? 0) + 1;
        tx.set(stampRef, stamp);
        tx.update(userRef, { [`board.${cellId}`]: boardCell(count, stamp.gameDate) });
      }),
    );

    const snap = await getDoc(doc(db, paths.user(OWNER_UID)));
    assert.deepEqual(snap.data().board[cellId], {
      count: 1,
      tier: 'first',
      lastStampedOn: '2026-09-01',
    });
  });
});
