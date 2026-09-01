// 카카오 호출 자리의 단위 테스트 — 실제 카카오 서버에는 붙지 않는다.
// fetch 를 주입해 저장된 모양의 응답만 돌려주고, 나가는 요청의 모양을 단언한다.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import test from 'node:test';

import {
  KAKAO_USER_ME_URL,
  KakaoAuthError,
  fetchKakaoProfile,
} from '../kakao.js';

const functionsDir = dirname(dirname(fileURLToPath(import.meta.url)));

/** 응답 하나만 돌려주는 가짜 fetch — 호출 인자를 기록한다. */
function fakeFetch(response) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url: String(url), init });
    if (response instanceof Error) throw response;
    return response;
  };
  impl.calls = calls;
  return impl;
}

/** Response 를 흉내 내는 최소 객체 (Node 의 fetch 응답 중 우리가 쓰는 면만). */
function jsonResponse(status, body) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
    text: async () => JSON.stringify(body),
  };
}

test('유효한 토큰이면 카카오 사용자 id 와 닉네임을 돌려준다', async () => {
  const fetchImpl = fakeFetch(
    jsonResponse(200, { id: 8123456, properties: { nickname: '원정팬' } }),
  );

  const profile = await fetchKakaoProfile('valid-access-token', {
    fetch: fetchImpl,
  });

  assert.deepEqual(profile, { id: '8123456', nickname: '원정팬' });
  assert.equal(fetchImpl.calls.length, 1);
});

test('요청은 /v2/user/me 에 Bearer 헤더로 나가고 닉네임 말고는 아무 항목도 요구하지 않는다', async () => {
  const fetchImpl = fakeFetch(jsonResponse(200, { id: 1, properties: {} }));

  await fetchKakaoProfile('valid-access-token', { fetch: fetchImpl });

  const [{ url, init }] = fetchImpl.calls;
  assert.ok(url.startsWith(KAKAO_USER_ME_URL), `예상 밖 URL: ${url}`);
  assert.equal(init.method, 'GET');
  assert.equal(init.headers.Authorization, 'Bearer valid-access-token');

  // 동의 항목 경계: 요청에 이메일·전화·성별 등 추가 동의 항목이 실리지 않는다.
  const requested = new URL(url).searchParams.get('property_keys');
  assert.deepEqual(JSON.parse(requested), ['properties.nickname']);
  assert.doesNotMatch(url, /email|phone|gender|birth|age_range|legal_name|shipping/i);
});

test('닉네임 동의가 없으면 닉네임은 null 이고 id 는 그대로 나온다', async () => {
  const fetchImpl = fakeFetch(jsonResponse(200, { id: 42 }));

  const profile = await fetchKakaoProfile('valid-access-token', {
    fetch: fetchImpl,
  });

  assert.deepEqual(profile, { id: '42', nickname: null });
});

test('닉네임은 앞뒤 공백을 털고 20자로 자른다 (users 문서 계약)', async () => {
  const fetchImpl = fakeFetch(
    jsonResponse(200, { id: 7, properties: { nickname: `  ${'가'.repeat(30)}  ` } }),
  );

  const profile = await fetchKakaoProfile('valid-access-token', {
    fetch: fetchImpl,
  });

  assert.equal(profile.nickname, '가'.repeat(20));
});

test('닉네임을 자를 때 이모지의 짝을 가르지 않는다 (코드 포인트 단위)', async () => {
  // UTF-16 단위로 자르면 21번째 이모지의 절반이 남아 깨진 문자가 된다.
  const fetchImpl = fakeFetch(
    jsonResponse(200, { id: 7, properties: { nickname: '⚾️'.repeat(3) + '🐯'.repeat(30) } }),
  );

  const profile = await fetchKakaoProfile('valid-access-token', {
    fetch: fetchImpl,
  });

  assert.equal([...profile.nickname].length, 20);
  assert.doesNotMatch(profile.nickname, /[\uD800-\uDFFF]/u, '짝 잃은 서러게이트가 남았습니다');
});

test('401 이면 unauthenticated 오류를 던진다', async () => {
  const fetchImpl = fakeFetch(
    jsonResponse(401, { msg: 'this access token does not exist', code: -401 }),
  );

  await assert.rejects(
    () => fetchKakaoProfile('expired-token', { fetch: fetchImpl }),
    (err) => {
      assert.ok(err instanceof KakaoAuthError);
      assert.equal(err.code, 'unauthenticated');
      assert.equal(err.status, 401);
      return true;
    },
  );
});

test('403 이면 permission-denied 오류를 던진다', async () => {
  const fetchImpl = fakeFetch(jsonResponse(403, { msg: 'insufficient scope', code: -402 }));

  await assert.rejects(
    () => fetchKakaoProfile('token', { fetch: fetchImpl }),
    (err) => err instanceof KakaoAuthError && err.code === 'permission-denied',
  );
});

test('카카오가 5xx 로 답하면 unavailable 오류를 던진다', async () => {
  const fetchImpl = fakeFetch(jsonResponse(503, { msg: 'service unavailable' }));

  await assert.rejects(
    () => fetchKakaoProfile('token', { fetch: fetchImpl }),
    (err) => err instanceof KakaoAuthError && err.code === 'unavailable',
  );
});

test('네트워크 자체가 실패해도 unavailable 오류로 나온다 (원인은 들고 간다)', async () => {
  const cause = new Error('connect ETIMEDOUT');
  const fetchImpl = fakeFetch(cause);

  await assert.rejects(
    () => fetchKakaoProfile('token', { fetch: fetchImpl }),
    (err) =>
      err instanceof KakaoAuthError && err.code === 'unavailable' && err.cause === cause,
  );
});

test('200 인데 id 가 없으면 internal 오류 — 토큰 발급으로 넘어가지 않는다', async () => {
  const fetchImpl = fakeFetch(jsonResponse(200, { properties: { nickname: '원정팬' } }));

  await assert.rejects(
    () => fetchKakaoProfile('token', { fetch: fetchImpl }),
    (err) => err instanceof KakaoAuthError && err.code === 'internal',
  );
});

test('빈 액세스 토큰이면 카카오를 호출하지 않고 invalid-argument 로 끝난다', async () => {
  const fetchImpl = fakeFetch(jsonResponse(200, { id: 1 }));

  await assert.rejects(
    () => fetchKakaoProfile('   ', { fetch: fetchImpl }),
    (err) => err instanceof KakaoAuthError && err.code === 'invalid-argument',
  );
  assert.equal(fetchImpl.calls.length, 0);
});

test('카카오 API 호출은 kakao.js 한 자리에서만 일어난다', () => {
  const sources = readdirSync(functionsDir, { withFileTypes: true })
    .filter((e) => e.isFile() && e.name.endsWith('.js'))
    .map((e) => e.name);

  const callers = sources.filter((name) =>
    /\bfetch\s*\(|kapi\.kakao\.com|kauth\.kakao\.com/.test(
      readFileSync(join(functionsDir, name), 'utf8'),
    ),
  );

  assert.deepEqual(callers, ['kakao.js'], `카카오 호출 자리가 늘었습니다: ${callers}`);
});
