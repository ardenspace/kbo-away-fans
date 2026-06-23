# task-002 plan   (spec: ./spec.md)

## 아키텍처 한 줄

`supabase/migrations/` 에 번호 순 SQL 파일 + `scripts/migrate.sh` psql 래퍼. 맥미니 `127.0.0.1:5434` 직결 실행.

## 파일 구조

```
supabase/
  migrations/
    001_teams.sql
    002_stadiums.sql
    003_games.sql
    004_restaurants.sql
    005_planb_places.sql
    006_profiles_stamps.sql   ← auth trigger 포함
    007_rls.sql
scripts/
  migrate.sh                  ← psql 래퍼 (DATABASE_URL 읽어 실행)
  migrate_dry_run.sh          ← \i 없이 syntax 확인용
.env.example                  ← DATABASE_URL 항목 추가
```

## Step 분해

- [ ] **Step 1** — `supabase/migrations/001_teams.sql` 작성 + 검증
- [ ] **Step 2** — `supabase/migrations/002_stadiums.sql` 작성 + 검증
- [ ] **Step 3** — `supabase/migrations/003_games.sql` 작성 + 검증
- [ ] **Step 4** — `supabase/migrations/004_restaurants.sql` + `005_planb_places.sql` 작성 + 검증
- [ ] **Step 5** — `supabase/migrations/006_profiles_stamps.sql` (auth trigger 포함) 작성 + 검증
- [ ] **Step 6** — `supabase/migrations/007_rls.sql` (RLS enable + 정책 전체) 작성 + 검증
- [ ] **Step 7** — `scripts/migrate.sh` 작성 + 맥미니 실제 실행 → 7개 테이블 생성 확인
- [ ] **Step 8** — DoD 검증: anon/service_role 권한 경계 psql 테스트

## 각 Step 상세

### Step 1 — teams
```sql
-- 멱등: IF NOT EXISTS
CREATE TABLE IF NOT EXISTS public.teams (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name            text NOT NULL,
  short_name      text NOT NULL,
  abbr            text NOT NULL UNIQUE,
  primary_color   text NOT NULL,
  secondary_color text NOT NULL
);
```
검증: `psql $DATABASE_URL -c "\d public.teams"` → 6컬럼 출력.

### Step 2 — stadiums
```sql
CREATE TABLE IF NOT EXISTS public.stadiums (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  name             text NOT NULL,
  team_id          uuid REFERENCES public.teams(id) NOT NULL,
  city             text NOT NULL,
  address          text NOT NULL,
  lat              double precision NOT NULL,
  lng              double precision NOT NULL,
  stamp_radius_m   integer NOT NULL DEFAULT 500,
  parking_info     text,
  seating_info     text,
  route_info       text,
  convenience_info text
);
```
검증: `\d public.stadiums` → 13컬럼.

### Step 3 — games
```sql
CREATE TABLE IF NOT EXISTS public.games (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id        text NOT NULL UNIQUE,
  home_team_id   uuid REFERENCES public.teams(id) NOT NULL,
  away_team_id   uuid REFERENCES public.teams(id) NOT NULL,
  stadium_id     uuid REFERENCES public.stadiums(id) NOT NULL,
  scheduled_at   timestamptz NOT NULL,
  status         text NOT NULL DEFAULT 'scheduled'
                 CHECK (status IN ('scheduled','in_progress','finished','cancelled','postponed')),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
```
검증: `\d public.games` → 8컬럼 + CHECK 제약 확인.

### Step 4 — restaurants + planb_places
```sql
CREATE TABLE IF NOT EXISTS public.restaurants (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  stadium_id   uuid REFERENCES public.stadiums(id) NOT NULL,
  name         text NOT NULL,
  pick_type    text NOT NULL CHECK (pick_type IN ('player','fan','editor')),
  category     text,
  address      text,
  lat          double precision,
  lng          double precision,
  source_url   text NOT NULL,
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.planb_places (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  stadium_id   uuid REFERENCES public.stadiums(id) NOT NULL,
  name         text NOT NULL,
  category     text NOT NULL,
  address      text,
  lat          double precision,
  lng          double precision,
  source_url   text NOT NULL,
  description  text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
```
검증: `\d public.restaurants` + `\d public.planb_places`.

