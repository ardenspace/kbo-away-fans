// crawl-schedule.mjs 단위 테스트 — 전부 저장된 픽스처(test/fixtures/crawl/) 기반.
// 실제 네트워크에 의존하지 않는다. boundary test 대응:
//   1) 저장된 응답 픽스처 → 파싱 결과 스냅샷 일치
//   2) 취소 표기 픽스처 → rain_canceled 매핑
//   3) 깨진 픽스처 → CLI exit 비0 + 산출물 미변경
//   4) 산출물이 validate 를 통과 (exit 0)
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  buildScheduleDocument,
  mapStatus,
  ScheduleParseError,
  crawlWindow,
} from '../crawl-schedule.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const pipelineRoot = path.join(here, '..');
const crawler = path.join(pipelineRoot, 'crawl-schedule.mjs');
const validator = path.join(pipelineRoot, 'common', 'validate.mjs');
const crawlFixtures = path.join(here, 'fixtures', 'crawl');

const fixture = (name) => path.join(crawlFixtures, name);
const loadJson = (p) => JSON.parse(readFileSync(p, 'utf8'));
const FIXED_NOW = () => new Date('2026-08-25T09:00:00Z');

function runCrawler(args) {
  return spawnSync(process.execPath, [crawler, ...args], { encoding: 'utf8' });
}

test('저장된 응답 픽스처 → 파싱 결과가 스냅샷과 일치한다', () => {
  const payload = loadJson(fixture('naver-schedule.sample.json'));
  const document = buildScheduleDocument(payload, { now: FIXED_NOW });
  assert.deepEqual(document, loadJson(fixture('naver-schedule.sample.expected.json')));
});

test('취소 표기 픽스처 → 우천 표기는 rain_canceled, 그 외 취소는 canceled', () => {
  const payload = loadJson(fixture('naver-schedule.rain-canceled.json'));
  const document = buildScheduleDocument(payload, { now: FIXED_NOW });
  const byId = Object.fromEntries(document.games.map((g) => [g.id, g.status]));
  assert.equal(byId['20260816HHSS02026'], 'rain_canceled');
  assert.equal(byId['20260816NCLT02026'], 'canceled');
});

test('경기전·진행 중은 scheduled, 끝난 경기(RESULT)는 finished 로 매핑된다', () => {
  assert.equal(
    mapStatus({ cancel: false, statusCode: 'BEFORE', statusInfo: '경기전' }),
    'scheduled',
  );
  assert.equal(
    mapStatus({ cancel: false, statusCode: 'STARTED', statusInfo: '9회말' }),
    'scheduled',
  );
  assert.equal(
    mapStatus({ cancel: false, statusCode: 'RESULT', statusInfo: '종료' }),
    'finished',
  );
  // 서스펜디드는 재개될 경기라 종료가 아니다.
  assert.equal(
    mapStatus({ cancel: false, statusCode: 'RESULT', suspended: true }),
    'scheduled',
  );
});

test('끝난 경기는 점수와 승패(홈 기준)를 담고, 안 끝난 경기는 담지 않는다', () => {
  const payload = loadJson(fixture('naver-schedule.finished.json'));
  const document = buildScheduleDocument(payload, { now: FIXED_NOW });
  const byId = Object.fromEntries(document.games.map((g) => [g.id, g]));

  const outcomeOf = (game) => ({
    status: game.status,
    homeScore: game.homeScore,
    awayScore: game.awayScore,
    result: game.result,
  });

  assert.equal(document.schemaVersion, 2);
  assert.deepEqual(outcomeOf(byId['20260823NCLG02026']), {
    status: 'finished',
    homeScore: 7,
    awayScore: 3,
    result: 'home_win',
  });
  assert.deepEqual(outcomeOf(byId['20260823HTSS02026']), {
    status: 'finished',
    homeScore: 1,
    awayScore: 4,
    result: 'away_win',
  });
  assert.deepEqual(outcomeOf(byId['20260823KTSK02026']), {
    status: 'finished',
    homeScore: 5,
    awayScore: 5,
    result: 'draw',
  });

  // 진행 중 경기는 중간 점수를 계약에 남기지 않는다.
  const inProgress = byId['20260823LTOB02026'];
  assert.equal(inProgress.status, 'scheduled');
  assert.equal('homeScore' in inProgress, false);
  assert.equal('awayScore' in inProgress, false);
  assert.equal('result' in inProgress, false);
});

test('끝난 경기인데 점수가 없으면 ScheduleParseError', () => {
  const payload = loadJson(fixture('naver-schedule.finished.json'));
  delete payload.result.games[0].homeTeamScore;
  assert.throws(() => buildScheduleDocument(payload, { now: FIXED_NOW }), ScheduleParseError);
});

