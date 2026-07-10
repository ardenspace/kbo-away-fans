#!/usr/bin/env python3
"""시드 스크립트: scripts/seed/data/*.json → kbo-supabase-db upsert (멱등)

사용법:
  python3 scripts/seed.py
  SUPABASE_DB_CONTAINER=my-db python3 scripts/seed.py
"""
import json
import subprocess
import sys
from pathlib import Path

CONTAINER = "kbo-supabase-db"
DATA_DIR = Path(__file__).parent / "seed" / "data"


def q(v) -> str:
    """Python 값 → SQL 리터럴 (단순 이스케이프, 시드 데이터 전용)"""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return str(v)
    return "'" + str(v).replace("'", "''") + "'"


def run_sql(sql: str, label: str = "") -> None:
    container = __import__("os").environ.get("SUPABASE_DB_CONTAINER", CONTAINER)
    if label:
        print(f"  ▶ {label}")
    result = subprocess.run(
        [
            "docker", "exec", "-i", container,
            "psql", "-U", "postgres", "-d", "postgres",
            "-v", "ON_ERROR_STOP=1", "-q",
        ],
        input=sql.encode(),
        capture_output=True,
    )
    out = result.stdout.decode().strip()
    if out:
        print(f"    {out}")
    if result.returncode != 0:
        print(result.stderr.decode(), file=sys.stderr)
        sys.exit(1)


def setup_constraints() -> None:
    """upsert에 필요한 UNIQUE 제약 추가 (존재 체크 후 추가, 멱등)"""
    run_sql(
        """
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stadiums_name_key') THEN
    ALTER TABLE public.stadiums ADD CONSTRAINT stadiums_name_key UNIQUE (name);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'restaurants_stadium_name_key') THEN
    ALTER TABLE public.restaurants
      ADD CONSTRAINT restaurants_stadium_name_key UNIQUE (stadium_id, name);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'planb_places_stadium_name_key') THEN
    ALTER TABLE public.planb_places
      ADD CONSTRAINT planb_places_stadium_name_key UNIQUE (stadium_id, name);
  END IF;
END $$;
""",
        "UNIQUE 제약 확인",
    )


def seed_teams() -> None:
    teams = json.loads((DATA_DIR / "teams.json").read_text())
    print(f"\n[teams] {len(teams)}건")
    for t in teams:
        run_sql(
            f"""
INSERT INTO public.teams(name, short_name, abbr, primary_color, secondary_color)
VALUES ({q(t['name'])}, {q(t['short_name'])}, {q(t['abbr'])},
        {q(t['primary_color'])}, {q(t['secondary_color'])})
ON CONFLICT (abbr) DO UPDATE SET
  name            = EXCLUDED.name,
  short_name      = EXCLUDED.short_name,
  primary_color   = EXCLUDED.primary_color,
  secondary_color = EXCLUDED.secondary_color;
""",
            t["name"],
        )


def seed_stadiums() -> None:
    stadiums = json.loads((DATA_DIR / "stadiums.json").read_text())
    print(f"\n[stadiums] {len(stadiums)}건")
    for s in stadiums:
        run_sql(
            f"""
INSERT INTO public.stadiums(
  name, team_id, city, address, lat, lng, stamp_radius_m,
  parking_info, seating_info, route_info, convenience_info
)
SELECT
  {q(s['name'])},
  (SELECT id FROM public.teams WHERE abbr = {q(s['team_abbr'])}),
  {q(s['city'])}, {q(s['address'])},
  {q(s['lat'])}, {q(s['lng'])}, {q(s['stamp_radius_m'])},
  {q(s.get('parking_info'))}, {q(s.get('seating_info'))},
  {q(s.get('route_info'))}, {q(s.get('convenience_info'))}
ON CONFLICT (name) DO UPDATE SET
  city             = EXCLUDED.city,
  address          = EXCLUDED.address,
  lat              = EXCLUDED.lat,
  lng              = EXCLUDED.lng,
  stamp_radius_m   = EXCLUDED.stamp_radius_m,
  parking_info     = EXCLUDED.parking_info,
  seating_info     = EXCLUDED.seating_info,
  route_info       = EXCLUDED.route_info,
  convenience_info = EXCLUDED.convenience_info;
""",
            s["name"],
        )


def seed_restaurants() -> None:
    items = json.loads((DATA_DIR / "restaurants.json").read_text())
    print(f"\n[restaurants] {len(items)}건")
    for r in items:
        run_sql(
            f"""
INSERT INTO public.restaurants(
  stadium_id, name, pick_type, category,
  address, lat, lng, source_url, description
)
SELECT
  (SELECT id FROM public.stadiums WHERE name = {q(r['stadium_name'])}),
  {q(r['name'])}, {q(r['pick_type'])}, {q(r.get('category'))},
  {q(r.get('address'))}, {q(r.get('lat'))}, {q(r.get('lng'))},
  {q(r['source_url'])}, {q(r.get('description'))}
ON CONFLICT (stadium_id, name) DO UPDATE SET
  pick_type   = EXCLUDED.pick_type,
  category    = EXCLUDED.category,
  address     = EXCLUDED.address,
  lat         = EXCLUDED.lat,
  lng         = EXCLUDED.lng,
  source_url  = EXCLUDED.source_url,
  description = EXCLUDED.description;
""",
            f"{r['stadium_name']} / {r['name']}",
        )


def seed_planb() -> None:
    items = json.loads((DATA_DIR / "planb_places.json").read_text())
    print(f"\n[planb_places] {len(items)}건")
    for p in items:
        run_sql(
            f"""
INSERT INTO public.planb_places(
  stadium_id, name, category,
  address, lat, lng, source_url, description
)
SELECT
  (SELECT id FROM public.stadiums WHERE name = {q(p['stadium_name'])}),
  {q(p['name'])}, {q(p['category'])},
  {q(p.get('address'))}, {q(p.get('lat'))}, {q(p.get('lng'))},
  {q(p['source_url'])}, {q(p.get('description'))}
ON CONFLICT (stadium_id, name) DO UPDATE SET
  category    = EXCLUDED.category,
  address     = EXCLUDED.address,
  lat         = EXCLUDED.lat,
  lng         = EXCLUDED.lng,
  source_url  = EXCLUDED.source_url,
  description = EXCLUDED.description;
""",
            f"{p['stadium_name']} / {p['name']}",
        )


if __name__ == "__main__":
    print("🌱 seed 시작")
    setup_constraints()
    seed_teams()
    seed_stadiums()
    seed_restaurants()
    seed_planb()
    print("\n✅ seed 완료")
