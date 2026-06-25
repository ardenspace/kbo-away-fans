"""RawGame → games 행(dict). 팀/구장 매핑, 상태 정규화, game_id 합성, KST→UTC.

매핑은 DB 비종속 — 조회용 dict 를 인자로 받는다(db.py 가 채워 넣음).

구장 매핑 노트(task-005 spike 결정):
 spec 의 "홈팀→구장 역참조" 대신 **소스 구장 컬럼을 별칭으로 매핑**한다.
 이유: ① 잠실은 두산·LG 공용인데 stadiums 시드는 잠실=두산(OB) 1행뿐 →
 LG 홈경기 역참조가 깨짐. ② 소스가 구장을 직접 주므로 중립/공용구장도 정확.
 짧은 소스명(잠실)→공식명(잠실야구장) 별칭표로 흡수.
"""
from __future__ import annotations

import datetime as dt
from dataclasses import dataclass

from .parse import RawGame

KST = dt.timezone(dt.timedelta(hours=9))

# 소스 구장 짧은 이름 → stadiums.name 공식명
STADIUM_ALIAS: dict[str, str] = {
    "잠실": "잠실야구장",
    "고척": "고척스카이돔",
    "문학": "인천SSG랜더스필드",
    "인천": "인천SSG랜더스필드",
    "사직": "사직야구장",
    "대구": "대구삼성라이온즈파크",
    "대전": "한화생명이글스파크",
    "광주": "광주기아챔피언스필드",
    "창원": "창원NC파크",
    "수원": "수원KT위즈파크",
}


@dataclass
class GameRow:
    game_id: str
    away_team_id: str
    home_team_id: str
    stadium_id: str
    scheduled_at: str  # ISO8601 UTC
    status: str


def normalize_status(label: str, scored: bool) -> str:
    """끝셀 라벨 + 점수유무 → games.status enum."""
    if "취소" in label:
        return "cancelled"
    if "연기" in label:
        return "postponed"
    if "서스" in label:  # 서스펜디드 = 중단/속개 예정
        return "postponed"
    return "finished" if scored else "scheduled"


def to_utc_iso(date: dt.date, time_str: str | None) -> str:
    hh, mm = (int(x) for x in time_str.split(":")) if time_str else (0, 0)
    kst = dt.datetime(date.year, date.month, date.day, hh, mm, tzinfo=KST)
    return kst.astimezone(dt.timezone.utc).isoformat()


def build_game_id(date: dt.date, away_abbr: str, home_abbr: str, dh: int) -> str:
    return f"{date:%Y%m%d}{away_abbr}{home_abbr}{dh}"


def map_games(
    raws: list[RawGame],
    teams_by_short: dict[str, dict],
    stadiums_by_name: dict[str, str],
) -> tuple[list[GameRow], list[tuple[RawGame, str]]]:
    """RawGame 들 → (GameRow 리스트, [(스킵된 raw, 사유)]).

    teams_by_short: short_name → {"id":..., "abbr":...}
    stadiums_by_name: 공식 stadium name → stadium_id
    더블헤더는 (date,away,home) 등장 순서로 dh 0,1 부여 → game_id 분리.
    """
    rows: list[GameRow] = []
    skipped: list[tuple[RawGame, str]] = []
    dh_seen: dict[tuple, int] = {}
    for g in raws:
        away = teams_by_short.get(g.away_name)
        home = teams_by_short.get(g.home_name)
        if not away or not home:
            miss = g.away_name if not away else g.home_name
            skipped.append((g, f"미등록 팀: {miss}"))
            continue
        official = STADIUM_ALIAS.get(g.stadium_name)
        stadium_id = stadiums_by_name.get(official) if official else None
        if not stadium_id:
            skipped.append((g, f"미등록 구장: {g.stadium_name}"))
            continue
        key = (g.date, away["abbr"], home["abbr"])
        dh = dh_seen.get(key, 0)
        dh_seen[key] = dh + 1
        rows.append(
            GameRow(
                game_id=build_game_id(g.date, away["abbr"], home["abbr"], dh),
                away_team_id=away["id"],
                home_team_id=home["id"],
                stadium_id=stadium_id,
                scheduled_at=to_utc_iso(g.date, g.time_str),
                status=normalize_status(g.status_label, g.scored),
            )
        )
    return rows, skipped
