// App Check 강제를 **동작으로** 잰다 — 소스 문자열 검사가 아니라.
//
// `index.test.js` 의 소스 검사는 "`enforceAppCheck: true` 라고 적혀 있다"까지만
// 말한다. 실제로 막히는지는 옵션이 firebase-functions 의 요청 처리에 닿아야만
// 드러나고, `kakaoCustomToken.run(...)` 은 그 처리를 **건너뛴다**(핸들러를 바로
// 부른다). 그래서 여기서는 함수를 express 핸들러 그대로 세우고 HTTP 로 부른다.
//
// 재는 것은 셋이다:
//   1. App Check 토큰 없는 호출이 401 `UNAUTHENTICATED` 로 거절된다
//   2. 거절이 **함수 몸보다 먼저** 일어난다 — 카카오로 나가지 않는다
//      (부르는 것 자체가 카카오 API 왕복이고 그것이 요금이다)
//   3. 위조된 토큰도 거절된다 (`MISSING` 과 `INVALID` 는 서로 다른 갈래다)
//
// 네트워크로 나가지 않는다: `globalThis.fetch` 를 갈아 끼워 카카오 호출을 세고,
// 강제가 서 있는 한 그 수는 0 이다.
import assert from 'node:assert/strict';
import test from 'node:test';
import http from 'node:http';
import express from 'express';

// 에뮬레이터 전용 접두 — 어떤 요청도 이 id 로 클라우드에 나가지 않는다.
process.env.GCLOUD_PROJECT ??= 'demo-kbo-away-fans';

let functions = null;
try {
  functions = await import('../index.js');
} catch (err) {
  if (err?.code !== 'ERR_MODULE_NOT_FOUND') throw err;
}

const skip = functions === null ? 'firebase SDK 미설치 (npm ci --prefix functions)' : false;

/** 함수를 express 핸들러로 세우고 한 번 부른다. 카카오 호출 수를 함께 돌려준다. */
async function callOverHttp(headers) {
  const realFetch = globalThis.fetch;
  let kakaoCalls = 0;
  globalThis.fetch = (url, init) => {
    if (String(url).includes('kapi.kakao.com')) {
      kakaoCalls += 1;
      return Promise.resolve(new Response('{}', { status: 200 }));
    }
    return realFetch(url, init);
  };

  const app = express();
  app.use(express.json());
  app.post('/', (req, res) => functions.kakaoCustomToken(req, res));
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));

  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify({ data: { accessToken: 'irrelevant' } }),
    });
    let body = null;
    try {
      body = await response.json();
    } catch {
      body = null;
    }
    return { status: response.status, body, kakaoCalls };
  } finally {
    globalThis.fetch = realFetch;
    await new Promise((resolve) => server.close(resolve));
  }
}

test('App Check 토큰 없는 호출은 거절되고 카카오로 나가지 않는다', { skip }, async () => {
  const { status, body, kakaoCalls } = await callOverHttp({});

  assert.equal(status, 401, 'App Check 토큰 없는 호출이 그대로 통과했다');
  assert.equal(body?.error?.status, 'UNAUTHENTICATED');
  assert.equal(
    kakaoCalls,
    0,
    '거절 전에 카카오 API 를 불렀다 — 남의 반복 호출이 그대로 요금이 되는 자리다',
  );
});

test('위조된 App Check 토큰도 거절된다', { skip }, async () => {
  const { status, body, kakaoCalls } = await callOverHttp({
    'X-Firebase-AppCheck': 'not-a-real-token',
  });

  assert.equal(status, 401);
  assert.equal(body?.error?.status, 'UNAUTHENTICATED');
  assert.equal(kakaoCalls, 0);
});
