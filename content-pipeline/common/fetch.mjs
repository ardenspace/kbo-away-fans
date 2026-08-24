// HTTP fetch 공통 — 재시도·타임아웃·User-Agent 를 한곳에서 관리한다.
// 모든 크롤러·빌드 스크립트의 외부 요청은 이 모듈을 통과한다 (REGISTRY.md 규칙).
//
// 사용법:
//   import { fetchWithRetry } from './fetch.mjs';
//   const res = await fetchWithRetry('https://example.com/schedule');
//   const html = await res.text();
//
// 재시도 정책 (기본값, 옵션으로 조정 가능):
//   - 최대 3회 재시도 (최초 시도 포함 총 4회)
//   - 시도당 타임아웃 10초 (AbortSignal)
//   - 지수 백오프: 500ms → 1s → 2s …
//   - 재시도 대상: 네트워크 오류, 타임아웃, HTTP 429/5xx
//   - 재시도 제외: 그 외 4xx (요청 자체가 잘못된 것이라 반복해도 소용없음)

/** 재시도 소진 후에도 실패했을 때 던지는 오류. */
export class FetchRetryError extends Error {
  /**
   * @param {string} message
   * @param {{ url: string, attempts: number, lastStatus?: number, cause?: unknown }} info
   */
  constructor(message, { url, attempts, lastStatus, cause }) {
    super(message, { cause });
    this.name = 'FetchRetryError';
    this.url = url;
    this.attempts = attempts;
    this.lastStatus = lastStatus;
  }
}

export const FETCH_DEFAULTS = Object.freeze({
  retries: 3,
  timeoutMs: 10_000,
  backoffBaseMs: 500,
  userAgent: 'kbo-away-fans-content-pipeline/0.1',
});

/** HTTP 상태 코드가 재시도할 가치가 있는지. */
export function isRetriableStatus(status) {
  return status === 429 || (status >= 500 && status < 600);
}

const defaultSleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * 재시도·타임아웃이 걸린 fetch. 성공(2xx~3xx 등 ok 여부와 무관하게
 * "재시도 불필요"인 응답)이면 Response 를 그대로 반환하고,
 * 재시도를 소진하면 FetchRetryError 를 던진다.
 *
 * @param {string | URL} url
 * @param {object} [options]
 * @param {number} [options.retries]        최대 재시도 횟수 (기본 3)
 * @param {number} [options.timeoutMs]      시도당 타임아웃 ms (기본 10000)
 * @param {number} [options.backoffBaseMs]  백오프 기점 ms (기본 500, 지수 증가)
 * @param {Record<string, string>} [options.headers]
 * @param {RequestInit} [options.init]      추가 fetch 옵션 (method, body 등)
 * @param {typeof fetch} [options.fetchImpl]  테스트용 fetch 주입점
 * @param {(ms: number) => Promise<void>} [options.sleep]  테스트용 대기 주입점
 * @param {{ warn: (event: string, fields?: object) => void }} [options.logger]
 * @returns {Promise<Response>}
 */
export async function fetchWithRetry(url, options = {}) {
  const {
    retries = FETCH_DEFAULTS.retries,
    timeoutMs = FETCH_DEFAULTS.timeoutMs,
    backoffBaseMs = FETCH_DEFAULTS.backoffBaseMs,
    headers = {},
    init = {},
    fetchImpl = fetch,
    sleep = defaultSleep,
    logger,
  } = options;

  const maxAttempts = retries + 1;
  let lastStatus;
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const response = await fetchImpl(url, {
        ...init,
        headers: { 'User-Agent': FETCH_DEFAULTS.userAgent, ...headers },
        signal: AbortSignal.timeout(timeoutMs),
      });

      if (!isRetriableStatus(response.status)) {
        return response; // ok 여부 판단은 호출자 몫 — 4xx 는 반복해도 안 변한다.
      }
      lastStatus = response.status;
      lastError = undefined;
      logger?.warn('fetch_retry', { url: String(url), attempt, status: response.status });
    } catch (err) {
      lastStatus = undefined;
      lastError = err;
      logger?.warn('fetch_retry', { url: String(url), attempt, error: String(err) });
    }

    if (attempt < maxAttempts) {
      await sleep(backoffBaseMs * 2 ** (attempt - 1));
    }
  }

  throw new FetchRetryError(
    `fetch 실패 (${maxAttempts}회 시도 소진): ${url}` +
      (lastStatus !== undefined ? ` — 마지막 상태 ${lastStatus}` : '') +
      (lastError !== undefined ? ` — ${lastError}` : ''),
    { url: String(url), attempts: maxAttempts, lastStatus, cause: lastError },
  );
}
