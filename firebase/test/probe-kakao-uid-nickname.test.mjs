// 검증 탐침 — 카카오 로그인이 만드는 값(uid·닉네임)을 규칙 앞에 그대로 세워 본다.
//
// 커밋된 테스트는 두 겹을 **따로** 잰다: `functions/test/*` 는 함수가 내놓는 값의
// 모양을, `firebase/test/rules.test.mjs` 는 규칙이 받는 값의 모양을. 둘을 잇는
// 자리 — 함수가 실제로 내놓은 값이 규칙을 지나는가 — 는 아무도 밟지 않는다.
// 여기서 `functions/kakao.js` 의 결과를 그대로 에뮬레이터에 태운다.
//
// uid 도 같은 이유로 여기서 본다: `kakao:{id}` 의 콜론은 문서 id 와
// `request.auth.uid` 양쪽에 동시에 들어가는 문자이고, 2.4 의 사용자 문서 경로가
// 그 위에 선다.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';

import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';

import { fetchKakaoProfile } from '../../functions/kakao.js';
import { asUser, createTestEnv, paths, stampDoc, stampIdOf, userDoc } from './helpers.mjs';

/** 카카오 응답 하나를 돌려주는 가짜 fetch — 실제 카카오로 나가지 않는다. */
function fakeFetch(body) {
  return async () => ({ ok: true, status: 200, json: async () => body });
}

/** 함수가 실제로 내놓는 닉네임 (자르기·다듬기를 거친 값). */
async function 함수가_내놓는_닉네임(nickname) {
  const profile = await fetchKakaoProfile('token', {
    fetch: fakeFetch({ id: 8123456, properties: { nickname } }),
  });
  return profile.nickname;
}

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

describe('탐침 — 카카오 uid 와 닉네임이 규칙을 그대로 지나는가', () => {
  const KAKAO_UID = 'kakao:8123456';
  const 다른_KAKAO_UID = 'kakao:9999999';

  it('`kakao:{id}` uid 는 본인 문서·하위 컬렉션을 쓰고, 남의 문서는 못 쓴다', async () => {
    const db = asUser(env, KAKAO_UID);

    await assertSucceeds(setDoc(doc(db, paths.user(KAKAO_UID)), userDoc()));
    const stamp = stampDoc();
    await assertSucceeds(
      setDoc(doc(db, paths.stamp(KAKAO_UID, stampIdOf(stamp))), stamp),
    );

    // 콜론이 경로 매칭을 갈라 남의 uid 로 새지 않는다.
    await assertFails(setDoc(doc(db, paths.user(다른_KAKAO_UID)), userDoc()));
    await assertFails(setDoc(doc(db, paths.user('8123456')), userDoc()));
    await assertFails(setDoc(doc(db, paths.user('uid-owner')), userDoc()));
  });

  it('함수가 잘라 보낸 닉네임은 어떤 입력에서 왔든 규칙을 통과한다', async () => {
    const db = asUser(env, KAKAO_UID);
    const 카카오_원본 = [
      '원정팬',
      '가'.repeat(30),
      '가'.repeat(18) + '\u{1F42F}'.repeat(2),
      '가'.repeat(19) + '\u{1F42F}'.repeat(3),
      '\u{1F42F}'.repeat(30),
      '\u{1F468}‍\u{1F469}‍\u{1F467}‍\u{1F466}'.repeat(3),
      '  \u{1F44D}\u{1F3FD} 원정 러 \n',
      'a'.repeat(64),
    ];

    for (const 원본 of 카카오_원본) {
      const nickname = await 함수가_내놓는_닉네임(원본);
      assert.notEqual(nickname, null, `표본이 잘못됐다(널): ${JSON.stringify(원본)}`);
      await assertSucceeds(
        setDoc(doc(db, paths.user(KAKAO_UID)), userDoc({ nickname })),
      );
    }
  });

  it('함수의 한도를 한 단위 넘긴 값은 규칙이 거부한다 (한도가 실제로 걸려 있다)', async () => {
    const db = asUser(env, KAKAO_UID);
    const 넘긴값 = (await 함수가_내놓는_닉네임('가'.repeat(30))) + '가';
    assert.equal(넘긴값.length, 21, '전제: 21단위');
    await assertFails(setDoc(doc(db, paths.user(KAKAO_UID)), userDoc({ nickname: 넘긴값 })));
  });
});
