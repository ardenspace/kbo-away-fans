// 검증 탐침 — 커밋된 테스트가 지나지 않는 자리만 공격한다.
import assert from 'node:assert/strict';
import test from 'node:test';

import { KakaoAuthError, fetchKakaoProfile } from '../kakao.js';
import { issueKakaoCustomToken } from '../custom-token.js';

function stubGlobalFetch(handler) {
  const calls = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), init });
    return handler(String(url), init);
  };
  return { calls, restore: () => { globalThis.fetch = original; } };
}

function jsonResponse(status, body) {
  return { ok: status >= 200 && status < 300, status, json: async () => body };
}

function countingAuth() {
  const calls = [];
  return {
    calls,
    createCustomToken: async (uid, claims) => {
      calls.push({ uid, claims });
      return `custom-token-for-${uid}`;
    },
  };
}

async function nicknameOf(nickname) {
  const stub = stubGlobalFetch(() => jsonResponse(200, { id: 7, properties: { nickname } }));
  try {
    return (await fetchKakaoProfile('token')).nickname;
  } finally {
    stub.restore();
  }
}

// 탐침 1 — 닉네임 정규화의 불변식을 넓은 표본으로 쓸어 본다.
// 커밋된 테스트는 고른 케이스 몇 개를 단언한다. 여기서는 조합·이형·지역표시자·
// 결합문자까지 섞어 "규칙이 받는 모양"이라는 사후 조건을 표본 전체에 건다.
const 표본 = [
  '',
  '   ',
  '원정팬',
  'a',
  'a'.repeat(21),
  '가'.repeat(20),
  '가'.repeat(21),
  '가'.repeat(18) + '🐯🐯',
  '가'.repeat(19) + '🐯🐯🐯',
  '🐯'.repeat(11),
  '🐯'.repeat(30),
  '👨‍👩‍👧‍👦'.repeat(2),
  '👨‍👩‍👧‍👦'.repeat(3),
  '가'.repeat(19) + '👍🏽', // 피부색 수정자가 경계에 걸린다
  '가'.repeat(18) + '👍🏽',
  '가'.repeat(17) + '🇰🇷', // 지역표시자 짝이 경계에 걸린다
  '가'.repeat(19) + '❤️', // 이형 선택자(U+FE0F)가 경계에 걸린다
  '가'.repeat(19) + '\u200d\u{1F42F}',
  'é'.repeat(15), // 결합 악센트
  '\u200d\u200d\u200d',
  '\ufe0f\ufe0f',
  ' \t\n가나다 \n ',
  '가'.repeat(19) + '  나',
  '0'.repeat(64),
];

test('탐침: 어떤 카카오 닉네임이 와도 규칙이 받는 모양(널 또는 UTF-16 1~20)으로만 나온다', async () => {
  for (const raw of 표본) {
    const 결과 = await nicknameOf(raw);
    if (결과 === null) continue;
    assert.equal(typeof 결과, 'string', `${JSON.stringify(raw)}`);
    assert.ok(결과.length >= 1 && 결과.length <= 20, `${JSON.stringify(raw)} → ${결과.length}단위`);
    assert.doesNotMatch(결과, /[\uD800-\uDFFF]/u, `짝 잃은 서러게이트: ${JSON.stringify(raw)}`);
    assert.doesNotMatch(결과, /\u200d$/u, `매달린 ZWJ: ${JSON.stringify(raw)}`);
    assert.equal(결과, 결과.trim(), `앞뒤 공백이 남았다: ${JSON.stringify(raw)}`);
    // 자른 값은 입력의 앞부분이어야 한다 — 내용을 바꿔 보내면 안 된다.
    assert.ok(raw.trim().startsWith(결과), `앞부분이 아니다: ${JSON.stringify(raw)} → ${결과}`);
  }
});

// 탐침 2 — 멱등성. 함수가 보낸 닉네임을 다시 넣으면 같은 값이어야 한다.
// (2.3/2.4 가 재로그인마다 이 값을 다시 받아 문서에 쓴다 — 여기가 흔들리면
//  같은 사람의 닉네임이 로그인할 때마다 조금씩 달라진다.)
test('탐침: 닉네임 정규화는 멱등이다', async () => {
  for (const raw of 표본) {
    const 한번 = await nicknameOf(raw);
    if (한번 === null) continue;
    const 두번 = await nicknameOf(한번);
    assert.equal(두번, 한번, `멱등하지 않다: ${JSON.stringify(raw)}`);
  }
});

