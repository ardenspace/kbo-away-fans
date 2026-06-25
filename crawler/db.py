"""Postgres 직결 접근 (DECISIONS task-001 E1). teams/stadiums 로드 + games upsert.

postgres 슈퍼유저로 접속 → RLS 우회. 앱은 Kong/anon 경유(키격리 E10).
"""
from __future__ import annotations

import datetime as dt
from contextlib import contextmanager
from dataclasses import astuple

import psycopg2
from psycopg2.extras import RealDictCursor, execute_values

from .config import config
from .mapping import GameRow

_UPSERT_SQL = """
INSERT INTO games
  (game_id, away_team_id, home_team_id, stadium_id, scheduled_at, status, updated_at)
VALUES %s
ON CONFLICT (game_id) DO UPDATE SET
  away_team_id = EXCLUDED.away_team_id,
  home_team_id = EXCLUDED.home_team_id,
  stadium_id   = EXCLUDED.stadium_id,
  scheduled_at = EXCLUDED.scheduled_at,
  status       = EXCLUDED.status,
  updated_at   = EXCLUDED.updated_at
"""


@contextmanager
def connect():
    config.require_db()
    conn = psycopg2.connect(config.DATABASE_URL)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def load_teams_by_short(conn) -> dict[str, dict]:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT id, short_name, abbr FROM teams")
        return {r["short_name"]: {"id": str(r["id"]), "abbr": r["abbr"]} for r in cur}


def load_stadiums_by_name(conn) -> dict[str, str]:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT id, name FROM stadiums")
        return {r["name"]: str(r["id"]) for r in cur}


def load_scheduled_at_on(conn, kst_date: dt.date) -> list[dt.datetime]:
    """KST 기준 kst_date 에 열리는 경기들의 scheduled_at(UTC aware) 목록.

    gameday 윈도우(첫경기 30분전 ~ 막경기 1h후) 판정용 (task-006). 취소/연기는 제외.
    """
    with conn.cursor() as cur:
        cur.execute(
            "SELECT scheduled_at FROM games "
            "WHERE (scheduled_at AT TIME ZONE 'Asia/Seoul')::date = %s "
            "AND status NOT IN ('cancelled', 'postponed')",
            (kst_date,),
        )
        return [r[0] for r in cur.fetchall()]


def upsert_games(conn, rows: list[GameRow]) -> int:
    """game_id 충돌 시 갱신(reconcile). updated_at 갱신 포함. 적재 건수 반환."""
    if not rows:
        return 0
    now = dt.datetime.now(dt.timezone.utc)
    # GameRow: (game_id, away_team_id, home_team_id, stadium_id, scheduled_at, status)
    values = [astuple(r) + (now,) for r in rows]
    with conn.cursor() as cur:
        execute_values(cur, _UPSERT_SQL, values)
    return len(values)
