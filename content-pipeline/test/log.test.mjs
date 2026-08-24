// log.mjs 단위 테스트 — JSON Lines 포맷과 레벨/필드 구조 검증.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createLogger } from '../common/log.mjs';

function capture() {
  const lines = [];
  return { lines, write: (line) => lines.push(line) };
}

test('로그 한 건은 ts/level/script/event 를 갖춘 한 줄 JSON 이다', () => {
  const { lines, write } = capture();
  const fixed = new Date('2026-08-24T12:00:00.000Z');
  const log = createLogger('schedule-crawler', { write, now: () => fixed });

  log.info('crawl_start', { url: 'https://example.test' });

  assert.equal(lines.length, 1);
  const entry = JSON.parse(lines[0]);
  assert.deepEqual(entry, {
    ts: '2026-08-24T12:00:00.000Z',
    level: 'info',
    script: 'schedule-crawler',
    event: 'crawl_start',
    url: 'https://example.test',
  });
});

test('debug/info/warn/error 네 레벨을 제공한다', () => {
  const { lines, write } = capture();
  const log = createLogger('t', { write });
  log.debug('d');
  log.info('i');
  log.warn('w');
  log.error('e');
  assert.deepEqual(
    lines.map((l) => JSON.parse(l).level),
    ['debug', 'info', 'warn', 'error'],
  );
});

test('필드 없이 호출해도 유효한 JSON 을 남긴다', () => {
  const { lines, write } = capture();
  createLogger('t', { write }).info('bare');
  const entry = JSON.parse(lines[0]);
  assert.equal(entry.event, 'bare');
});
