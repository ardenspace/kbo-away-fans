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
//   4) games 내용이 기존 산출물과 같으면 파일을 건드리지 않는다 (exit 0,
//      generatedAt 만 바뀌는 커밋 노이즈 방지).
//
// 사용법:
//   node content-pipeline/crawl-schedule.mjs                # 실 크롤 → data/schedule.json
//   node content-pipeline/crawl-schedule.mjs --days 14      # 크롤 창 조정 (기본 30일)
//   node content-pipeline/crawl-schedule.mjs --input f.json # 저장된 응답 픽스처로 산출 (테스트)
//   node content-pipeline/crawl-schedule.mjs --out p.json   # 산출 경로 변경 (테스트)

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
export const DEFAULT_WINDOW_DAYS = 30;

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

/** 크롤 창: KST 오늘부터 days-1 일 뒤까지 (경기일 취소 감지 + D-day 계산에 충분). */
export function crawlWindow(now, days = DEFAULT_WINDOW_DAYS) {
  const fromDate = kstDateString(now);
  const toDate = kstDateString(new Date(now.getTime() + (days - 1) * 24 * 60 * 60 * 1000));
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
 * 네이버 경기 상태 → 계약 status enum.
 * 취소(cancel=true)면 상태 문구에 '우천'이 있을 때만 rain_canceled, 그 외 canceled.
 * 취소가 아니면(경기전·진행·종료·서스펜디드) 전부 scheduled — 계약의 3분류가 그렇다.
 */
export function mapStatus(raw) {
  if (raw.cancel === true) {
    const info = String(raw.statusInfo ?? '');
    return info.includes('우천') ? 'rain_canceled' : 'canceled';
  }
  return 'scheduled';
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

    games.push({ id, date, startTime, homeTeamId, awayTeamId, stadiumId, status });
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

  return { schemaVersion: 1, generatedAt: now().toISOString(), games };
}

function parseArgs(argv) {
  const args = { input: null, out: DEFAULT_OUT, days: DEFAULT_WINDOW_DAYS };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--input') args.input = argv[(i += 1)];
    else if (flag === '--out') args.out = argv[(i += 1)];
    else if (flag === '--days') args.days = Number(argv[(i += 1)]);
    else throw new Error(`알 수 없는 인자: ${flag}`);
  }
  if (!Number.isInteger(args.days) || args.days < 1) {
    throw new Error(`--days 는 1 이상의 정수여야 함: ${args.days}`);
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
  const window = crawlWindow(new Date(), args.days);
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

    if (existing !== null && JSON.stringify(existing.games) === JSON.stringify(document.games)) {
      log.info('no_change', { games: document.games.length });
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
    log.info('crawl_success', { out: args.out, games: document.games.length });
    return 0;
  } catch (err) {
    log.error('crawl_fail', { reason: 'fetch_or_parse_failed', error: String(err) });
    return 1;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(await main(process.argv.slice(2)));
}
