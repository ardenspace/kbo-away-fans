// Firestore 보안 규칙 — SDK 가 실제로 보내는 쓰기 형태를 잰다.
//
// rules.test.mjs 가 문서 한 장의 모양을, rules-surface.test.mjs 가 그 모양을 우회하는
// 경로를 재는 데 비해, 이 파일은 앱이 실제로 쓸 쓰기 형태를 넣어 본다: 서버 변환
// (serverTimestamp · increment · deleteField), 병합 쓰기(merge), 배치 쓰기, 그리고
// 값 대신 타입이 어긋난 칸 요약. 클라이언트 `Date` 로만 재면 앱이 serverTimestamp()
// 로 바꿔 다는 순간 규칙이 통과하는지 아무도 모른다.
//
// 실행: npm --prefix firebase test  (run-rules-tests.sh 가 에뮬레이터를 감싼다)

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteField,
  doc,
  getDoc,
  getDocs,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

import {
  CELL_IDS,
  OTHER_UID,
  OWNER_UID,
  asGuest,
  asUser,
  boardCell,
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

describe('서버 시각 변환(serverTimestamp)', () => {
  it('세 컬렉션의 timestamp 필드를 serverTimestamp() 로 써도 통과한다', async () => {
    const db = asUser(env, OWNER_UID);

    await assertSucceeds(
      setDoc(
        doc(db, paths.user(OWNER_UID)),
        userDoc({ joinedAt: serverTimestamp(), updatedAt: serverTimestamp() }),
      ),
    );

    const stamp = stampDoc({
      stadiumId: 'daegu',
      homeTeamId: 'samsung',
      gameId: 'g-daegu-9',
      stampedAt: serverTimestamp(),
    });
    await assertSucceeds(setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp));

    const like = likeDoc({ placeId: 'daegu-tteok', stadiumId: 'daegu', likedAt: serverTimestamp() });
    await assertSucceeds(setDoc(doc(db, paths.like(OWNER_UID, like.placeId)), like));
  });

  it('serverTimestamp() 를 update 로 얹어도 통과한다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertSucceeds(
      updateDoc(doc(db, paths.user(OWNER_UID)), { updatedAt: serverTimestamp() }),
    );
  });
});

describe('원자 증가(increment) 아래에서도 사다리가 강제되는가', () => {
  beforeEach(async () => {
    await seed(env, (db) =>
      setDoc(doc(db, paths.user(OWNER_UID)), userDoc({ board: { jamsil_lg: boardCell(2) } })),
    );
  });

  it('count 만 increment 하고 tier 를 그대로 두면 사다리를 지킬 때만 통과한다', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));

    // 2 → 3 은 tier 가 first 에서 regular 로 넘어가야 하므로 tier 를 안 옮기면 거부
    await assertFails(updateDoc(ref, { 'board.jamsil_lg.count': increment(1) }));

    // 같은 증가라도 tier 를 함께 옮기면 통과
    await assertSucceeds(
      updateDoc(ref, {
        'board.jamsil_lg.count': increment(1),
        'board.jamsil_lg.tier': 'regular',
      }),
    );
    const snap = await getDoc(ref);
    assert.deepEqual(snap.data().board.jamsil_lg, { count: 3, tier: 'regular' });
  });

  it('사다리를 넘지 않는 increment 는 tier 를 그대로 두어도 통과한다', async () => {
    const db = asUser(env, OWNER_UID);
    await seed(env, (db2) =>
      setDoc(doc(db2, paths.user(OWNER_UID)), userDoc({ board: { jamsil_lg: boardCell(1) } })),
    );
    await assertSucceeds(
      updateDoc(doc(db, paths.user(OWNER_UID)), { 'board.jamsil_lg.count': increment(1) }),
    );
  });
});

