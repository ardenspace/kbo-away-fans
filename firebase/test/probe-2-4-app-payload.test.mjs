// 적대적 탐침 (step 2.4) — 앱이 실제로 만들어 보내는 payload 모양이 규칙을
// 통과하는지 에뮬레이터로 직접 잰다.
//
// 기존 규칙 테스트는 helpers.mjs 의 JS 표본(`userDoc()`)을 쓴다. 그 표본은
// `joinedAt` 을 확정된 Date 로 두고, 문서를 `setDoc` 으로 통째로 쓴다. 앱이
// 실제로 보내는 모양은 그것과 셋이 다르다.
//   1) `joinedAt`/`updatedAt` 이 **서버 시각 센티널**이다
//      (`encodeBackendValues` → `FieldValue.serverTimestamp()`).
//   2) 첫 문서는 `runTransaction` 안의 `transaction.set` 으로 나간다.
//   3) 팀 변경은 세 키(`favoriteTeamId`·`profileThemeKey`·`updatedAt`)만 실은
//      `updateDoc` 이다.
// 셋 중 하나라도 규칙과 어긋나면 실기기에서만 보이는 실패가 된다.

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteField,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  updateDoc,
} from 'firebase/firestore';

import { OWNER_UID, asUser, createTestEnv, paths, seed } from './helpers.mjs';

let env;

before(async () => {
  env = await createTestEnv();
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

/** lib/backend/user_data.dart 의 NewUserProfile.toData() + 어댑터. */
function newUserProfilePayload(teamId = 'hanwha', nickname = '원정러1234') {
  return {
    nickname,
    favoriteTeamId: teamId,
    profileThemeKey: teamId,
    joinedAt: serverTimestamp(),
    board: {},
  };
}

/** lib/backend/user_data.dart 의 UserProfilePatch.toData() + 어댑터. */
function patchPayload(teamId) {
  return {
    favoriteTeamId: teamId,
    profileThemeKey: teamId,
    updatedAt: serverTimestamp(),
  };
}

/**
 * 같은 타입이 **닉네임만** 실었을 때의 모양 — 3.x 마이페이지가 여는 경로다.
 * 팀 변경만 재 두면 규칙이 이 모양을 받아 주는지 아무도 모르는 채 배포된다.
 */
function nicknamePatchPayload(nickname) {
  return {
    nickname,
    updatedAt: serverTimestamp(),
  };
}

/** lib/backend/user_data_firestore.dart 의 createProfile 그대로. */
function createProfile(db, uid, payload) {
  return runTransaction(db, async (transaction) => {
    const ref = doc(db, paths.user(uid));
    const snapshot = await transaction.get(ref);
    if (snapshot.exists()) return;
    transaction.set(ref, payload);
  });
}

describe('탐침 — 앱의 첫 문서 payload 가 규칙을 통과한다', () => {
  it('서버 시각 센티널 + 빈 board 로 만든 첫 문서가 통과한다', async () => {
    const db = asUser(env, OWNER_UID);

    await assertSucceeds(createProfile(db, OWNER_UID, newUserProfilePayload()));

    const written = (await getDoc(doc(db, paths.user(OWNER_UID)))).data();
    assert.ok(written, '문서가 실제로 남아야 한다');
    // 센티널이 진짜 timestamp 로 확정됐는지 — 규칙의 `joinedAt is timestamp` 가
    // 통과한 것이 우연이 아님을 값으로 확인한다.
    assert.equal(typeof written.joinedAt.toDate, 'function');
    assert.deepEqual(written.board, {});
  });

  it('기본 닉네임(원정러NNNN)도 길이 계약 안이다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertSucceeds(
      createProfile(db, OWNER_UID, newUserProfilePayload('lg', '원정러0000')),
    );
  });

  it('이미 있는 문서에 대고 같은 트랜잭션을 돌리면 덮지 않는다', async () => {
    await seed(env, async (adminDb) => {
      await runTransaction(adminDb, async (t) => {
        t.set(doc(adminDb, paths.user(OWNER_UID)), {
          nickname: '먼저있던닉',
          favoriteTeamId: 'lg',
          profileThemeKey: 'lg',
          joinedAt: new Date('2026-03-01T00:00:00Z'),
          board: { jamsil_lg: { count: 2, tier: 'first' } },
        });
      });
    });

    const db = asUser(env, OWNER_UID);
    await assertSucceeds(
      createProfile(db, OWNER_UID, newUserProfilePayload('kia', '다른사람')),
    );

    const after_ = (await getDoc(doc(db, paths.user(OWNER_UID)))).data();
    assert.equal(after_.nickname, '먼저있던닉');
    assert.equal(after_.favoriteTeamId, 'lg');
    assert.equal(after_.joinedAt.toDate().toISOString(), '2026-03-01T00:00:00.000Z');
    assert.deepEqual(after_.board, { jamsil_lg: { count: 2, tier: 'first' } });
  });
});

describe('탐침 — 앱의 팀 변경 payload 가 규칙을 통과한다', () => {
  beforeEach(async () => {
    const db = asUser(env, OWNER_UID);
    await createProfile(db, OWNER_UID, newUserProfilePayload('lg'));
  });

  it('세 키만 실은 updateDoc 이 통과하고 가입 시각·판이 남는다', async () => {
    const db = asUser(env, OWNER_UID);

    await assertSucceeds(
      updateDoc(doc(db, paths.user(OWNER_UID)), patchPayload('doosan')),
    );

    const after_ = (await getDoc(doc(db, paths.user(OWNER_UID)))).data();
    assert.equal(after_.favoriteTeamId, 'doosan');
    assert.equal(after_.profileThemeKey, 'doosan');
    assert.ok(after_.joinedAt, '가입 시각이 남아야 한다');
    assert.ok(after_.updatedAt, 'updatedAt 이 서버 시각으로 확정돼야 한다');
  });

  it('닉네임만 실은 update 도 통과하고 나머지 필드가 남는다', async () => {
    const db = asUser(env, OWNER_UID);

    await assertSucceeds(
      updateDoc(doc(db, paths.user(OWNER_UID)), nicknamePatchPayload('바꾼닉')),
    );

    const after_ = (await getDoc(doc(db, paths.user(OWNER_UID)))).data();
    assert.equal(after_.nickname, '바꾼닉');
    assert.equal(after_.favoriteTeamId, 'lg');
    assert.ok(after_.joinedAt, '가입 시각이 남아야 한다');
  });

  it('계약 밖 팀 id 는 규칙이 거부한다 (앱이 먼저 막지만 바닥이 여기다)', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(
      updateDoc(doc(db, paths.user(OWNER_UID)), patchPayload('yankees')),
    );
  });

  it('없는 문서에 대고 부른 update 는 실패한다 (create 갈래를 건너뛰면 여기로 온다)', async () => {
    const db = asUser(env, 'uid-no-doc');
    await assertFails(
      updateDoc(doc(db, paths.user('uid-no-doc')), patchPayload('nc')),
    );
  });

  it('필수 필드를 지우는 update 는 거부된다', async () => {
    const db = asUser(env, OWNER_UID);
    await assertFails(
      updateDoc(doc(db, paths.user(OWNER_UID)), {
        favoriteTeamId: deleteField(),
        updatedAt: serverTimestamp(),
      }),
    );
  });
});
