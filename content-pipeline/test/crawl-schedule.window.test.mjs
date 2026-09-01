// 검증자 탐침 (커밋 5f6cfec) — 크롤 창이 "실행 시각의 UTC 시분"에 흔들리지
// 않는지. cron 이 06:30 KST 와 14:00–23:40 KST 20분 간격으로 도는데, 그중
// 23:40 KST 는 UTC 로 전날이다. 창 계산이 KST 달력 날짜에만 걸려 있지 않으면
// 하루 안에서도 fromDate/toDate 가 흔들려 과거 구간이 들쭉날쭉해진다.
//
// 기존 crawl-schedule.test.mjs 는 고정 시각 2건만 본다 — 여기서는 하루 24시각
// 전부에서 창이 [KST오늘-pastDays, KST오늘+days-1] 임을 독립 계산으로 대조한다.
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  crawlWindow,
  kstDateString,
  DEFAULT_PAST_DAYS,
  DEFAULT_WINDOW_DAYS,
} from '../crawl-schedule.mjs';

/** YYYY-MM-DD 에 달력 일수를 더한다 (창 계산과 독립인 경로). */
function shiftDate(dateString, days) {
  const d = new Date(`${dateString}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

test('크롤 창은 하루 24시각 어디서 돌려도 KST 달력 날짜에만 걸린다', () => {
  // 월말·월초를 함께 지나도록 두 날을 본다 (달 넘김에서 자릿수 계산이 깨지는 경우).
  for (const [y, m, day] of [
    [2026, 8, 31],
    [2026, 9, 1],
  ]) {
    for (let hour = 0; hour < 24; hour += 1) {
      const now = new Date(Date.UTC(y, m - 1, day, hour, 37, 12));
      const today = kstDateString(now);
      assert.deepEqual(
        crawlWindow(now),
        {
          fromDate: shiftDate(today, -DEFAULT_PAST_DAYS),
          toDate: shiftDate(today, DEFAULT_WINDOW_DAYS - 1),
        },
        `${now.toISOString()} (KST ${today})`,
      );
    }
  }
});

test('--past-days 0 은 사이클 1 의 창([오늘, 오늘+29])을 그대로 복원한다', () => {
  // KST 자정 직후 — 되돌리기 탈출구가 경계에서도 맞는지.
  const now = new Date('2026-09-01T15:00:00Z'); // KST 2026-09-02 00:00
  assert.deepEqual(crawlWindow(now, { pastDays: 0 }), {
    fromDate: '2026-09-02',
    toDate: '2026-10-01',
  });
});