describe('필드 삭제(deleteField)', () => {
  it('필수 필드는 deleteField 로 지울 수 없고, 선택 필드는 지울 수 있다', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));

    await seed(env, (db2) =>
      setDoc(
        doc(db2, paths.user(OWNER_UID)),
        userDoc({ updatedAt: new Date('2026-09-01T01:00:00Z'), board: { jamsil_lg: boardCell(1, '2026-09-01') } }),
      ),
    );

    await assertFails(updateDoc(ref, { board: deleteField() }));
    await assertFails(updateDoc(ref, { nickname: deleteField() }));
    await assertFails(updateDoc(ref, { joinedAt: deleteField() }));
    // 칸 요약의 필수 키를 지우면 그 칸이 계약을 잃는다
    await assertFails(updateDoc(ref, { 'board.jamsil_lg.tier': deleteField() }));
    await assertFails(updateDoc(ref, { 'board.jamsil_lg.count': deleteField() }));

    // 선택 필드는 지워도 계약이 성립한다
    await assertSucceeds(updateDoc(ref, { 'board.jamsil_lg.lastStampedOn': deleteField() }));
    await assertSucceeds(updateDoc(ref, { updatedAt: deleteField() }));
    // 칸 통째로 비우기(도장 취소 시나리오)도 계약 안이다
    await assertSucceeds(updateDoc(ref, { 'board.jamsil_lg': deleteField() }));
  });
});

describe('setDoc(..., {merge:true}) 병합 쓰기', () => {
  it('merge 로도 계약 밖 필드를 끼워 넣을 수 없다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(
      setDoc(doc(db, paths.user(OWNER_UID)), { whereIWas: '37.5,127.0' }, { merge: true }),
    );
    await assertFails(
      setDoc(
        doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP))),
        { accuracyMeters: 12 },
        { merge: true },
      ),
    );
    // 계약 안 필드의 merge 는 통과한다 (병합 자체가 막히는 것이 아님을 확인)
    await assertSucceeds(
      setDoc(doc(db, paths.user(OWNER_UID)), { nickname: '병합' }, { merge: true }),
    );
  });

  it('merge 로 도장 문서 id 계약을 어긋나게 할 수 없다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(
      setDoc(
        doc(db, paths.stamp(OWNER_UID, stampIdOf(SEED_STAMP))),
        { gameId: 'g-somewhere-else' },
        { merge: true },
      ),
    );
  });
});

describe('배치 쓰기(writeBatch)', () => {
  it('배치 안의 한 쓰기가 계약을 어기면 배치 전체가 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'munhak', homeTeamId: 'ssg', gameId: 'g-munhak-2' });

    const bad = writeBatch(db);
    bad.set(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp);
    // 같은 배치에서 남의 문서를 건드린다
    bad.set(doc(db, paths.stamp(OTHER_UID, stampIdOf(stamp))), stamp);
    await assertFails(bad.commit());

    // 도장이 남의 배치와 함께 거부되었으므로 내 쪽에도 문서가 없어야 한다
    const snap = await getDoc(doc(asUser(env, OWNER_UID), paths.stamp(OWNER_UID, stampIdOf(stamp))));
    assert.equal(snap.exists(), false);
  });

  it('도장 + 칸 요약을 한 배치로 쓰는 정상 경로는 통과한다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'munhak', homeTeamId: 'ssg', gameId: 'g-munhak-3' });

    const ok = writeBatch(db);
    ok.set(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp);
    ok.update(doc(db, paths.user(OWNER_UID)), {
      'board.munhak_ssg': boardCell(1, stamp.gameDate),
      updatedAt: serverTimestamp(),
    });
    await assertSucceeds(ok.commit());
  });
});

// rules.test.mjs 의 "10칸 전부" 테스트는 이미 있는 문서를 덮어쓰는 update 한 갈래만
// 잰다. create 갈래와 점 경로 update 갈래도 같은 예산을 쓰므로 함께 지킨다.
describe('표현식 예산 — 10칸 만판을 다른 쓰기 방식으로도 통과하는가', () => {
  const fullBoard = () => {
    const board = {};
    for (const [i, cellId] of CELL_IDS.entries()) {
      board[cellId] = boardCell([10, 3, 1][i % 3], '2026-09-01');
    }
    return board;
  };

  it('create(새 문서)로 10칸 만판을 써도 통과한다', async () => {
    const db = asUser(env, OTHER_UID);
    await assertSucceeds(
      setDoc(
        doc(db, paths.user(OTHER_UID)),
        userDoc({ board: fullBoard(), updatedAt: serverTimestamp(), nickname: 'x'.repeat(20) }),
      ),
    );
  });

  it('update(점 경로 10개)로 10칸을 한 번에 채워도 통과한다', async () => {
    const db = asUser(env, OWNER_UID);
    const patch = { updatedAt: serverTimestamp() };
    const board = fullBoard();
    for (const cellId of CELL_IDS) patch[`board.${cellId}`] = board[cellId];
    await assertSucceeds(updateDoc(doc(db, paths.user(OWNER_UID)), patch));

    const snap = await getDoc(doc(db, paths.user(OWNER_UID)));
    assert.equal(Object.keys(snap.data().board).length, 10);
  });

  it('만판 상태에서 칸 하나만 update 해도 통과한다 (평가는 병합 후 문서 전체를 본다)', async () => {
    await seed(env, (db) =>
      setDoc(doc(db, paths.user(OWNER_UID)), userDoc({ board: fullBoard() })),
    );
    const db = asUser(env, OWNER_UID);
    await assertSucceeds(
      updateDoc(doc(db, paths.user(OWNER_UID)), { 'board.jamsil_lg': boardCell(11, '2026-09-02') }),
    );
  });
});

