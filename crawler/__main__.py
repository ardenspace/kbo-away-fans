"""CLI 진입점: python -m crawler --from YYYY-MM-DD --to YYYY-MM-DD"""
from __future__ import annotations

import argparse
import datetime as dt
import sys

from .pipeline import run


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="crawler", description="KBO 일정 크롤러 코어")
    ap.add_argument("--from", dest="d_from", required=True, help="YYYY-MM-DD")
    ap.add_argument("--to", dest="d_to", required=True, help="YYYY-MM-DD")
    args = ap.parse_args(argv)

    d_from = dt.date.fromisoformat(args.d_from)
    d_to = dt.date.fromisoformat(args.d_to)
    if d_to < d_from:
        ap.error("--to 가 --from 보다 빠릅니다")

    result = run(d_from, d_to)
    skipped = result.pop("skipped")
    print(f"[crawler] {result}")
    if skipped:
        print(f"[crawler] 스킵 {len(skipped)}건:")
        for raw, reason in skipped:
            print(f"  - {raw.date} {raw.away_name}@{raw.home_name} ({raw.stadium_name}): {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
