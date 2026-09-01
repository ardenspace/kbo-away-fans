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
  requestSize,
  DEFAULT_PAST_DAYS,
  DEFAULT_WINDOW_DAYS,
  MAX_REQUEST_SIZE,
  MAX_MISSING_FINISHED_SCORES,
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

// ── 점수 결측 안전장치 1겹: 이전 산출물 유지 ────────────────────────────────
// 결측이 오늘 경기에 걸리면 그 경기가 문서에서 사라져 앱의 "오늘 원정" 판정과
// 오늘 취소 감지가 통째로 어긋난다 — 이전 값 유지가 그 경로를 막는다.

/** past-window 픽스처의 오늘(2026-09-01) 경기 하나를 "점수 없이 끝난" 상태로 만든다. */
function todayGameFinishedWithoutScore(payload, gameId = '20260901LGOB02026') {
  const game = payload.result.games.find((g) => g.gameId === gameId);
  assert.ok(game, `픽스처에 ${gameId} 가 있어야 함`);
  game.statusCode = 'RESULT';
  game.homeTeamScore = null;
  game.awayTeamScore = null;
  return gameId;
}

test('점수가 사라진 오늘 경기는 이전 산출물의 종료 값(점수·승패)으로 되살아난다', () => {
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  const id = todayGameFinishedWithoutScore(payload);

  const warns = [];
  const document = buildScheduleDocument(payload, {
    now: PAST_WINDOW_NOW,
    previousGames: [
      {
        id,
        date: '2026-09-01',
        startTime: '18:30',
        homeTeamId: 'doosan',
        awayTeamId: 'lg',
        stadiumId: 'jamsil',
        status: 'finished',
        homeScore: 6,
        awayScore: 2,
        result: 'home_win',
      },
    ],
    logger: { warn: (event, fields) => warns.push({ event, ...fields }) },
  });

  const game = document.games.find((g) => g.id === id);
  assert.ok(game, '오늘 경기가 문서에서 사라지면 안 됨 (오늘 원정 판정의 원천)');
  assert.equal(document.games.length, 12, '경기 수가 줄면 안 됨');
  assert.equal(game.status, 'finished');
  assert.equal(game.homeScore, 6);
  assert.equal(game.awayScore, 2);
  assert.equal(game.result, 'home_win');
  assert.deepEqual(
    warns.filter((w) => w.event === 'game_skipped'),
    [],
    '되살린 경기는 skip 되면 안 됨',
  );
  assert.equal(warns.filter((w) => w.event === 'finished_score_carried_over').length, 1);
});

test('이전 산출물이 그 경기를 아직 scheduled 로 갖고 있으면 그 상태로 남는다 (사라지지 않는다)', () => {
  // 20분 간격 cron 의 실제 모양 — 직전 크롤 때는 경기가 아직 안 끝나 있었다.
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  const id = todayGameFinishedWithoutScore(payload);

  const document = buildScheduleDocument(payload, {
    now: PAST_WINDOW_NOW,
    previousGames: [{ id, status: 'scheduled' }],
  });

  const game = document.games.find((g) => g.id === id);
  assert.ok(game, '오늘 경기가 문서에서 사라지면 안 됨');
  assert.equal(game.status, 'scheduled');
  assert.equal('homeScore' in game, false, '점수 없는 상태에 점수가 붙으면 안 됨');
  assert.equal(document.games.length, 12);
});

test('CLI: 점수 결측이 임계값 이하면 이전 산출물 값으로 살아나 12경기가 그대로 남는다', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-carryover-'));
  const out = path.join(dir, 'schedule.json');
  const input = path.join(dir, 'payload.json');

  // 1) 정상 크롤 — 산출물에 종료 6경기의 점수가 남는다.
  const first = runCrawler(['--input', fixture('naver-schedule.past-window.json'), '--out', out]);
  assert.equal(first.status, 0, first.stderr);
  assert.equal(loadJson(out).games.filter((g) => g.status === 'finished').length, 6);

  // 2) 개별 경기 몇 건의 점수만 결측된 상황 — 임계값 이하이므로 유지 장치가 흡수한다.
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  stripScores(payload, MAX_MISSING_FINISHED_SCORES);
  writeFileSync(input, JSON.stringify(payload));

  const second = runCrawler(['--input', input, '--out', out]);
  assert.equal(second.status, 0, second.stderr);
  assert.match(second.stderr, /finished_score_carried_over/);
  assert.doesNotMatch(second.stderr, /game_skipped/, '이전 산출물이 있으면 빠지는 경기가 없어야 함');

  const document = loadJson(out);
  assert.equal(document.games.length, 12, '반토막 산출물이 되면 안 됨');
  assert.equal(document.games.filter((g) => g.status === 'finished').length, 6);

  const validation = spawnSync(process.execPath, [validator, out], { encoding: 'utf8' });
  assert.equal(validation.status, 0, validation.stderr);
});

