"""raw rows → 정규화된 경기 레코드.

KBO JSON row 구조 (cell = {"Text","Class",...}):
  - Class="day"  : "06.02(화)"  (그날 첫 행에만, RowSpan=경기수)
  - Class="time" : "<b>18:30</b>"
  - Class="play" : "<span>어웨이</span><em>점수|vs</em><span>홈</span>"
  - 끝에서 -2 셀 : 구장명("잠실")
  - 끝 셀        : 상태("-" 정상 / "우천취소" / "연기" ...)
점수 span(win/lose/same)이 있으면 이미 치러진 경기, "vs"만 있으면 예정.
day 셀은 행마다 없을 수 있어 날짜는 직전 day 값을 이어서 쓴다.
"""
from __future__ import annotations

import datetime as dt
import re
from dataclasses import dataclass

_TAG = re.compile(r"<[^>]+>")
_DAY = re.compile(r"(\d{2})\.(\d{2})")
_DIGIT = re.compile(r"\d")


@dataclass
class RawGame:
    date: dt.date
    time_str: str | None  # "18:30" or None
    away_name: str  # short_name, e.g. "한화"
    home_name: str  # short_name, e.g. "두산"
    stadium_name: str  # e.g. "잠실"
    status_label: str  # raw 끝셀 텍스트 ("-" / "우천취소" ...)
    scored: bool  # 점수가 표시됨 = 이미 치러짐


def _text(cell: dict | None) -> str:
    return _TAG.sub("", (cell or {}).get("Text") or "").strip()


def _cell_by_class(row: list[dict], cls: str) -> dict | None:
    for c in row:
        if c.get("Class") == cls:
            return c
    return None


def _parse_play(html: str) -> tuple[str, str, bool]:
    """play 셀 → (away_short, home_short, scored)."""
    em = re.search(r"<em>(.*?)</em>", html, re.S)
    scored = bool(em and _DIGIT.search(em.group(1)))
    # <em>...</em> 제거 후 남는 <span> 들이 [어웨이, 홈]
    outer = re.sub(r"<em>.*?</em>", "|", html, flags=re.S)
    names = [_TAG.sub("", s).strip() for s in re.findall(r"<span>(.*?)</span>", outer, re.S)]
    names = [n for n in names if n]
    if len(names) < 2:
        raise ValueError(f"play 셀에서 팀 2개를 못 찾음: {html!r}")
    return names[0], names[-1], scored


def parse_month(rows: list[dict], year: int) -> list[RawGame]:
    """월 raw rows → RawGame 리스트 (날짜·시간 순서 유지)."""
    games: list[RawGame] = []
    cur_date: dt.date | None = None
    for r in rows:
        row = r.get("row") or []
        if not row:
            continue
        day_cell = _cell_by_class(row, "day")
        if day_cell:
            m = _DAY.search(_text(day_cell))
            if m:
                cur_date = dt.date(year, int(m.group(1)), int(m.group(2)))
        play_cell = _cell_by_class(row, "play")
        if cur_date is None or play_cell is None:
            continue
        away, home, scored = _parse_play(play_cell.get("Text") or "")
        time_txt = _text(_cell_by_class(row, "time")) or None
        if time_txt and not re.match(r"^\d{1,2}:\d{2}$", time_txt):
            time_txt = None
        games.append(
            RawGame(
                date=cur_date,
                time_str=time_txt,
                away_name=away,
                home_name=home,
                stadium_name=_text(row[-2]) if len(row) >= 2 else "",
                status_label=_text(row[-1]) if row else "",
                scored=scored,
            )
        )
    return games


if __name__ == "__main__":
    import json
    import sys

    path = sys.argv[1] if len(sys.argv) > 1 else "crawler/fixtures/kbo_2026_06.json"
    year = int(sys.argv[2]) if len(sys.argv) > 2 else 2026
    data = json.load(open(path))
    parsed = parse_month(data.get("rows", []), year)
    print(f"parsed {len(parsed)} games")
    from collections import Counter

    print("status_labels:", dict(Counter(g.status_label for g in parsed)))
    for g in parsed[:5]:
        print(g)
