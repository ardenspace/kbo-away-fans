// 규칙 테스트 공용 도구 — 문서 표본과 경로를 한 곳에 모아 둔다.
//
// 4.2(도장 쓰기)의 트랜잭션 테스트가 이 파일을 그대로 재사용한다. 표본 문서가
// 계약을 만족하는 최소 형태이므로, 새 테스트는 필요한 필드만 덮어써서 쓴다.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';

const here = dirname(fileURLToPath(import.meta.url));

/** 저장소 루트 — firestore.rules 의 원본 위치. */
export const repoRoot = join(here, '..', '..');

/** demo- 접두라 실제 Firebase 프로젝트도 로그인도 필요 없다. */
export const PROJECT_ID = 'demo-kbo-away-fans';

export const OWNER_UID = 'uid-owner';
export const OTHER_UID = 'uid-other';

/** 배지 판의 10칸 — firestore.rules 의 cellIds() 와 같은 값. */
export const CELL_IDS = [
  'jamsil_lg',
  'jamsil_doosan',
  'gocheok_kiwoom',
  'munhak_ssg',
  'suwon_kt',
  'daejeon_hanwha',
  'daegu_samsung',
  'sajik_lotte',
  'changwon_nc',
  'gwangju_kia',
];

/** lib/design/tokens.dart 의 BadgeTierTokens 임계(1/3/10)와 같은 사다리. */
export function tierFor(count) {
  if (count >= 10) return 'master';
  if (count >= 3) return 'regular';
  if (count >= 1) return 'first';
  return null;
}

export async function createTestEnv() {
  const hostPort = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8791';
  const sep = hostPort.lastIndexOf(':');
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: hostPort.slice(0, sep),
      port: Number(hostPort.slice(sep + 1)),
      rules: readFileSync(join(repoRoot, 'firestore.rules'), 'utf8'),
    },
  });
}

export const paths = {
  user: (uid) => `users/${uid}`,
  stamp: (uid, id) => `users/${uid}/stamps/${id}`,
  like: (uid, id) => `users/${uid}/likes/${id}`,
};

export const asUser = (env, uid) => env.authenticatedContext(uid).firestore();
export const asGuest = (env) => env.unauthenticatedContext().firestore();

/** 규칙을 끄고 초기 데이터를 심는다 (테스트 준비 전용). */
export function seed(env, fn) {
  return env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));
}

/** 칸별 요약의 한 칸. 도장이 없는 칸은 요약에 아예 두지 않는다. */
export function boardCell(count, lastStampedOn) {
  const cell = { count, tier: tierFor(count) };
  if (lastStampedOn !== undefined) cell.lastStampedOn = lastStampedOn;
  return cell;
}

export function userDoc(overrides = {}) {
  return {
    nickname: '원정러',
    favoriteTeamId: 'nc',
    profileThemeKey: 'nc',
    joinedAt: new Date('2026-09-01T00:00:00Z'),
    board: {},
    ...overrides,
  };
}

export function stampDoc(overrides = {}) {
  return {
    stadiumId: 'jamsil',
    gameId: '20260901LGOB02026',
    homeTeamId: 'lg',
    gameDate: '2026-09-01',
    stampedAt: new Date('2026-09-01T10:30:00Z'),
    ...overrides,
  };
}

/** 도장 문서 id 의 유일한 형태 — `{stadiumId}_{gameId}`. */
export function stampIdOf(stamp) {
  return `${stamp.stadiumId}_${stamp.gameId}`;
}

/** 도장이 채우는 칸 id — `{stadiumId}_{homeTeamId}`. */
export function cellIdOf(stamp) {
  return `${stamp.stadiumId}_${stamp.homeTeamId}`;
}

export function likeDoc(overrides = {}) {
  return {
    placeId: 'jamsil-gopchang',
    stadiumId: 'jamsil',
    category: 'food',
    likedAt: new Date('2026-09-01T09:00:00Z'),
    ...overrides,
  };
}