// ── 점수 결측 안전장치 2겹: 임계값 초과는 실패 ─────────────────────────────

/** 픽스처의 종료 경기 앞 `count` 건의 점수를 지운다. 지운 gameId 목록을 준다. */
function stripScores(payload, count) {
  const finished = payload.result.games.filter((g) => g.statusCode === 'RESULT');
  assert.ok(finished.length >= count, '픽스처에 종료 경기가 충분해야 함');
  return finished.slice(0, count).map((g) => {
    g.homeTeamScore = null;
    g.awayTeamScore = null;
    return g.gameId;
  });
}

test('이전 산출물로도 못 살릴 점수 결측이 임계값 이하면 그 경기만 빠지고 문서는 산출된다', () => {
  // "한 건의 결측이 문서 전체의 산출을 막는" 원래 문제를 임계값이 되돌리지 않는지.
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  const stripped = stripScores(payload, MAX_MISSING_FINISHED_SCORES);

  const document = buildScheduleDocument(payload, { now: PAST_WINDOW_NOW });
  assert.equal(document.games.length, 12 - MAX_MISSING_FINISHED_SCORES);
  for (const id of stripped) {
    assert.equal(
      document.games.some((g) => g.id === id),
      false,
      id,
    );
  }
});

test('점수 결측이 임계값을 넘으면 ScheduleParseError (이전 산출물이 없어 살릴 수도 없는 경우)', () => {
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  stripScores(payload, MAX_MISSING_FINISHED_SCORES + 1);

  assert.throws(
    () => buildScheduleDocument(payload, { now: PAST_WINDOW_NOW }),
    (err) => err instanceof ScheduleParseError && /임계값/.test(err.message),
  );
});

test('이전 산출물이 scheduled 로 유지해 주더라도 종료 경기 전원의 점수 결측은 임계값을 넘는다', () => {
  // 20분 간격 cron 에서 경기 종료 직전의 이전 산출물 상태는 언제나 scheduled 다.
  // 임계값이 "1겹이 못 살린 건수"만 세면 이 경로에서 카운트가 0 이 되어, 원천이
  // 점수 필드를 잃었을 때 종료 경기 전원이 점수 없는 scheduled 로 강등된 문서가
  // crawl_success 로 배포된다 — 임계값은 유지 여부와 무관하게 세야 한다.
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  const stripped = stripScores(payload, MAX_MISSING_FINISHED_SCORES + 1);
  const previousGames = stripped.map((id) => ({ id, status: 'scheduled' }));

  assert.throws(
    () => buildScheduleDocument(payload, { now: PAST_WINDOW_NOW, previousGames }),
    (err) => err instanceof ScheduleParseError && /임계값/.test(err.message),
  );
});

test('CLI: 이전 산출물이 scheduled 로 갖고 있어도 대량 점수 결측은 exit 1 (산출물 무변경)', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-missing-carried-'));
  const out = path.join(dir, 'schedule.json');
  const input = path.join(dir, 'payload.json');

  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  const stripped = stripScores(payload, MAX_MISSING_FINISHED_SCORES + 1);
  writeFileSync(input, JSON.stringify(payload));

  // 직전 크롤(20분 전) 때는 이 경기들이 아직 안 끝나 있었다 — 유지 장치가 전부 흡수한다.
  const original = `${JSON.stringify(
    {
      schemaVersion: 2,
      generatedAt: '2026-09-01T04:40:00Z',
      games: stripped.map((id) => ({ id, status: 'scheduled' })),
    },
    null,
    2,
  )}\n`;
  writeFileSync(out, original);

  const result = runCrawler(['--input', input, '--out', out]);
  assert.notEqual(result.status, 0, result.stderr);
  assert.match(result.stderr, /crawl_fail/);
  assert.equal(readFileSync(out, 'utf8'), original, '실패 시 기존 산출물을 덮어쓰면 안 됨');
  assert.ok(!existsSync(path.join(dir, 'schedule.next.json')), '임시 파일이 남으면 안 됨');
});

