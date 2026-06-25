"""크롤러 운영 래퍼 (task-006, E4·E5).

단발 `pipeline.run()` 을 무인 운영으로 감싼다:
  - **2단 주기**(E4): daily(1일1회, 향후 N일 재크롤) / gameday(매분 깨우되 경기 윈도우 안에서만)
  - **graceful**(E5): run() 예외를 잡아 DB 무변경 + 실패 exit. 앱은 캐시된 DB 로 계속 동작.
  - **텔레그램 실패 알림**(E5): 실패 시에만 1건. 성공·no-op 은 무알림.
  - **중복 방지**: fcntl.flock 비차단 — 매분 gameday 가 느린 크롤과 겹치면 즉시 스킵.

스케줄러는 launchd LaunchAgent (cron 아님 — 맥미니 인프라 선례, infra/crawler/*.plist).
실행:  python -m crawler.ops --mode daily
       python -m crawler.ops --mode gameday
"""
from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import sys
from contextlib import contextmanager
from pathlib import Path

from . import db
from .notify import send_telegram
from .pipeline import run

KST = dt.timezone(dt.timedelta(hours=9))

# gameday 윈도우 = [첫경기 - PRE, 막경기 + POST] (E4)
_PRE = dt.timedelta(minutes=30)
_POST = dt.timedelta(hours=1)

_LOCK_PATH = Path(__file__).resolve().parent / ".ops.lock"
_DEFAULT_DAYS = 14  # daily 재크롤 향후 범위


# ── 순수 로직 (DB/네트워크 무관, 테스트 대상) ────────────────────────────

def game_window(
    scheduled_ats: list[dt.datetime],
) -> tuple[dt.datetime, dt.datetime] | None:
    """경기 시각들 → (윈도우 시작, 끝). 경기 없으면 None."""
    if not scheduled_ats:
        return None
    return (min(scheduled_ats) - _PRE, max(scheduled_ats) + _POST)


def in_window(now: dt.datetime, scheduled_ats: list[dt.datetime]) -> bool:
    """now 가 경기 윈도우 안인가. 경기 없으면 False."""
    win = game_window(scheduled_ats)
    return win is not None and win[0] <= now <= win[1]


# ── 락 ──────────────────────────────────────────────────────────────────

@contextmanager
def flock_or_skip(path: Path = _LOCK_PATH):
    """비차단 flock. 잡으면 (True) 진입, 이미 잡혀 있으면 (False) 즉시 양보."""
    fh = open(path, "w")
    try:
        try:
            fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (OSError, BlockingIOError):
            yield False
            return
        yield True
    finally:
        fh.close()


# ── 운영 진입점 ──────────────────────────────────────────────────────────

def _crawl_daily(today: dt.date, days: int) -> dict:
    return run(today, today + dt.timedelta(days=days))


def _crawl_gameday(today: dt.date, now: dt.datetime) -> dict | None:
    """오늘 경기 윈도우 안이면 오늘분 크롤, 밖이면 None(no-op)."""
    with db.connect() as conn:
        scheduled = db.load_scheduled_at_on(conn, today)
    if not in_window(now, scheduled):
        return None
    return run(today, today)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="crawler.ops", description="KBO 크롤러 운영 래퍼")
    ap.add_argument("--mode", choices=("daily", "gameday"), required=True)
    ap.add_argument("--days", type=int, default=_DEFAULT_DAYS, help="daily 재크롤 향후 일수")
    args = ap.parse_args(argv)

    now = dt.datetime.now(dt.timezone.utc)
    today = now.astimezone(KST).date()

    with flock_or_skip() as acquired:
        if not acquired:
            print(f"[ops:{args.mode}] 다른 크롤 실행 중 — 스킵")
            return 0
        try:
            if args.mode == "daily":
                result = _crawl_daily(today, args.days)
            else:
                result = _crawl_gameday(today, now)
            if result is None:
                print(f"[ops:gameday] 경기 윈도우 밖 — no-op ({today})")
            else:
                result.pop("skipped", None)
                print(f"[ops:{args.mode}] ok {result}")
            return 0
        except Exception as e:  # noqa: BLE001 — graceful: 잡아서 알림 후 실패 exit
            msg = f"⚠️ KBO 크롤러 실패 [{args.mode}] {today}: {type(e).__name__}: {e}"
            print(f"[ops:{args.mode}] {msg}", file=sys.stderr)
            send_telegram(msg)
            return 1


if __name__ == "__main__":
    sys.exit(main())