describe('칸 요약의 타입 경계', () => {
  it('count 가 정수가 아니면 거부된다 (소수·문자열·불리언)', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));

    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: { count: 1.5, tier: 'first' } } })));
    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: { count: '3', tier: 'regular' } } })));
    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: { count: true, tier: 'first' } } })));
    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: { count: -1, tier: 'first' } } })));
  });

  it('칸 값이 map 이 아니거나 board 가 map 이 아니면 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));

    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: null } })));
    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: 3 } })));
    await assertFails(setDoc(ref, userDoc({ board: { jamsil_lg: [1, 'first'] } })));
    await assertFails(setDoc(ref, userDoc({ board: [] })));
    await assertFails(setDoc(ref, userDoc({ board: 'jamsil_lg' })));
  });

  it('lastStampedOn 이 날짜 표기가 아니면 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));

    await assertFails(
      setDoc(ref, userDoc({ board: { jamsil_lg: { count: 1, tier: 'first', lastStampedOn: '2026/09/01' } } })),
    );
    await assertFails(
      setDoc(
        ref,
        userDoc({ board: { jamsil_lg: { count: 1, tier: 'first', lastStampedOn: new Date() } } }),
      ),
    );
  });

  it('선택 필드가 null 이면 거부된다 (없음과 null 은 다르다)', async () => {
    const db = asUser(env, OWNER_UID);
    const ref = doc(db, paths.user(OWNER_UID));
    await assertFails(setDoc(ref, userDoc({ updatedAt: null })));
    await assertFails(
      setDoc(ref, userDoc({ board: { jamsil_lg: { count: 1, tier: 'first', lastStampedOn: null } } })),
    );
  });
});

describe('읽기 표면', () => {
  it('없는 문서라도 남의 경로면 읽기가 거부된다 (존재 여부가 새지 않는다)', async () => {
    const other = asUser(env, OTHER_UID);
    await assertFails(getDoc(doc(other, paths.user('uid-nobody'))));
    await assertFails(getDoc(doc(other, paths.stamp(OWNER_UID, 'jamsil_no-such-game'))));
    await assertFails(getDoc(doc(asGuest(env), paths.user('uid-nobody'))));
  });

  it('본인 하위 컬렉션 전체 훑기는 허용되고 남의 것은 거부된다', async () => {
    await assertSucceeds(getDocs(collection(asUser(env, OWNER_UID), `users/${OWNER_UID}/stamps`)));
    await assertFails(getDocs(collection(asGuest(env), `users/${OWNER_UID}/stamps`)));
  });
});

describe('도장 문서 id 형태를 우회하는 나머지 시도', () => {
  it('gameId 가 규정 문자 밖이면(공백·한글·점) 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    for (const gameId of ['g 1', '경기1', 'g.1', '', 'a'.repeat(65)]) {
      const stamp = stampDoc({ stadiumId: 'sajik', homeTeamId: 'lotte', gameId });
      await assertFails(setDoc(doc(db, paths.stamp(OWNER_UID, stampIdOf(stamp))), stamp));
    }
  });

  it('id 는 맞아도 stadiumId 가 로스터 밖이면 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampDoc({ stadiumId: 'tokyo', homeTeamId: 'lg', gameId: 'g-1' });
    await assertFails(setDoc(doc(db, paths.stamp(OWNER_UID, 'tokyo_g-1')), stamp));
  });
});