test('끝난 경기 픽스처의 산출물이 validate 를 통과한다 (exit 0)', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-finished-'));
  const out = path.join(dir, 'schedule.json');

  const result = runCrawler(['--input', fixture('naver-schedule.finished.json'), '--out', out]);
  assert.equal(result.status, 0, result.stderr);

  const validation = spawnSync(process.execPath, [validator, out], { encoding: 'utf8' });
  assert.equal(validation.status, 0, validation.stderr);
});

test('이전 산출물의 rain_canceled 는 정규화된 취소 라벨로 강등되지 않는다', () => {
  const payload = loadJson(fixture('naver-schedule.rain-canceled.json'));
  // 네이버가 나중에 '경기취소' 로 정규화한 상황 재현
  for (const g of payload.result.games) g.statusInfo = '경기취소';
  const document = buildScheduleDocument(payload, {
    now: FIXED_NOW,
    previousGames: [{ id: '20260816HHSS02026', status: 'rain_canceled' }],
  });
  const byId = Object.fromEntries(document.games.map((g) => [g.id, g.status]));
  assert.equal(byId['20260816HHSS02026'], 'rain_canceled');
  assert.equal(byId['20260816NCLT02026'], 'canceled');
});

test('로스터 밖 구장(제2구장) 경기는 warn 로그와 함께 제외된다', () => {
  const payload = loadJson(fixture('naver-schedule.sample.json'));
  payload.result.games[0] = { ...payload.result.games[0], stadium: '울산' };
  const warns = [];
  const document = buildScheduleDocument(payload, {
    now: FIXED_NOW,
    logger: { warn: (event, fields) => warns.push({ event, ...fields }) },
  });
  assert.equal(document.games.length, 7);
  assert.deepEqual(warns, [
    { event: 'game_skipped', gameId: '20260822KTSK02026', reason: 'unknown_stadium', stadium: '울산' },
  ]);
});

test('result.games 가 없는 응답은 ScheduleParseError', () => {
  assert.throws(
    () => buildScheduleDocument({ code: 500, success: false }, { now: FIXED_NOW }),
    ScheduleParseError,
  );
});

test('산출 게임 id 가 중복되면 ScheduleParseError', () => {
  const payload = loadJson(fixture('naver-schedule.sample.json'));
  payload.result.games.push({ ...payload.result.games[0] });
  assert.throws(() => buildScheduleDocument(payload, { now: FIXED_NOW }), ScheduleParseError);
});

test('크롤 창은 KST 달력 날짜 기준이다', () => {
  // 2026-08-25 23:30 UTC = 2026-08-26 08:30 KST — KST 로는 이미 다음 날
  const window = crawlWindow(new Date('2026-08-25T23:30:00Z'), 3);
  assert.deepEqual(window, { fromDate: '2026-08-26', toDate: '2026-08-28' });
});

test('CLI: 깨진 픽스처 → exit 비0, 기존 산출물 미변경', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-broken-'));
  const out = path.join(dir, 'schedule.json');
  const original = '{"schemaVersion":1,"generatedAt":"2026-08-24T13:00:00Z","games":[]}\n';
  writeFileSync(out, original);

  const result = runCrawler(['--input', fixture('naver-schedule.broken.json'), '--out', out]);
  assert.notEqual(result.status, 0, result.stderr);
  assert.match(result.stderr, /crawl_fail/);
  assert.equal(readFileSync(out, 'utf8'), original, '실패 시 기존 산출물을 덮어쓰면 안 됨');
  assert.ok(!existsSync(path.join(dir, 'schedule.next.json')), '임시 파일이 남으면 안 됨');
});

test('CLI: 정상 픽스처 → exit 0, 산출물이 validate 를 통과한다 (exit 0)', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-ok-'));
  const out = path.join(dir, 'schedule.json');

  const result = runCrawler(['--input', fixture('naver-schedule.sample.json'), '--out', out]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /crawl_success/);

  const validation = spawnSync(process.execPath, [validator, out], { encoding: 'utf8' });
  assert.equal(validation.status, 0, validation.stderr);

  const document = loadJson(out);
  assert.equal(document.games.length, 8);
});

test('CLI: games 내용이 같으면 파일을 덮어쓰지 않는다 (no_change)', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-nochange-'));
  const out = path.join(dir, 'schedule.json');

  const first = runCrawler(['--input', fixture('naver-schedule.sample.json'), '--out', out]);
  assert.equal(first.status, 0, first.stderr);
  const afterFirst = readFileSync(out, 'utf8');

  const second = runCrawler(['--input', fixture('naver-schedule.sample.json'), '--out', out]);
  assert.equal(second.status, 0, second.stderr);
  assert.match(second.stderr, /no_change/);
  assert.equal(readFileSync(out, 'utf8'), afterFirst, 'generatedAt 까지 그대로여야 함');
});
