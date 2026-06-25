"""fetch → parse → map → upsert 결선. 단발 실행.

운영(cron/주기/알림/graceful)은 task-006 이 이 run() 을 감싼다.
"""
from __future__ import annotations

import datetime as dt

from . import db
from .fetch import fetch_month, months_in_range
from .mapping import map_games
from .parse import parse_month


def run(date_from: dt.date, date_to: dt.date) -> dict:
    """[date_from, date_to] 일정 크롤 → games upsert. 집계 dict 반환.

    실패(네트워크/파싱)는 예외로 올린다 — graceful 처리는 task-006.
    """
    raws = []
    for year, month in months_in_range(date_from, date_to):
        rows = fetch_month(year, month)
        raws.extend(parse_month(rows, year))
    # 월 단위 fetch 라 범위 밖 날짜 잘라냄
    raws = [g for g in raws if date_from <= g.date <= date_to]

    with db.connect() as conn:
        teams_by_short = db.load_teams_by_short(conn)
        stadiums_by_name = db.load_stadiums_by_name(conn)
        mapped, skipped = map_games(raws, teams_by_short, stadiums_by_name)
        upserted = db.upsert_games(conn, mapped)

    by_status: dict[str, int] = {}
    for r in mapped:
        by_status[r.status] = by_status.get(r.status, 0) + 1

    return {
        "range": f"{date_from} ~ {date_to}",
        "fetched": len(raws),
        "mapped": len(mapped),
        "skipped": skipped,
        "upserted": upserted,
        "by_status": by_status,
    }
