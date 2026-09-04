// 적대적 탐침 (step 4.2) — 앱이 도장을 쓸 때 **실제로 보내는 배치**가 규칙을
// 통과하는지 에뮬레이터로 직접 잰다.
//
// rules-writes.test.mjs 에도 "도장 + 칸 요약을 한 배치로" 케이스가 있지만 그것은
// 1.5 가 손으로 지은 모양이다. 앱이 보내는 모양은 `lib/backend/user_data.dart` 의
// `StampWrite.toData()` 와 `StampWrite.boardPatchData()` 가 정하고, 그 사이에
// `encodeBackendValues` 어댑터가 낀다. 실제 모양이 그 표본과 다른 자리가 셋이다.
//   1) `stampedAt` 이 확정된 Date 가 아니라 **서버 시각 센티널**이다.
//   2) 칸 요약은 `board` 를 통째로 쓰지 않고 **점 경로**(`board.{cellId}`) 하나만
//      건드리며, `updatedAt` 도 센티널로 함께 얹힌다.
//   3) 개수는 앱이 읽어서 세고(`count = 있던 개수 + 1`) 등급은 그 개수에서
//      파생한다 — 그 파생이 규칙의 `tierFor` 와 어긋나면 쓰기가 통째로 거부된다.
// 셋 중 하나라도 규칙과 어긋나면 실기기에서만 보이는 실패가 된다.
//
// 짝 파일: `test/backend/user_data_firestore_store_test.dart` 가 같은 배치를
// Dart 쪽에서(무엇이 불렸는가) 재고, 여기서는 그것을 규칙이 받아 주는지를 잰다.

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  writeBatch,
} from 'firebase/firestore';

import {
  OTHER_UID,
  OWNER_UID,
  asUser,
  createTestEnv,
  paths,
  seed,
  tierFor,
  userDoc,
} from './helpers.mjs';

let env;

before(async () => {
  env = await createTestEnv();
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await seed(env, (db) => setDoc(doc(db, paths.user(OWNER_UID)), userDoc()));
});

/** lib/backend/user_data.dart 의 StampWrite.toData() + 어댑터. */
function stampPayload({
  stadiumId = 'jamsil',
  gameId = 'g-jamsil-1',
  homeTeamId = 'lg',
  gameDate = '2026-08-25',
} = {}) {
  return {
    stadiumId,
    gameId,
    homeTeamId,
    gameDate,
    stampedAt: serverTimestamp(),
  };
}

/** 같은 파일의 StampWrite.boardPatchData(cell) + 어댑터. */
function boardPatchPayload(stamp, count) {
  return {
    [`board.${stamp.stadiumId}_${stamp.homeTeamId}`]: {
      count,
      tier: tierFor(count),
      lastStampedOn: stamp.gameDate,
    },
    updatedAt: serverTimestamp(),
  };
}

/** FirestoreUserDataStore.writeStamp 가 커밋하는 배치 그대로. */
function stampBatch(db, uid, stamp, count) {
  const batch = writeBatch(db);
  batch.set(
    doc(db, paths.stamp(uid, `${stamp.stadiumId}_${stamp.gameId}`)),
    stamp,
  );
  batch.update(doc(db, paths.user(uid)), boardPatchPayload(stamp, count));
  return batch;
}

describe('탐침 — 앱의 도장 배치가 규칙을 통과한다', () => {
  it('첫 도장(센티널 + 점 경로 요약)이 통과하고 두 문서가 함께 남는다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampPayload();

    await assertSucceeds(stampBatch(db, OWNER_UID, stamp, 1).commit());

    const written = await getDoc(
      doc(db, paths.stamp(OWNER_UID, `${stamp.stadiumId}_${stamp.gameId}`)),
    );
    assert.equal(written.exists(), true);
    const user = await getDoc(doc(db, paths.user(OWNER_UID)));
    assert.deepEqual(user.data().board.jamsil_lg, {
      count: 1,
      tier: 'first',
      lastStampedOn: '2026-08-25',
    });
  });

  it('사다리를 넘는 개수까지 같은 배치 모양으로 올라간다 (1→3→10)', async () => {
    const db = asUser(env, OWNER_UID);

    for (const count of [1, 2, 3, 9, 10]) {
      const stamp = stampPayload({ gameId: `g-jamsil-${count}` });
      await assertSucceeds(stampBatch(db, OWNER_UID, stamp, count).commit());
    }

    const user = await getDoc(doc(db, paths.user(OWNER_UID)));
    assert.equal(user.data().board.jamsil_lg.tier, 'master');
  });

  it('잠실의 두 홈팀은 서로 다른 칸으로 간다', async () => {
    const db = asUser(env, OWNER_UID);

    await assertSucceeds(
      stampBatch(db, OWNER_UID, stampPayload({ homeTeamId: 'lg' }), 1).commit(),
    );
    await assertSucceeds(
      stampBatch(
        db,
        OWNER_UID,
        stampPayload({ gameId: 'g-jamsil-2', homeTeamId: 'doosan' }),
        1,
      ).commit(),
    );

    const board = (await getDoc(doc(db, paths.user(OWNER_UID)))).data().board;
    assert.deepEqual(Object.keys(board).sort(), ['jamsil_doosan', 'jamsil_lg']);
  });

  it('개수와 등급이 어긋난 배치는 도장까지 함께 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampPayload({ gameId: 'g-mismatch' });

    const bad = writeBatch(db);
    bad.set(
      doc(db, paths.stamp(OWNER_UID, `${stamp.stadiumId}_${stamp.gameId}`)),
      stamp,
    );
    bad.update(doc(db, paths.user(OWNER_UID)), {
      // count 1 인데 등급만 올려 적는다 — 앱 코드의 버그가 이렇게 생긴다.
      'board.jamsil_lg': { count: 1, tier: 'master' },
      updatedAt: serverTimestamp(),
    });
    await assertFails(bad.commit());

    const written = await getDoc(
      doc(db, paths.stamp(OWNER_UID, `${stamp.stadiumId}_${stamp.gameId}`)),
    );
    assert.equal(written.exists(), false, '배치가 거부되면 도장도 남지 않는다');
  });

  it('구장×홈팀 짝이 판의 10칸 밖이면 배치가 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    // 고척인데 홈팀이 LG — cellIds() 에 없는 짝이다.
    const stamp = stampPayload({
      stadiumId: 'gocheok',
      gameId: 'g-gocheok-1',
      homeTeamId: 'lg',
    });

    await assertFails(stampBatch(db, OWNER_UID, stamp, 1).commit());
  });

  it('남의 도장은 같은 배치 모양으로도 쓸 수 없다', async () => {
    await seed(env, (db) =>
      setDoc(doc(db, paths.user(OTHER_UID)), userDoc()),
    );
    const db = asUser(env, OTHER_UID);

    await assertFails(
      stampBatch(db, OWNER_UID, stampPayload({ gameId: 'g-steal' }), 1).commit(),
    );
  });

  it('도장 문서 id 가 `{stadiumId}_{gameId}` 가 아니면 배치가 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    const stamp = stampPayload({ gameId: 'g-wrong-id' });

    const bad = writeBatch(db);
    // 자동 생성 id 를 흉내 낸다 — 규칙이 id 와 본문의 어긋남을 거부한다.
    bad.set(doc(db, paths.stamp(OWNER_UID, 'AbCdEf0123456789')), stamp);
    bad.update(doc(db, paths.user(OWNER_UID)), boardPatchPayload(stamp, 1));
    await assertFails(bad.commit());
  });
});