// 탐침 3 — 액세스 토큰이 URL 에도 오류 메시지에도 새지 않는다.
// index.js 가 실패마다 `reason: err.message` 를 구조화 로그에 싣기 때문에,
// 메시지에 토큰이 섞이면 로그가 곧 자격 증명 저장소가 된다.
test('탐침: 액세스 토큰은 URL 에도 오류 메시지에도 실리지 않는다', async () => {
  const SECRET = 'AAAA-secret-kakao-access-token-BBBB';

  const 성공 = stubGlobalFetch(() => jsonResponse(200, { id: 1 }));
  try {
    await fetchKakaoProfile(SECRET);
    assert.doesNotMatch(성공.calls[0].url, /secret-kakao-access-token/);
  } finally {
    성공.restore();
  }

  for (const status of [400, 401, 403, 500]) {
    const stub = stubGlobalFetch(() => jsonResponse(status, { msg: 'nope', code: -401 }));
    try {
      await fetchKakaoProfile(SECRET);
      assert.fail(`status=${status} 인데 통과했다`);
    } catch (err) {
      assert.ok(err instanceof KakaoAuthError);
      assert.doesNotMatch(err.message, /secret-kakao-access-token/, `status=${status}`);
    } finally {
      stub.restore();
    }
  }

  // 네트워크 실패 경로 (cause 까지 문자열로 훑는다).
  const 끊김 = stubGlobalFetch(() => { throw new Error('connect ETIMEDOUT'); });
  try {
    await fetchKakaoProfile(SECRET);
    assert.fail('네트워크 실패인데 통과했다');
  } catch (err) {
    assert.doesNotMatch(err.message, /secret-kakao-access-token/);
  } finally {
    끊김.restore();
  }
});

// 탐침 4 — 카카오가 동의하지 않은 항목을 얹어 보내도 함수 밖으로 새지 않는다.
// 요청에 안 실었다는 것은 커밋된 테스트가 잰다. 응답에 섞여 온 값을 흘리지
// 않는지는 아무도 재지 않는다 — acceptance 의 "uid·닉네임만" 은 나가는 값에도 걸린다.
test('탐침: 응답에 이메일·전화가 섞여 와도 함수의 결과에는 없다', async () => {
  const stub = stubGlobalFetch(() =>
    jsonResponse(200, {
      id: 8123456,
      properties: { nickname: '원정팬', profile_image: 'https://x/y.jpg' },
      kakao_account: {
        email: 'leak@example.com',
        has_email: true,
        phone_number: '+82 10-1234-5678',
        birthday: '0101',
        gender: 'male',
        name: '홍길동',
      },
    }),
  );
  const auth = countingAuth();

  try {
    const result = await issueKakaoCustomToken({
      accessToken: 'token',
      createCustomToken: auth.createCustomToken,
    });
    const 직렬화 = JSON.stringify(result);
    assert.doesNotMatch(직렬화, /leak@example\.com|phone|birthday|gender|홍길동|profile_image/i, 직렬화);
    assert.deepEqual(Object.keys(result).sort(), ['customToken', 'nickname', 'uid']);
    assert.equal(auth.calls[0].claims, undefined, '커스텀 클레임에 아무것도 싣지 않는다');
  } finally {
    stub.restore();
  }
});

// 탐침 5 — 동시 호출이 서로의 결과를 섞지 않는다 (모듈 수준 가변 상태 탐지).
// 이 함수는 로그인 순간에만 불리지만 여러 사람이 동시에 로그인한다.
test('탐침: 50건을 동시에 태워도 uid 가 서로 섞이지 않는다', async () => {
  const stub = stubGlobalFetch((url, init) => {
    const id = Number(init.headers.Authorization.replace('Bearer token-', ''));
    return jsonResponse(200, { id, properties: { nickname: `팬${id}` } });
  });
  const auth = countingAuth();

  try {
    const ids = Array.from({ length: 50 }, (_, i) => i + 1);
    const results = await Promise.all(
      ids.map((id) =>
        issueKakaoCustomToken({ accessToken: `token-${id}`, createCustomToken: auth.createCustomToken }),
      ),
    );

    results.forEach((r, i) => {
      assert.equal(r.uid, `kakao:${ids[i]}`, `${i}번째가 섞였다: ${r.uid}`);
      assert.equal(r.customToken, `custom-token-for-kakao:${ids[i]}`);
      assert.equal(r.nickname, `팬${ids[i]}`);
    });
    assert.equal(auth.calls.length, 50, '발급 횟수가 호출 수와 다르다');
    assert.equal(new Set(auth.calls.map((c) => c.uid)).size, 50);
  } finally {
    stub.restore();
  }
});

