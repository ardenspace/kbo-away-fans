// 검증자 탐침 (커밋 3bf8626) — "이전 산출물 값 유지"(안전장치 1겹)가 낡은 값을
// 고착시키지 않는지.
//
// 유지 경로는 점수 결측일 때만 도는 것이 계약인데, 분기가 뒤집히거나 previous 를
// 먼저 보도록 바뀌면 원천이 점수를 되찾은 뒤에도 이전 산출물의 옛 점수가 계속
// 산출된다 — validate 도 스키마도 통과하는 조용한 오답이라(점수와 result 가
// 서로 일관되므로) 다른 게이트가 잡지 못한다. 기존 테스트는 "결측일 때 되살아난다"
// 방향만 단언하므로 반대 방향을 여기서 못 박는다.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { buildScheduleDocument } from '../crawl-schedule.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const FIXTURE = path.join(here, 'fixtures', 'crawl', 'naver-schedule.past-window.json');
const NOW = () => new Date('2026-09-01T05:00:00Z');

const loadPayload = () => JSON.parse(readFileSync(FIXTURE, 'utf8'));

test('원천이 점수를 갖고 있으면 이전 산출물의 옛 점수를 덮어쓴다 (유지가 값을 고착시키지 않는다)', () => {
  const payload = loadPayload();
  const raw = payload.result.games.find((g) => g.statusCode === 'RESULT');
  raw.homeTeamScore = 7;
  raw.awayTeamScore = 2;

  // 이전 산출물에는 다른 점수(그리고 반대 승패)가 들어 있다.
  const previousGames = [
    {
      id: raw.gameId,
      date: raw.gameDate,
      status: 'finished',
      homeScore: 1,
      awayScore: 4,
      result: 'away_win',
    },
  ];

  const document = buildScheduleDocument(payload, { now: NOW, previousGames });
  const game = document.games.find((g) => g.id === raw.gameId);

  assert.equal(game.status, 'finished');
  assert.deepEqual(
    [game.homeScore, game.awayScore, game.result],
    [7, 2, 'home_win'],
    '원천 점수가 이전 산출물 값을 이겨야 한다',
  );
});

test('결측이 해소되면 직전 크롤에서 유지된 값이 새 값으로 교체된다', () => {
  const raw0 = loadPayload().result.games.find((g) => g.statusCode === 'RESULT');

  // 1회차: 원천에 점수가 없어 이전 산출물 값(5-3)으로 유지된다.
  const missing = loadPayload();
  const rawMissing = missing.result.games.find((g) => g.gameId === raw0.gameId);
  rawMissing.homeTeamScore = null;
  rawMissing.awayTeamScore = null;
  const first = buildScheduleDocument(missing, {
    now: NOW,
    previousGames: [
      {
        id: raw0.gameId,
        date: raw0.gameDate,
        status: 'finished',
        homeScore: 5,
        awayScore: 3,
        result: 'home_win',
      },
    ],
  });
  const carried = first.games.find((g) => g.id === raw0.gameId);
  assert.deepEqual([carried.homeScore, carried.awayScore], [5, 3], '1회차는 유지되어야 한다');

  // 2회차: 원천이 점수를 되찾으면 유지된 값이 남으면 안 된다.
  const recovered = loadPayload();
  const rawRecovered = recovered.result.games.find((g) => g.gameId === raw0.gameId);
  rawRecovered.homeTeamScore = 2;
  rawRecovered.awayTeamScore = 8;
  const second = buildScheduleDocument(recovered, { now: NOW, previousGames: first.games });
  const fresh = second.games.find((g) => g.id === raw0.gameId);

  assert.deepEqual([fresh.homeScore, fresh.awayScore, fresh.result], [2, 8, 'away_win']);
});