### Step 5 — profiles + stamps + auth trigger
```sql
CREATE TABLE IF NOT EXISTS public.profiles (
  id               uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  favorite_team_id uuid REFERENCES public.teams(id),
  display_name     text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stamps (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stadium_id  uuid NOT NULL REFERENCES public.stadiums(id),
  stamped_at  timestamptz NOT NULL DEFAULT now(),
  lat         double precision NOT NULL,
  lng         double precision NOT NULL,
  UNIQUE(user_id, stadium_id)
);

-- auth trigger: 가입 시 profile 자동 생성
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles(id) VALUES (NEW.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```
검증: `\df public.handle_new_user` + `\d public.stamps` (UNIQUE 제약).

### Step 6 — RLS 정책
```sql
-- 콘텐츠 테이블: RLS enable + public SELECT
ALTER TABLE public.teams        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stadiums     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurants  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planb_places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stamps       ENABLE ROW LEVEL SECURITY;

-- 콘텐츠: public read (IF NOT EXISTS 대신 DROP IF EXISTS → CREATE 패턴으로 멱등)
DO $$ BEGIN
  DROP POLICY IF EXISTS "public_read" ON public.teams;
  CREATE POLICY "public_read" ON public.teams FOR SELECT USING (true);

  DROP POLICY IF EXISTS "public_read" ON public.stadiums;
  CREATE POLICY "public_read" ON public.stadiums FOR SELECT USING (true);

  DROP POLICY IF EXISTS "public_read" ON public.games;
  CREATE POLICY "public_read" ON public.games FOR SELECT USING (true);

  DROP POLICY IF EXISTS "public_read" ON public.restaurants;
  CREATE POLICY "public_read" ON public.restaurants FOR SELECT USING (true);

  DROP POLICY IF EXISTS "public_read" ON public.planb_places;
  CREATE POLICY "public_read" ON public.planb_places FOR SELECT USING (true);
END $$;

-- profiles: owner-scoped
DO $$ BEGIN
  DROP POLICY IF EXISTS "owner_select" ON public.profiles;
  CREATE POLICY "owner_select" ON public.profiles FOR SELECT USING (auth.uid() = id);

  DROP POLICY IF EXISTS "owner_insert" ON public.profiles;
  CREATE POLICY "owner_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

  DROP POLICY IF EXISTS "owner_update" ON public.profiles;
  CREATE POLICY "owner_update" ON public.profiles FOR UPDATE USING (auth.uid() = id);
END $$;

-- stamps: owner-scoped
DO $$ BEGIN
  DROP POLICY IF EXISTS "owner_select" ON public.stamps;
  CREATE POLICY "owner_select" ON public.stamps FOR SELECT USING (auth.uid() = user_id);

  DROP POLICY IF EXISTS "owner_insert" ON public.stamps;
  CREATE POLICY "owner_insert" ON public.stamps FOR INSERT WITH CHECK (auth.uid() = user_id);
END $$;
```
검증: `\dp public.*` → 각 테이블 policy 목록 출력.

### Step 7 — migrate.sh + 실제 실행
```bash
#!/usr/bin/env bash
set -euo pipefail
# DATABASE_URL: postgres://postgres:<password>@127.0.0.1:5434/postgres
DIR="$(cd "$(dirname "$0")/.." && pwd)/supabase/migrations"
for f in "$DIR"/*.sql; do
  echo "▶ $f"
  psql "$DATABASE_URL" -f "$f"
done
echo "✅ migration done"
```
검증: `bash scripts/migrate.sh` → 7개 파일 순차 실행, 오류 없음.
재실행(멱등 확인): 한 번 더 돌려 오류 없음.

### Step 8 — DoD 권한 경계 검증
psql로 직접 확인:
```sql
-- anon key로 games SELECT → rows 반환 (빈 테이블이면 0 rows OK)
-- service_role key로 games INSERT → 성공
-- anon key로 games INSERT → 거부 (new row violates row-level security)
-- anon key로 타인 stamps SELECT → 0 rows
```
실제 검증은 psql 세션에서 `SET ROLE anon` + `SET request.jwt.claims` 방식 또는
`psql $ANON_DB_URL` 로 anon 역할 시뮬레이션.

## 롤백

개발 초기 데이터 없음 → `DROP TABLE IF EXISTS ... CASCADE` (역순) + `DROP TRIGGER` + `DROP FUNCTION`.
`scripts/rollback.sh` 는 작성하지 않음 — psql 직결로 충분.