// 탐침 6 — 성공 판정이 상태 코드 200 계열에만 붙는가.
// 커밋된 테스트는 200/401/403/5xx/429 만 잰다. 3xx 와 본문 없는 2xx 가 남아 있다.
test('탐침: 3xx·본문 없는 2xx 는 발급 없이 오류로 끝난다', async () => {
  for (const [status, body] of [
    [204, null],
    [301, null],
    [302, { id: 1 }],
    [200, {}],
    [200, []],
    [200, 'not-an-object'],
  ]) {
    const stub = stubGlobalFetch(() => jsonResponse(status, body));
    const auth = countingAuth();
    try {
      await assert.rejects(
        () => issueKakaoCustomToken({ accessToken: 'token', createCustomToken: auth.createCustomToken }),
        (err) => err instanceof KakaoAuthError,
        `status=${status} body=${JSON.stringify(body)} 가 통과했다`,
      );
      assert.equal(auth.calls.length, 0, `status=${status} 로 토큰이 발급됐다`);
    } finally {
      stub.restore();
    }
  }
});

// 탐침 8 — 진짜 Admin SDK 가 `kakao:{id}` 모양의 uid 를 받아 주는가.
// 커밋된 테스트는 발급 자리를 전부 가짜로 세운다. 그래서 "uid 에 콜론을 쓴다"는
// 결정이 실제 SDK 에서 성립하는지는 아무도 밟지 않는다 — 여기서 밟는다.
// 네트워크는 쓰지 않는다: 에뮬레이터 서명자는 요청 없이 토큰을 만든다(아래 주석 참조).
process.env.GCLOUD_PROJECT ??= 'demo-kbo-away-fans';
// 이 값이 있으면 Admin SDK 는 서명 키를 받으러 나가지 않고 빈 서명으로 토큰을 만든다.
// (포트가 닫혀 있어도 성공하는 것이 나가지 않는다는 증거다.)
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

let adminAuth = null;
try {
  const { initializeApp } = await import('firebase-admin/app');
  const { getAuth } = await import('firebase-admin/auth');
  initializeApp();
  adminAuth = getAuth();
} catch (err) {
  if (err?.code !== 'ERR_MODULE_NOT_FOUND') throw err;
}
const adminSkip = adminAuth === null ? 'firebase SDK 미설치 (npm ci --prefix functions)' : false;

test('탐침: Admin SDK 가 `kakao:{id}` uid 를 받고 토큰에 그 uid 만 싣는다', { skip: adminSkip }, async () => {
  const uid = 'kakao:8123456';
  const token = await adminAuth.createCustomToken(uid);
  const claims = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString());

  assert.equal(claims.uid, uid);
  // 닉네임 등 부가 정보가 토큰에 실리지 않는다 (표준 클레임 + uid 뿐).
  assert.deepEqual(Object.keys(claims).sort(), ['aud', 'exp', 'iat', 'iss', 'sub', 'uid']);

  // 128자를 넘는 uid 는 SDK 가 거부한다 — 탐침 7 이 가정한 자리의 실물 확인.
  await assert.rejects(async () => adminAuth.createCustomToken(`kakao:${'9'.repeat(200)}`), /128/);
});

// 탐침 7 — 발급된 uid 가 Firebase 커스텀 토큰 uid 의 길이 한도(128자) 안에 있는가.
// 카카오 id 는 숫자열이면 길이 제한이 없어 그대로 접두에 붙으면 한도를 넘을 수 있고,
// 그때 Admin SDK 가 던지는 자리가 발급 경로 한가운데다.
test('탐침: 아주 긴 카카오 id 도 발급 경로를 조용히 지나지 않는다', async () => {
  const 긴id = '9'.repeat(200);
  const auth = {
    calls: [],
    createCustomToken: async (uid) => {
      auth.calls.push(uid);
      // Admin SDK 의 실제 검사와 같은 자리 (uid 는 1~128자).
      if (uid.length > 128) throw new Error('uid must be 128 characters or fewer');
      return `custom-token-for-${uid}`;
    },
  };

  const stub = stubGlobalFetch(() => jsonResponse(200, { id: 긴id }));
  try {
    await assert.rejects(
      () => issueKakaoCustomToken({ accessToken: 'token', createCustomToken: auth.createCustomToken }),
      (err) => err instanceof KakaoAuthError && err.code === 'internal',
      `길이 ${긴id.length} 인 id 가 발급까지 갔다`,
    );
  } finally {
    stub.restore();
  }
});