test('CLI: 대량 점수 결측은 exit 1 이고 기존 산출물은 그대로 남는다', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-missing-'));
  const out = path.join(dir, 'schedule.json');
  const input = path.join(dir, 'payload.json');

  // 이전 산출물에 그 경기들이 없어야 1겹이 흡수하지 못한다 (원천 개명 + 첫 산출 상황).
  const original = '{"schemaVersion":2,"generatedAt":"2026-09-01T04:00:00Z","games":[]}\n';
  writeFileSync(out, original);

  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  stripScores(payload, MAX_MISSING_FINISHED_SCORES + 1);
  writeFileSync(input, JSON.stringify(payload));

  const result = runCrawler(['--input', input, '--out', out]);
  assert.notEqual(result.status, 0, result.stderr);
  assert.match(result.stderr, /crawl_fail/);
  assert.equal(readFileSync(out, 'utf8'), original, '실패 시 기존 산출물을 덮어쓰면 안 됨');
  assert.ok(!existsSync(path.join(dir, 'schedule.next.json')), '임시 파일이 남으면 안 됨');
});

// ── 응답 잘림 ───────────────────────────────────────────────────────────────

test('요청 size 는 창 길이에 비례하고 원천이 무시하는 상한을 넘지 않는다', () => {
  // 기본 창(과거 14 + 미래 30 = 44일, 최대 약 220경기)
  const base = crawlWindow(new Date('2026-09-01T05:00:00Z'));
  assert.equal(requestSize(base), 440);
  assert.equal(apiUrl(base).searchParams.get('size'), '440');

  // 넓힌 창 — 옛 고정값 500 이면 여기서부터 뒤쪽이 조용히 잘렸다.
  const wide = crawlWindow(new Date('2026-09-01T05:00:00Z'), { pastDays: 90 });
  assert.ok(requestSize(wide) > 500, '창을 넓히면 요청 size 도 커져야 함');
  assert.equal(requestSize(wide), MAX_REQUEST_SIZE);

  // 상한 — 네이버는 이 값을 넘는 size 를 받으면 페이지 크기를 10 으로 떨어뜨린다.
  const huge = crawlWindow(new Date('2026-09-01T05:00:00Z'), { pastDays: 700, days: 700 });
  assert.equal(requestSize(huge), MAX_REQUEST_SIZE);
});

test('응답이 잘리면(총건수 > 수신 건수) ScheduleParseError — 조용히 넘어가지 않는다', () => {
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  payload.result.gameTotalCount = payload.result.games.length + 1;

  assert.throws(
    () => buildScheduleDocument(payload, { now: PAST_WINDOW_NOW }),
    (err) => err instanceof ScheduleParseError && /잘림/.test(err.message),
  );
});

test('총건수 필드가 없으면 대조 불가를 warn 으로 알린다 (원천 필드명 변경 감지)', () => {
  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  delete payload.result.gameTotalCount;

  const warns = [];
  buildScheduleDocument(payload, {
    now: PAST_WINDOW_NOW,
    logger: { warn: (event, fields) => warns.push({ event, ...fields }) },
  });
  assert.equal(warns.filter((w) => w.event === 'total_count_missing').length, 1);
});

test('CLI: 잘린 응답은 exit 1 이고 기존 산출물은 그대로 남는다', () => {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'crawl-truncated-'));
  const out = path.join(dir, 'schedule.json');
  const input = path.join(dir, 'payload.json');
  const original = '{"schemaVersion":2,"generatedAt":"2026-09-01T04:00:00Z","games":[]}\n';
  writeFileSync(out, original);

  const payload = loadJson(fixture('naver-schedule.past-window.json'));
  payload.result.gameTotalCount = 200; // size 를 넘겨 뒤쪽이 잘린 응답
  writeFileSync(input, JSON.stringify(payload));

  const result = runCrawler(['--input', input, '--out', out]);
  assert.notEqual(result.status, 0, result.stderr);
  assert.match(result.stderr, /crawl_fail/);
  assert.equal(readFileSync(out, 'utf8'), original);
});
