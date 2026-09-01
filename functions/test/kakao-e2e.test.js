// 카카오 로그인 경로의 이음매 테스트 — 주입 없이 **기본 배선**을 통째로 지난다.
//
// `kakao.test.js` 는 `fetch` 를 주입해 카카오 계층만, `custom-token.test.js` 는
// `fetchProfile` 을 주입해 발급 순서만 잰다. 둘 사이의 배선(주입 없이
// `issueKakaoCustomToken` 이 `fetchKakaoProfile` 을 부르고 그것이 `globalThis.fetch`
// 를 부르는 경로)은 그 두 파일이 지나가지 않는다 — 이 파일이 그 자리를 맡는다.
// 함께 재는 것: uid 공간 침범 시도, 오류 본문이 JSON 이 아닌 응답, 헤더 주입,
// 그리고 callable 경계에서 본 실패 모양.
//
// 실제 카카오·Firebase 로는 나가지 않는다: `globalThis.fetch` 를 이 파일 안에서
// 가짜로 갈아 끼우고(node --test 는 파일마다 별도 프로세스라 격리된다), 성공
// 경로에서 Admin SDK 를 부르는 자리는 부르지 않는다.
import assert from 'node:assert/strict';
import test from 'node:test';

import { KakaoAuthError, fetchKakaoProfile } from '../kakao.js';
import { issueKakaoCustomToken } from '../custom-token.js';

process.env.GCLOUD_PROJECT ??= 'demo-kbo-away-fans';

/** 응답 하나를 돌려주는 가짜 전역 fetch — 나간 요청을 기록한다. */
function stubGlobalFetch(handler) {
  const calls = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), init });
    return handler(String(url), init);
  };
  return {
    calls,
    restore() {
      globalThis.fetch = original;
    },
  };
}

function jsonResponse(status, body, { brokenBody = false } = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => {
      if (brokenBody) throw new SyntaxError('Unexpected token < in JSON at position 0');
      return body;
    },
  };
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

// ───────────────────────────────────────────────────────────────────────────
// 기본 배선(주입 없음)으로 성공 경로 전체를 지나 토큰이 **한 번** 발급되는가.
test('주입 없이 기본 배선으로도 유효 토큰 → 결정적 uid 로 1회 발급', async () => {
  const stub = stubGlobalFetch(() =>
    jsonResponse(200, { id: 8123456, properties: { nickname: '원정팬' } }),
  );
  const auth = countingAuth();

  try {
    const result = await issueKakaoCustomToken({
      accessToken: 'valid-access-token',
      createCustomToken: auth.createCustomToken,
    });

    assert.equal(auth.calls.length, 1);
    assert.equal(result.uid, 'kakao:8123456');
    assert.equal(result.customToken, 'custom-token-for-kakao:8123456');
    assert.equal(result.nickname, '원정팬');

    // 기본 배선이 실제로 카카오 자리로 나갔는지 — 그리고 이메일 동의를 얹지 않았는지.
    assert.equal(stub.calls.length, 1);
    const outgoing = stub.calls[0].url;
    assert.ok(outgoing.startsWith('https://kapi.kakao.com/v2/user/me'), outgoing);
    assert.deepEqual(
      JSON.parse(new URL(outgoing).searchParams.get('property_keys')),
      ['properties.nickname'],
    );
    assert.doesNotMatch(
      outgoing,
      /kakao_account|email|phone_number|gender|birthday|birthyear|age_range|legal_name|shipping/i,
    );
  } finally {
    stub.restore();
  }
});

