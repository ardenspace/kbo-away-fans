// crawl-schedule.mjs 단위 테스트 — 전부 저장된 픽스처(test/fixtures/crawl/) 기반.
// 실제 네트워크에 의존하지 않는다. boundary test 대응:
//   1) 저장된 응답 픽스처 → 파싱 결과 스냅샷 일치
//   2) 취소 표기 픽스처 → rain_canceled 매핑
//   3) 깨진 픽스처 → CLI exit 비0 + 산출물 미변경
//   4) 산출물이 validate 를 통과 (exit 0)
//   5) 과거 구간이 든 픽스처 → 종료 경기의 점수·승패 산출 + 크롤 창의 과거 확장
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
  apiUrl,
  DEFAULT_PAST_DAYS,
  DEFAULT_WINDOW_DAYS,
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
  // 종료 판정은 statusCode 만 본다 — 실제 응답의 statusInfo 는 끝난 경기에도
  // '종료'가 아니라 마지막 이닝('9회말' 등)이 담긴다.
  assert.equal(
    mapStatus({ cancel: false, statusCode: 'RESULT', statusInfo: '9회말' }),
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

test('끝난 경기인데 점수가 없으면 그 경기만 warn 로그와 함께 빠진다 (문서 전체는 산출된다)', () => {
  // 창이 과거로 넓어진 뒤로 이 관문을 지나는 경기가 수백 건이라, 한 건의 결측이
  // 문서 전체의 산출을 막으면 고빈도 cron 이 매번 실패해 산출물이 영구히 멈춘다.
  const payload = loadJson(fixture('naver-schedule.finished.json'));
  delete payload.result.games[0].homeTeamScore;
  const dropped = payload.result.games[0].gameId;

  const warns = [];
  const document = buildScheduleDocument(payload, {
    now: FIXED_NOW,
    logger: { warn: (event, fields) => warns.push({ event, ...fields }) },
  });

  assert.equal(
    document.games.some((g) => g.id === dropped),
    false,
    '점수 없는 종료 경기는 산출물에 남으면 안 됨 (계약이 점수를 요구)',
  );
  assert.ok(document.games.length > 0, '나머지 경기는 그대로 산출되어야 함');
  assert.deepEqual(
    warns.filter((w) => w.event === 'game_skipped'),
    [
      {
        event: 'game_skipped',
        gameId: dropped,
        reason: 'finished_without_score',
        homeTeamScore: undefined,
        awayTeamScore: 3,
      },
    ],
  );
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
  assert.deepEqual(
    warns.filter((w) => w.event === 'game_skipped'),
    [
      {
        event: 'game_skipped',
        gameId: '20260822KTSK02026',
        reason: 'unknown_stadium',
        stadium: '울산',
      },
    ],
  );
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
  const window = crawlWindow(new Date('2026-08-25T23:30:00Z'), { days: 3, pastDays: 0 });
  assert.deepEqual(window, { fromDate: '2026-08-26', toDate: '2026-08-28' });
});

test('크롤 창은 과거 구간을 포함한다 — fromDate 가 오늘(KST)보다 pastDays 만큼 앞선다', () => {
  const window = crawlWindow(new Date('2026-08-25T23:30:00Z'), { days: 3, pastDays: 5 });
  assert.deepEqual(window, { fromDate: '2026-08-21', toDate: '2026-08-28' });
});

test('크롤 창 기본값은 과거 14일 + 오늘 포함 미래 30일', () => {
  assert.equal(DEFAULT_PAST_DAYS, 14);
  assert.equal(DEFAULT_WINDOW_DAYS, 30);
  // 기본 인자 그대로 — 과거 구간이 실제로 요청 범위에 들어가는지 단언한다.
  const window = crawlWindow(new Date('2026-09-01T05:00:00Z'));
  assert.deepEqual(window, { fromDate: '2026-08-18', toDate: '2026-09-30' });
});

test('과거 창은 API 요청 URL 의 fromDate 로 실제로 전달된다', () => {
  const url = apiUrl(crawlWindow(new Date('2026-09-01T05:00:00Z')));
  assert.equal(url.searchParams.get('fromDate'), '2026-08-18');
  assert.equal(url.searchParams.get('toDate'), '2026-09-30');
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

test('CLI: games 가 같아도 schemaVersion 이 다르면 산출물을 갱신한다', () => {
  // 경기 내용은 그대로인 채 계약 버전만 오르는 변경 — games 만 비교하면 산출물이
  // 옛 버전에 머물고 앱이 그 문서를 통째로 거부한다.
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-version-'));
  const out = path.join(dir, 'schedule.json');

  const first = runCrawler(['--input', fixture('naver-schedule.sample.json'), '--out', out]);
  assert.equal(first.status, 0, first.stderr);

  const stale = { ...loadJson(out), schemaVersion: 1 };
  writeFileSync(out, `${JSON.stringify(stale, null, 2)}\n`);

  const second = runCrawler(['--input', fixture('naver-schedule.sample.json'), '--out', out]);
  assert.equal(second.status, 0, second.stderr);
  assert.doesNotMatch(second.stderr, /no_change/, 'schemaVersion 차이는 변경으로 봐야 함');
  assert.match(second.stderr, /crawl_success/);
  assert.equal(loadJson(out).schemaVersion, 2);
});

// ── 과거 구간 픽스처 (step 1.2) ─────────────────────────────────────────────
// naver-schedule.past-window.json 은 실제 네이버 응답(2026-08-18~09-01 구간)에서
// 뽑은 12경기다. 기준 시각 2026-09-01 14:00 KST 로 보면 08-21~08-30 이 과거,
// 09-01 이 오늘이다 — 크롤 창이 과거로 넓어졌을 때 실제로 들어오는 모양.
const PAST_WINDOW_NOW = () => new Date('2026-09-01T05:00:00Z');

test('과거 구간 픽스처: 종료 경기는 점수·승패를 담고 미래 경기는 종전대로 점수 없는 예정이다', () => {
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  const document = buildScheduleDocument(payload, { now: PAST_WINDOW_NOW });
  const byId = Object.fromEntries(document.games.map((g) => [g.id, g]));

  assert.equal(document.schemaVersion, 2);
  assert.equal(document.games.length, 12);

  // 지난 종료 경기 — 승패 세 갈래가 점수에서 파생되어 붙는다.
  assert.deepEqual(byId['20260821KTSK02026'], {
    id: '20260821KTSK02026',
    date: '2026-08-21',
    startTime: '19:00',
    homeTeamId: 'ssg',
    awayTeamId: 'kt',
    stadiumId: 'munhak',
    status: 'finished',
    homeScore: 3,
    awayScore: 3,
    result: 'draw',
  });
  assert.deepEqual(byId['20260821LTOB02026'], {
    id: '20260821LTOB02026',
    date: '2026-08-21',
    startTime: '19:00',
    homeTeamId: 'doosan',
    awayTeamId: 'lotte',
    stadiumId: 'jamsil',
    status: 'finished',
    homeScore: 4,
    awayScore: 11,
    result: 'away_win',
  });
  assert.deepEqual(byId['20260822HTWO02026'], {
    id: '20260822HTWO02026',
    date: '2026-08-22',
    startTime: '18:00',
    homeTeamId: 'kiwoom',
    awayTeamId: 'kia',
    stadiumId: 'gocheok',
    status: 'finished',
    homeScore: 3,
    awayScore: 1,
    result: 'home_win',
  });

  // 지난 취소 경기 — 점수 필드가 붙지 않는다 (원천에 0-0 이 들어 있어도).
  for (const id of ['20260822KTSK02026', '20260828WOOB02026', '20260830LGLT02026']) {
    assert.equal(byId[id].status, 'canceled', id);
    assert.equal('homeScore' in byId[id], false, id);
    assert.equal('awayScore' in byId[id], false, id);
    assert.equal('result' in byId[id], false, id);
  }

  // 오늘·미래 경기 — 종전대로 점수 없는 예정 상태.
  for (const id of ['20260901HHKT02026', '20260901LGOB02026', '20260901SKWO02026']) {
    assert.equal(byId[id].status, 'scheduled', id);
    assert.deepEqual(Object.keys(byId[id]).filter((k) => k.endsWith('Score')), [], id);
    assert.equal('result' in byId[id], false, id);
  }

  // 날짜 → 시작 시각 정렬은 과거 경기가 섞여도 그대로다.
  const dates = document.games.map((g) => g.date);
  assert.deepEqual(dates, [...dates].sort());
  assert.equal(dates[0], '2026-08-21');
  assert.equal(dates.at(-1), '2026-09-01');

  // 산출물이 실제로 최근 결과를 담는지 — 종료 6건.
  assert.equal(document.games.filter((g) => g.status === 'finished').length, 6);
});

test('과거 구간 픽스처의 산출물이 validate 를 통과한다 (exit 0) — 보호 패턴 그대로', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-past-'));
  const out = path.join(dir, 'schedule.json');

  const result = runCrawler(['--input', fixture('naver-schedule.past-window.json'), '--out', out]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /crawl_success/);

  const validation = spawnSync(process.execPath, [validator, out], { encoding: 'utf8' });
  assert.equal(validation.status, 0, validation.stderr);

  const document = loadJson(out);
  assert.equal(document.games.length, 12);
  assert.equal(document.games.filter((g) => g.status === 'finished').length, 6);
});

test('과거 구간 픽스처: 점수 없는 종료 경기가 있어도 나머지 11경기는 그대로 산출된다', () => {
  // "한 건이 전부를 막는" 구조를 없앤 자리 — CLI 가 exit 0 이고 산출물이 남아야 한다.
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-past-noscore-'));
  const input = path.join(dir, 'payload.json');
  const out = path.join(dir, 'schedule.json');

  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  const broken = payload.result.games.find((g) => g.gameId === '20260825NCLG02026');
  broken.homeTeamScore = null;
  writeFileSync(input, JSON.stringify(payload));

  const result = runCrawler(['--input', input, '--out', out]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /finished_without_score/);

  const document = loadJson(out);
  assert.equal(document.games.length, 11);
  assert.equal(
    document.games.some((g) => g.id === '20260825NCLG02026'),
    false,
  );

  const validation = spawnSync(process.execPath, [validator, out], { encoding: 'utf8' });
  assert.equal(validation.status, 0, validation.stderr);
});

test('지난 경기가 scheduled 로 남아 있으면 종료 판정 드리프트를 warn 으로 알린다', () => {
  // 종료 판정은 statusCode === 'RESULT' 단일 문자열에 걸려 있어, 네이버가 그 값을
  // 바꾸면 스키마·의미 검사·테스트가 전부 통과한 채 조용히 실패한다.
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  for (const g of payload.result.games) {
    if (g.statusCode === 'RESULT') g.statusCode = 'ENDED';
  }

  const warns = [];
  const document = buildScheduleDocument(payload, {
    now: PAST_WINDOW_NOW,
    logger: { warn: (event, fields) => warns.push({ event, ...fields }) },
  });

  assert.equal(document.games.filter((g) => g.status === 'finished').length, 0);
  const stale = warns.filter((w) => w.event === 'stale_scheduled_games');
  assert.equal(stale.length, 1);
  assert.equal(stale[0].count, 6);
  assert.equal(stale[0].today, '2026-09-01');
});

test('정상 응답에는 드리프트 warn 이 붙지 않는다', () => {
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  const warns = [];
  buildScheduleDocument(payload, {
    now: PAST_WINDOW_NOW,
    logger: { warn: (event, fields) => warns.push({ event, ...fields }) },
  });
  assert.deepEqual(warns, []);
});
