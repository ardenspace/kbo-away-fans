// fetch.mjs 단위 테스트 — 재시도·타임아웃·백오프·User-Agent 동작 검증.
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  fetchWithRetry,
  FetchRetryError,
  isRetriableStatus,
  FETCH_DEFAULTS,
} from '../common/fetch.mjs';

const immediateSleep = async () => {};

/** 호출 기록을 남기는 가짜 fetch 를 만든다. responses 를 순서대로 소비한다. */
function fakeFetch(responses) {
  const calls = [];
  const impl = async (url, init) => {
    calls.push({ url: String(url), init });
    const next = responses[Math.min(calls.length - 1, responses.length - 1)];
    if (next instanceof Error) throw next;
    return next;
  };
  return { impl, calls };
}

test('첫 시도 성공이면 재시도 없이 응답을 반환한다', async () => {
  const { impl, calls } = fakeFetch([new Response('ok', { status: 200 })]);
  const res = await fetchWithRetry('https://example.test/a', {
    fetchImpl: impl,
    sleep: immediateSleep,
  });
  assert.equal(res.status, 200);
  assert.equal(calls.length, 1);
});

test('User-Agent 헤더가 기본으로 붙는다', async () => {
  const { impl, calls } = fakeFetch([new Response('ok', { status: 200 })]);
  await fetchWithRetry('https://example.test/ua', { fetchImpl: impl, sleep: immediateSleep });
  assert.equal(calls[0].init.headers['User-Agent'], FETCH_DEFAULTS.userAgent);
});

test('5xx 응답이면 재시도하고, 성공하면 그 응답을 반환한다', async () => {
  const { impl, calls } = fakeFetch([
    new Response('boom', { status: 500 }),
    new Response('boom', { status: 503 }),
    new Response('ok', { status: 200 }),
  ]);
  const res = await fetchWithRetry('https://example.test/flaky', {
    fetchImpl: impl,
    sleep: immediateSleep,
  });
  assert.equal(res.status, 200);
  assert.equal(calls.length, 3);
});

test('네트워크 오류도 재시도 대상이다', async () => {
  const { impl, calls } = fakeFetch([
    new TypeError('fetch failed'),
    new Response('ok', { status: 200 }),
  ]);
  const res = await fetchWithRetry('https://example.test/net', {
    fetchImpl: impl,
    sleep: immediateSleep,
  });
  assert.equal(res.status, 200);
  assert.equal(calls.length, 2);
});

test('재시도를 소진하면 FetchRetryError 를 던진다 (시도 횟수 = retries+1)', async () => {
  const { impl, calls } = fakeFetch([new Response('boom', { status: 500 })]);
  await assert.rejects(
    fetchWithRetry('https://example.test/dead', {
      retries: 2,
      fetchImpl: impl,
      sleep: immediateSleep,
    }),
    (err) => {
      assert.ok(err instanceof FetchRetryError);
      assert.equal(err.attempts, 3);
      assert.equal(err.lastStatus, 500);
      return true;
    },
  );
  assert.equal(calls.length, 3);
});

test('429 이외의 4xx 는 재시도하지 않고 응답을 그대로 반환한다', async () => {
  const { impl, calls } = fakeFetch([new Response('nope', { status: 404 })]);
  const res = await fetchWithRetry('https://example.test/missing', {
    fetchImpl: impl,
    sleep: immediateSleep,
  });
  assert.equal(res.status, 404);
  assert.equal(calls.length, 1);
});

test('429 는 재시도 대상이다', () => {
  assert.equal(isRetriableStatus(429), true);
  assert.equal(isRetriableStatus(500), true);
  assert.equal(isRetriableStatus(404), false);
  assert.equal(isRetriableStatus(200), false);
});

test('백오프는 지수로 증가한다 (base * 2^n)', async () => {
  const { impl } = fakeFetch([new Response('boom', { status: 500 })]);
  const delays = [];
  await assert.rejects(
    fetchWithRetry('https://example.test/backoff', {
      retries: 3,
      backoffBaseMs: 100,
      fetchImpl: impl,
      sleep: async (ms) => delays.push(ms),
    }),
    FetchRetryError,
  );
  assert.deepEqual(delays, [100, 200, 400]);
});

test('타임아웃되면 해당 시도는 실패로 치고 재시도한다', async () => {
  let hangs = 0;
  const impl = (url, init) =>
    new Promise((resolve, reject) => {
      if (hangs === 0) {
        hangs += 1;
        init.signal.addEventListener('abort', () => reject(init.signal.reason));
      } else {
        resolve(new Response('ok', { status: 200 }));
      }
    });
  const res = await fetchWithRetry('https://example.test/slow', {
    timeoutMs: 20,
    fetchImpl: impl,
    sleep: immediateSleep,
  });
  assert.equal(res.status, 200);
  assert.equal(hangs, 1);
});
