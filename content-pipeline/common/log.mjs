// 구조화 로깅 공통 — 크롤 성공/실패를 JSON Lines 로 남긴다.
// 모든 파이프라인 스크립트는 console.* 대신 이 로거를 쓴다 (REGISTRY.md 규칙).
//
// 사용법:
//   import { createLogger } from './log.mjs';
//   const log = createLogger('schedule-crawler');
//   log.info('crawl_start', { url });
//   log.error('crawl_fail', { url, error: String(err) });
//
// 포맷: 한 줄 JSON — { ts, level, script, event, ...fields }
// 출력: stderr (stdout 은 산출 데이터용으로 비워 둔다)

const LEVELS = ['debug', 'info', 'warn', 'error'];

/**
 * @param {string} script  로그를 남기는 스크립트 이름 (예: 'schedule-crawler')
 * @param {object} [options]
 * @param {(line: string) => void} [options.write]  테스트용 출력 주입점 (기본 stderr)
 * @param {() => Date} [options.now]                테스트용 시계 주입점
 * @returns {{ debug: Function, info: Function, warn: Function, error: Function }}
 */
export function createLogger(script, options = {}) {
  const {
    write = (line) => process.stderr.write(`${line}\n`),
    now = () => new Date(),
  } = options;

  const emit = (level, event, fields = {}) => {
    write(
      JSON.stringify({
        ts: now().toISOString(),
        level,
        script,
        event,
        ...fields,
      }),
    );
  };

  return Object.fromEntries(
    LEVELS.map((level) => [level, (event, fields) => emit(level, event, fields)]),
  );
}