// ───────────────────────────────────────────────────────────────────────────
// 응답으로 나가는 닉네임이 사용자 문서 계약의 단위(UTF-16 코드 단위 20)를
// 이미 만족하는가 — 여기서 넘치면 2.4 가 만드는 사용자 문서가 규칙에서
// PERMISSION_DENIED 로 거부된다. 규칙 쪽 짝은 `firebase/test/rules.test.mjs`.
test('응답의 닉네임은 규칙이 세는 단위(UTF-16 20)를 넘지 않는다', async () => {
  const 긴닉네임 = ['가'.repeat(18) + '🐯'.repeat(2), '🐯'.repeat(30), '가'.repeat(30)];

  for (const nickname of 긴닉네임) {
    const stub = stubGlobalFetch(() => jsonResponse(200, { id: 8123456, properties: { nickname } }));
    const auth = countingAuth();
    try {
      const { nickname: 받은값 } = await issueKakaoCustomToken({
        accessToken: 'valid-access-token',
        createCustomToken: auth.createCustomToken,
      });
      assert.ok(받은값.length >= 1 && 받은값.length <= 20, `${nickname} → ${받은값.length}단위`);
    } finally {
      stub.restore();
    }
  }
});

// ───────────────────────────────────────────────────────────────────────────
// 기본 배선에서 카카오가 401 이면 발급이 **0회** 인가 (acceptance 의 실패 방향).
test('기본 배선에서 카카오 401 이면 Admin SDK 를 아예 부르지 않는다', async () => {
  const stub = stubGlobalFetch(() =>
    jsonResponse(401, { msg: 'this access token does not exist', code: -401 }),
  );
  const auth = countingAuth();

  try {
    await assert.rejects(
      () =>
        issueKakaoCustomToken({
          accessToken: 'expired-token',
          createCustomToken: auth.createCustomToken,
        }),
      (err) => err instanceof KakaoAuthError && err.code === 'unauthenticated' && err.status === 401,
    );
    assert.equal(auth.calls.length, 0, '검증 실패인데 커스텀 토큰이 발급됐습니다');
  } finally {
    stub.restore();
  }
});

// ───────────────────────────────────────────────────────────────────────────
// 카카오가 준 id 가 숫자열이 아니면(제공자 공간 침범 시도 포함) 발급이 없어야 한다.
// uid 는 곧 `users/{uid}` 경로라 여기서 새면 남의 문서를 가리킬 수 있다.
test('숫자열이 아닌 카카오 id 는 어떤 모양이든 발급 0회로 끝난다', async () => {
  const 이상한값 = [
    'kakao:1', // 접두를 스스로 들고 와 이중 접두를 노리는 모양
    '../8123456', // 경로 조작
    '81 23456',
    '8123456\n',
    '-1',
    '1.5',
    '0x10',
    '',
    null,
    undefined,
    1.5,
    -7,
    { toString: () => '8123456' },
  ];

  for (const id of 이상한값) {
    const auth = countingAuth();
    await assert.rejects(
      () =>
        issueKakaoCustomToken({
          accessToken: 'token',
          fetchProfile: async () => ({ id, nickname: null }),
          createCustomToken: auth.createCustomToken,
        }),
      (err) => err instanceof KakaoAuthError && err.code === 'internal',
      `id=${JSON.stringify(id)} 가 통과했습니다`,
    );
    assert.equal(auth.calls.length, 0, `id=${JSON.stringify(id)} 로 토큰이 발급됐습니다`);
  }
});

// ───────────────────────────────────────────────────────────────────────────
// 카카오 id 가 안전 정수 범위를 넘으면(JSON 숫자 정밀도가 뭉개지는 자리) 발급이 없어야 한다.
// 뭉개진 id 를 그대로 실으면 두 사람이 같은 uid 를 받는다.
test('안전 정수를 넘는 카카오 id 는 발급 없이 internal 로 끊긴다', async () => {
  // JSON.parse 를 실제로 지나게 해서 정밀도 손실을 그대로 재현한다.
  const body = JSON.parse('{"id": 9007199254740993, "properties": {"nickname": "큰id"}}');
  assert.equal(body.id, 9007199254740992, '전제: JSON 숫자가 이미 뭉개진다');

  const stub = stubGlobalFetch(() => jsonResponse(200, body));
  const auth = countingAuth();

  try {
    await assert.rejects(
      () =>
        issueKakaoCustomToken({
          accessToken: 'token',
          createCustomToken: auth.createCustomToken,
        }),
      (err) => err instanceof KakaoAuthError && err.code === 'internal',
    );
    assert.equal(auth.calls.length, 0);
  } finally {
    stub.restore();
  }
});

