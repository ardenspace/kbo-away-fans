"""KBO 공식 일정 fetch (D1: koreabaseball.com).

엔드포인트는 월 단위 JSON 을 반환한다:
  POST /ws/Schedule.asmx/GetScheduleList
  data: leId=1 & srIdList=0,9,6 & seasonId=YYYY & gameMonth=MM & teamId=
응답: {"rows": [{"row": [cell, ...]}, ...]}  (cell = {"Text","Class",...})

코어는 raw rows 만 돌려준다. 파싱은 parse.py.
실패 시 예외를 올린다(graceful/알림은 task-006).
"""
from __future__ import annotations

from typing import Iterable

import requests

ENDPOINT = "https://www.koreabaseball.com/ws/Schedule.asmx/GetScheduleList"
# srIdList: 0=정규시즌, 9=포스트시즌, 6=시범경기 (정규 위주지만 폭넓게)
SR_ID_LIST = "0,9,6"
LE_ID = "1"  # KBO 리그
HEADERS = {
    "User-Agent": "Mozilla/5.0 (kbo-away-fans crawler; dogfood)",
    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
    "Referer": "https://www.koreabaseball.com/Schedule/Schedule.aspx",
    "X-Requested-With": "XMLHttpRequest",
}
TIMEOUT = 20


def fetch_month(year: int, month: int) -> list[dict]:
    """해당 연/월 일정의 raw rows 반환. 빈 달은 []."""
    resp = requests.post(
        ENDPOINT,
        headers=HEADERS,
        data={
            "leId": LE_ID,
            "srIdList": SR_ID_LIST,
            "seasonId": str(year),
            "gameMonth": f"{month:02d}",
            "teamId": "",
        },
        timeout=TIMEOUT,
    )
    resp.raise_for_status()
    payload = resp.json()
    return payload.get("rows", []) or []


def months_in_range(date_from, date_to) -> Iterable[tuple[int, int]]:
    """[from, to] 를 덮는 (year, month) 들 (중복 없이, 오름차순)."""
    y, m = date_from.year, date_from.month
    while (y, m) <= (date_to.year, date_to.month):
        yield (y, m)
        m += 1
        if m > 12:
            m = 1
            y += 1


if __name__ == "__main__":
    import argparse
    import datetime as dt
    import json

    ap = argparse.ArgumentParser(description="KBO 일정 fetch 스모크")
    ap.add_argument("--from", dest="d_from", required=True)
    ap.add_argument("--to", dest="d_to", required=True)
    args = ap.parse_args()
    d_from = dt.date.fromisoformat(args.d_from)
    d_to = dt.date.fromisoformat(args.d_to)
    total = 0
    for y, mo in months_in_range(d_from, d_to):
        rows = fetch_month(y, mo)
        total += len(rows)
        print(f"{y}-{mo:02d}: {len(rows)} rows")
    print(json.dumps({"total_rows": total}, ensure_ascii=False))
