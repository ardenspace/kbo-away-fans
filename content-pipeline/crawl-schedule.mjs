#!/usr/bin/env node
// KBO 일정 크롤러 — 네이버 스포츠 일정 API(api-gw.sports.naver.com)에서
// KBO 경기 일정·상태를 긁어 계약(schema/schedule.schema.json)을 따르는
// data/schedule.json 을 산출한다.
//
// 소스 선택 근거는 .wellbegun/decisions.md 참조:
//   KBO 공식(koreabaseball.com)은 robots.txt 가 자동 수집을 전면 금지,
//   다음 스포츠 API 경로(/prx/)도 robots Disallow — 네이버 스포츠 API 는
//   robots 제약이 없고(robots.txt 404) 구조화 JSON 이라 파싱이 안정적이다.
//
// 계약(실패 시 기존 산출물 보호):
//   1) 파싱 결과를 임시 파일(schedule.next.json)에 쓰고
//   2) common/validate.mjs 검증을 통과한 경우에만 기존 파일을 교체(rename)한다.
//   3) fetch/파싱/검증 어느 단계든 실패하면 exit 1 — 기존 schedule.json 무변경.
//   4) 계약 버전(schemaVersion)과 games 내용이 둘 다 기존 산출물과 같으면 파일을
//      건드리지 않는다 (exit 0, generatedAt 만 바뀌는 커밋 노이즈 방지).
//      경기 내용이 그대로인 채 계약 버전만 올라간 변경은 통과시켜야 한다 —
//      산출물이 옛 버전에 머물면 앱이 그 문서를 통째로 거부한다.
//
// 사용법:
//   node content-pipeline/crawl-schedule.mjs                  # 실 크롤 → data/schedule.json
//   node content-pipeline/crawl-schedule.mjs --days 14        # 미래 창 조정 (기본 30일)
//   node content-pipeline/crawl-schedule.mjs --past-days 21   # 과거 창 조정 (기본 14일)
//   node content-pipeline/crawl-schedule.mjs --input f.json   # 저장된 응답 픽스처로 산출 (테스트)
//   node content-pipeline/crawl-schedule.mjs --out p.json     # 산출 경로 변경 (테스트)

import { existsSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import { fetchWithRetry } from './common/fetch.mjs';
import { createLogger } from './common/log.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_OUT = path.join(here, 'data', 'schedule.json');
const VALIDATOR = path.join(here, 'common', 'validate.mjs');

export const API_BASE = 'https://api-gw.sports.naver.com/schedule/games';

/** 미래 창: KST 오늘 포함 앞으로 몇 일치를 긁을지. */
export const DEFAULT_WINDOW_DAYS = 30;

/**
 * 과거 창: KST 오늘 이전 몇 일치를 함께 긁을지.
 *
 * 14일인 근거 — 이 창을 소비하는 화면은 "홈의 최근 5경기 결과 요약"이다.
 * KBO 는 월요일이 휴식일이라 한 팀이 한 주에 최대 6경기를 치르므로 2주면
 * 최대 12경기, 우천 취소가 몇 번 겹치거나 올스타 휴식기(4~5일)를 물고 있어도
 * 5경기가 남는다. 더 넓히면 산출물만 커진다 — 앱은 문서를 통째로 내려받으므로
 * 과거 하루가 곧 경기 5건(약 1.5KB)의 상시 전송 비용이다.
 */
export const DEFAULT_PAST_DAYS = 14;

const DAY_MS = 24 * 60 * 60 * 1000;

/** 네이버 팀 코드 → 계약 팀 id (common.defs.schema.json 의 10종). */
export const TEAM_CODE_TO_ID = Object.freeze({
  LG: 'lg',
  OB: 'doosan',
  WO: 'kiwoom',
  SK: 'ssg',
  KT: 'kt',
  HT: 'kia',
  SS: 'samsung',
  LT: 'lotte',
  NC: 'nc',
  HH: 'hanwha',
});

/** 네이버 구장 표기(짧은 이름) → 계약 구장 id (1군 정규 홈구장 9곳). */
export const STADIUM_NAME_TO_ID = Object.freeze({
  잠실: 'jamsil',
  고척: 'gocheok',
  문학: 'munhak',
  수원: 'suwon',
  대전: 'daejeon',
  대구: 'daegu',
  사직: 'sajik',
  창원: 'changwon',
  광주: 'gwangju',
});

/** 응답 구조가 계약을 만들 수 없을 때 던지는 오류 — 산출물을 덮어쓰면 안 된다. */
export class ScheduleParseError extends Error {
  constructor(message) {
    super(message);
    this.name = 'ScheduleParseError';
  }
}

/** KST(UTC+9, DST 없음) 기준 달력 날짜를 YYYY-MM-DD 로. */
export function kstDateString(date) {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  return kst.toISOString().slice(0, 10);
}

/**
 * 크롤 창: KST 로 [오늘 - pastDays, 오늘 + days-1].
 *
 * 과거 구간이 최근 경기 결과의 원천이고, 미래 구간이 오늘 취소 감지·D-day 계산의
 * 원천이다. 둘을 한 요청으로 함께 긁는다 — API 가 fromDate/toDate 구간 조회라
 * 요청이 늘지 않고, 과거 경기 데이터는 확정된 뒤 안 바뀌어 games 비교의
 * no_change 판정이 고빈도 cron 의 커밋 노이즈를 종전대로 막는다.
 */
export function crawlWindow(now, { days = DEFAULT_WINDOW_DAYS, pastDays = DEFAULT_PAST_DAYS } = {}) {
  const fromDate = kstDateString(new Date(now.getTime() - pastDays * DAY_MS));
  const toDate = kstDateString(new Date(now.getTime() + (days - 1) * DAY_MS));
  return { fromDate, toDate };
}

export function apiUrl({ fromDate, toDate }) {
  const url = new URL(API_BASE);
  url.searchParams.set('fields', 'basic,stadium');
  url.searchParams.set('upperCategoryId', 'kbaseball');
  url.searchParams.set('categoryId', 'kbo');
  url.searchParams.set('fromDate', fromDate);
  url.searchParams.set('toDate', toDate);
  url.searchParams.set('size', '500');
  return url;
}

/**
 * 네이버 경기 상태 → 계약 status enum (schemaVersion 2 의 4분류).
 * 취소(cancel=true)면 상태 문구에 '우천'이 있을 때만 rain_canceled, 그 외 canceled.
 * 끝난 경기(statusCode=RESULT, 서스펜디드 아님)는 finished — 점수·승패가 붙는다.
 * 나머지(경기전·진행 중·서스펜디드)는 scheduled.
 */
export function mapStatus(raw) {
  if (raw.cancel === true) {
    const info = String(raw.statusInfo ?? '');
    return info.includes('우천') ? 'rain_canceled' : 'canceled';
  }
  if (raw.statusCode === 'RESULT' && raw.suspended !== true) return 'finished';
  return 'scheduled';
}

/**
 * 종료 경기의 점수·승패 필드 — 점수가 정수가 아니면 **null**.
 * 계약상 finished 가 아닌 경기에는 붙이지 않는다.
 *
 * result 는 네이버의 winner 를 그대로 받지 않고 점수에서 계산한다 — validate 의
 * 의미 검사가 "result 와 점수의 일치"를 강제하므로, 점수에서 파생해야 산출물이
 * 항상 그 게이트를 통과한다(원천 두 필드가 어긋나도 계약은 깨지지 않는다).
 *
 * null 을 던지지 않고 반환하는 이유는 호출부([buildScheduleDocument])에 적었다.
 */
export function scoreFields(raw) {
  const homeScore = raw.homeTeamScore;
  const awayScore = raw.awayTeamScore;
  if (!Number.isInteger(homeScore) || !Number.isInteger(awayScore)) return null;
  const result =
    homeScore > awayScore ? 'home_win' : homeScore < awayScore ? 'away_win' : 'draw';
  return { homeScore, awayScore, result };
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^([01]\d|2[0-3]):[0-5]\d$/;

/**
 * 네이버 응답 payload → 계약 문서 { schemaVersion, generatedAt, games }.
 *
 * - 응답 구조가 아니면 ScheduleParseError (기존 산출물을 지키기 위해 실패 전파).
 * - 로스터 밖 팀 코드/구장 표기(제2구장 포항·울산 등)는 warn 로그 후 제외.
 * - 이전 산출물에서 rain_canceled 였던 경기는 새 라벨이 우천 구분 없는 취소로
 *   와도 canceled 로 강등하지 않는다 (네이버가 과거 취소를 '경기취소'로 정규화함).
 * - 끝난 경기(finished)에는 점수·승패(homeScore/awayScore/result)를 붙인다.
 *   점수가 없는 종료 경기는 warn 로그 후 **그 경기만** 제외한다 (로스터 밖 팀·구장과
 *   같은 처리). 크롤 창이 과거로 넓어진 뒤로 이 관문을 지나는 경기가 수백 건이라
 *   예외를 던지면 한 건이 문서 전체의 산출을 막고, 20분 간격 cron 이 매번 exit 1 이
 *   되어 schedule.json 이 영구히 갱신을 멈춘다. 한 경기의 결측이 전체 정지보다 싸다.
 * - 지난 날짜인데 scheduled 로 남은 경기가 있으면 warn 로그를 남긴다 — 종료 판정이
 *   statusCode === 'RESULT' 단일 문자열에 걸려 있어, 네이버가 그 값을 바꾸면
 *   종료 경기가 전부 scheduled 로 산출되고 스키마·의미 검사·테스트가 모두 통과한다.
 *   과거 구간을 긁기 시작한 지금은 "지난 경기인데 아직 예정"이 관찰 가능한 신호다.
 * - 산출 게임 id 중복은 오류 — 앱 파서가 중복 id 문서를 거부한다.
 *
 * @param {unknown} payload  네이버 API 응답(JSON.parse 결과)
 * @param {object} [options]
 * @param {() => Date} [options.now]  generatedAt 시계 주입점 (테스트용)
 * @param {Array<{id: string, status: string}>} [options.previousGames]  기존 산출물의 games
 * @param {{ warn: Function }} [options.logger]
 */
export function buildScheduleDocument(payload, options = {}) {
  const { now = () => new Date(), previousGames = [], logger } = options;

  const rawGames = payload?.result?.games;
  if (!Array.isArray(rawGames)) {
    throw new ScheduleParseError(
      '응답에 result.games 배열이 없음 — API 구조가 바뀌었거나 오류 응답',
    );
  }

  const previousRainCanceled = new Set(
    previousGames.filter((g) => g.status === 'rain_canceled').map((g) => g.id),
  );

  const games = [];
  for (const raw of rawGames) {
    const id = typeof raw?.gameId === 'string' ? raw.gameId : '';
    if (id === '') {
      throw new ScheduleParseError(`gameId 없는 항목: ${JSON.stringify(raw).slice(0, 200)}`);
    }

    const homeTeamId = TEAM_CODE_TO_ID[raw.homeTeamCode];
    const awayTeamId = TEAM_CODE_TO_ID[raw.awayTeamCode];
    if (homeTeamId === undefined || awayTeamId === undefined) {
      logger?.warn('game_skipped', {
        gameId: id,
        reason: 'unknown_team_code',
        homeTeamCode: raw.homeTeamCode,
        awayTeamCode: raw.awayTeamCode,
      });
      continue;
    }

    const stadiumId = STADIUM_NAME_TO_ID[raw.stadium];
    if (stadiumId === undefined) {
      // 제2구장(포항·울산·청주 등) 경기 — 콘텐츠 로스터(9곳) 밖이라 제외.
      logger?.warn('game_skipped', { gameId: id, reason: 'unknown_stadium', stadium: raw.stadium });
      continue;
    }

    const date = String(raw.gameDate ?? '');
    if (!DATE_RE.test(date)) {
      throw new ScheduleParseError(`gameDate 형식 불일치: ${id} → "${raw.gameDate}"`);
    }
    const startTime = String(raw.gameDateTime ?? '').slice(11, 16);
    if (!TIME_RE.test(startTime)) {
      throw new ScheduleParseError(`gameDateTime 형식 불일치: ${id} → "${raw.gameDateTime}"`);
    }

    let status = mapStatus(raw);
    if (status === 'canceled' && previousRainCanceled.has(id)) {
      status = 'rain_canceled';
    }

    let outcome = {};
    if (status === 'finished') {
      const scores = scoreFields(raw);
      if (scores === null) {
        // 계약이 종료 경기에 점수를 요구하므로 이 경기는 산출할 수 없다.
        // 문서 전체를 버리는 대신 이 한 건만 뺀다 (근거는 함수 주석).
        logger?.warn('game_skipped', {
          gameId: id,
          reason: 'finished_without_score',
          homeTeamScore: raw.homeTeamScore,
          awayTeamScore: raw.awayTeamScore,
        });
        continue;
      }
      outcome = scores;
    }

    games.push({
      id,
      date,
      startTime,
      homeTeamId,
      awayTeamId,
      stadiumId,
      status,
      ...outcome,
    });
  }

  games.sort(
    (a, b) =>
      a.date.localeCompare(b.date) ||
      a.startTime.localeCompare(b.startTime) ||
      a.id.localeCompare(b.id),
  );

  const ids = new Set(games.map((g) => g.id));
  if (ids.size !== games.length) {
    throw new ScheduleParseError('산출 게임 id 중복 — 앱 파서가 중복 id 문서를 거부한다');
  }

  const generatedAt = now();
  const today = kstDateString(generatedAt);
  // 종료 판정 드리프트 감지 (근거는 함수 주석). 서스펜디드 경기도 여기에 걸리므로
  // 실패로 만들지 않고 신호만 남긴다 — 판정이 통째로 깨지면 개수가 하루치를 넘는다.
  const stale = games.filter((g) => g.date < today && g.status === 'scheduled');
  if (stale.length > 0) {
    logger?.warn('stale_scheduled_games', {
      count: stale.length,
      today,
      sample: stale.slice(0, 3).map((g) => g.id),
      hint: '지난 경기가 아직 scheduled — 네이버 statusCode 가 RESULT 에서 바뀌었을 수 있음',
    });
  }

  return { schemaVersion: 2, generatedAt: generatedAt.toISOString(), games };
}

function parseArgs(argv) {
  const args = {
    input: null,
    out: DEFAULT_OUT,
    days: DEFAULT_WINDOW_DAYS,
    pastDays: DEFAULT_PAST_DAYS,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--input') args.input = argv[(i += 1)];
    else if (flag === '--out') args.out = argv[(i += 1)];
    else if (flag === '--days') args.days = Number(argv[(i += 1)]);
    else if (flag === '--past-days') args.pastDays = Number(argv[(i += 1)]);
    else throw new Error(`알 수 없는 인자: ${flag}`);
  }
  if (!Number.isInteger(args.days) || args.days < 1) {
    throw new Error(`--days 는 1 이상의 정수여야 함: ${args.days}`);
  }
  // 0 은 "과거 창 없음" — 사이클 1 의 동작으로 되돌리는 탈출구다.
  if (!Number.isInteger(args.pastDays) || args.pastDays < 0) {
    throw new Error(`--past-days 는 0 이상의 정수여야 함: ${args.pastDays}`);
  }
  return args;
}

/** 기존 산출물을 읽는다 — 없거나 깨져 있으면 null (rain_canceled 유지·no-change 비교용). */
function readExisting(outPath, log) {
  if (!existsSync(outPath)) return null;
  try {
    const doc = JSON.parse(readFileSync(outPath, 'utf8'));
    return Array.isArray(doc?.games) ? doc : null;
  } catch (err) {
    log.warn('existing_unreadable', { path: outPath, error: String(err) });
    return null;
  }
}

async function loadPayload(args, log) {
  if (args.input !== null) {
    log.info('payload_from_file', { path: args.input });
    return JSON.parse(readFileSync(args.input, 'utf8'));
  }
  const window = crawlWindow(new Date(), { days: args.days, pastDays: args.pastDays });
  const url = apiUrl(window);
  log.info('fetch_start', { url: String(url), ...window });
  const res = await fetchWithRetry(url, { logger: log });
  if (!res.ok) {
    throw new Error(`API 응답 상태 ${res.status}: ${url}`);
  }
  return JSON.parse(await res.text());
}

async function main(argv) {
  const log = createLogger('crawl-schedule');
  let args;
  try {
    args = parseArgs(argv);
  } catch (err) {
    log.error('bad_args', { error: String(err) });
    return 1;
  }

  try {
    const payload = await loadPayload(args, log);
    const existing = readExisting(args.out, log);
    const document = buildScheduleDocument(payload, {
      previousGames: existing?.games ?? [],
      logger: log,
    });

    // 변경 없음 판정에는 계약 버전도 포함한다 — games 만 보면 계약 버전만 오른
    // 변경에서 산출물이 옛 버전에 머물고 앱이 문서를 통째로 거부한다.
    const unchanged =
      existing !== null &&
      existing.schemaVersion === document.schemaVersion &&
      JSON.stringify(existing.games) === JSON.stringify(document.games);
    if (unchanged) {
      log.info('no_change', {
        games: document.games.length,
        schemaVersion: document.schemaVersion,
      });
      return 0;
    }

    // 임시 파일에 쓰고 검증 통과 시에만 교체 — 실패 시 기존 산출물 무변경.
    // (파일명은 validate 의 계약 판별 규칙 때문에 schedule 로 시작해야 한다.)
    const tempPath = path.join(path.dirname(args.out), 'schedule.next.json');
    writeFileSync(tempPath, `${JSON.stringify(document, null, 2)}\n`);
    const validation = spawnSync(process.execPath, [VALIDATOR, tempPath], { stdio: 'inherit' });
    if (validation.status !== 0) {
      rmSync(tempPath, { force: true });
      log.error('crawl_fail', { reason: 'validation_failed', exitCode: validation.status });
      return 1;
    }
    renameSync(tempPath, args.out);
    log.info('crawl_success', {
      out: args.out,
      games: document.games.length,
      finished: document.games.filter((g) => g.status === 'finished').length,
    });
    return 0;
  } catch (err) {
    log.error('crawl_fail', { reason: 'fetch_or_parse_failed', error: String(err) });
    return 1;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(await main(process.argv.slice(2)));
}