// ───────────────────────────────────────────────────────────────────────────
// 오류 응답의 본문이 JSON 이 아닐 때(게이트웨이 HTML 등) 상태 코드 판정이 흔들리지 않는가.
// `kakao.test.js` 는 오류 본문이 항상 JSON 인 경우만 잰다.
test('오류 본문이 JSON 이 아니어도 상태 코드로 판정한다', async () => {
  for (const [status, code] of [
    [401, 'unauthenticated'],
    [403, 'permission-denied'],
    [502, 'unavailable'],
    [429, 'internal'],
  ]) {
    const stub = stubGlobalFetch(() => jsonResponse(status, null, { brokenBody: true }));
    try {
      await assert.rejects(
        () => fetchKakaoProfile('token'),
        (err) =>
          err instanceof KakaoAuthError &&
          err.code === code &&
          err.status === status &&
          err.kakaoCode === null,
        `status=${status}`,
      );
    } finally {
      stub.restore();
    }
  }
});

// ───────────────────────────────────────────────────────────────────────────
// 액세스 토큰은 사용자가 준 값이 그대로 Authorization 헤더로 들어간다.
// 헤더를 검사하는 fetch(=undici 의 실제 동작) 아래에서 헤더가 갈라지지 않고
// 발급도 일어나지 않는지 — 헤더 주입이 성공하면 여기서 드러난다.
test('개행이 섞인 액세스 토큰은 헤더를 가르지 못하고 발급 0회로 끝난다', async () => {
  const stub = stubGlobalFetch((url, init) => {
    // 실제 fetch 처럼 헤더 값을 검증한다 (undici 는 여기서 TypeError 를 던진다).
    new Headers(init.headers);
    return jsonResponse(200, { id: 1 });
  });
  const auth = countingAuth();

  try {
    await assert.rejects(
      () =>
        issueKakaoCustomToken({
          accessToken: 'good-token\r\nX-Injected: 1',
          createCustomToken: auth.createCustomToken,
        }),
      (err) => err instanceof KakaoAuthError,
    );
    assert.equal(auth.calls.length, 0);
  } finally {
    stub.restore();
  }
});

// ───────────────────────────────────────────────────────────────────────────
// callable 경계에서 본 acceptance: 카카오가 401 이면 HttpsError 로만 나가고
// 응답 본문에 토큰이 실리지 않는다. (Firebase SDK 가 없으면 건너뛴다.)
let functions = null;
try {
  functions = await import('../index.js');
} catch (err) {
  if (err?.code !== 'ERR_MODULE_NOT_FOUND') throw err;
}
const skip = functions === null ? 'firebase SDK 미설치 (npm ci --prefix functions)' : false;

test('callable 경계에서도 카카오 401 은 토큰 없이 unauthenticated 로만 나간다', { skip }, async () => {
  const stub = stubGlobalFetch(() => jsonResponse(401, { msg: 'invalid token', code: -401 }));

  try {
    await assert.rejects(
      () => functions.kakaoCustomToken.run({ data: { accessToken: '만료된-토큰' } }),
      (err) => {
        assert.equal(err.code, 'unauthenticated');
        assert.equal(err.httpErrorCode.status, 401);
        // 실패 응답 어디에도 커스텀 토큰이 없다.
        assert.doesNotMatch(JSON.stringify(err.toJSON?.() ?? {}), /customToken/);
        return true;
      },
    );
    assert.equal(stub.calls.length, 1, '카카오 호출이 정확히 한 번이어야 합니다');
  } finally {
    stub.restore();
  }
});

test('callable 경계에서 카카오가 닿지 않으면 unavailable 로 나간다', { skip }, async () => {
  const stub = stubGlobalFetch(() => {
    throw new Error('connect ETIMEDOUT');
  });

  try {
    await assert.rejects(
      () => functions.kakaoCustomToken.run({ data: { accessToken: '토큰' } }),
      (err) => err.code === 'unavailable' && err.httpErrorCode.status === 503,
    );
  } finally {
    stub.restore();
  }
});
