# task-002 spec — DB 스키마 + RLS + migration   확정일: TBD

> PLAN: [task-002] (deep) · 결정 백링크: E1·E3·E10 · 실행계획: [docs/EXECUTION-PLAN.md](../../EXECUTION-PLAN.md)

## 1. 배경 / 문제

모든 lane의 선행 차단점. 스키마·RLS·migration 없이는 크롤러 upsert(task-005), 앱 데이터 조회(task-010~013), 스탬프 적립(task-014)이 전부 불가.

DB는 task-001에서 셋업된 맥미니 Supabase(Postgres 17, `127.0.0.1:5434`). 지금은 테이블이 전혀 없음.

## 2. 목표 / 비목표

**목표 (DoD — 완료 기준):**
- ☐ `teams`, `stadiums`, `games`, `restaurants`, `planb_places`, `profiles`, `stamps` 7개 테이블 생성
- ☐ RLS enabled: 콘텐츠 테이블 public-read, profiles/stamps owner-scoped
- ☐ 크롤러 service_role로 `games` upsert 동작 검증 (psql 직결)
- ☐ 앱 anon key로 `games` SELECT 됨, INSERT 거부됨 검증
- ☐ 앱 anon key로 본인 `stamps` INSERT·SELECT 됨, 타인 것은 거부됨 검증
- ☐ migration SQL 파일이 `supabase/migrations/` 에 위치, 재실행 멱등(CREATE TABLE IF NOT EXISTS + CREATE POLICY IF NOT EXISTS)
- ☐ `.env.example` 에 `DATABASE_URL` 문서화
- ☐ `make migrate` 또는 sh 스크립트로 로컬 맥미니에서 1회 실행 성공

**비목표 (YAGNI):**
- 실제 콘텐츠 시딩 (task-003·004)
- 크롤러 코드 (task-005·006)
- Flutter 앱 연동 (task-007+)
- 카카오 OAuth provider 설정 (task-009)
- Storage 버킷/정책 (이미지 업로드는 v2)
- 심화 게임화 테이블 (뱃지·랭킹 등 V2)

## 3. 설계(안)

### 3-1. 테이블 관계

```
teams ←──── stadiums ←──── games
  │              │              └── home_team_id → teams
  │              │              └── away_team_id → teams
  │              ├──── restaurants
  │              └──── planb_places
  │
auth.users ──── profiles ──── favorite_team_id → teams
      │
      └──────── stamps ──── stadium_id → stadiums
```

### 3-2. 테이블 스키마

#### teams
```sql
id             uuid DEFAULT gen_random_uuid() PRIMARY KEY
name           text NOT NULL  -- "두산 베어스"
short_name     text NOT NULL  -- "두산"
abbr           text NOT NULL UNIQUE  -- "OB" / "LG" / "HH" 등
primary_color  text NOT NULL  -- "#131230" hex
secondary_color text NOT NULL -- "#C0C0C0" hex
```

#### stadiums
```sql
id           uuid DEFAULT gen_random_uuid() PRIMARY KEY
name         text NOT NULL          -- "잠실야구장"
team_id      uuid REFERENCES teams(id) NOT NULL
city         text NOT NULL          -- "서울"
address      text NOT NULL
lat          double precision NOT NULL
lng          double precision NOT NULL
stamp_radius_m integer NOT NULL DEFAULT 500  -- GPS 스탬프 임계값 (E7)
parking_info text   -- 주차 안내 (마크다운)
seating_info text   -- 좌석 뷰·구역 안내
route_info   text   -- 동선 (외야·내야·입구별)
convenience_info text  -- 편의점 위치·운영시간
```

#### games
```sql
id             uuid DEFAULT gen_random_uuid() PRIMARY KEY
game_id        text NOT NULL UNIQUE   -- 크롤러 dedup 키 (KBO 페이지 파싱 고유값)
home_team_id   uuid REFERENCES teams(id) NOT NULL
away_team_id   uuid REFERENCES teams(id) NOT NULL
stadium_id     uuid REFERENCES stadiums(id) NOT NULL
scheduled_at   timestamptz NOT NULL
status         text NOT NULL DEFAULT 'scheduled'
               -- 'scheduled' | 'in_progress' | 'finished' | 'cancelled' | 'postponed'
updated_at     timestamptz NOT NULL DEFAULT now()
```

> `game_id` 컬럼이 크롤러 upsert + 중복방지 핵심. 형식은 task-005에서 확정하지만 text로 충분.

#### restaurants
```sql
id           uuid DEFAULT gen_random_uuid() PRIMARY KEY
stadium_id   uuid REFERENCES stadiums(id) NOT NULL
name         text NOT NULL
pick_type    text NOT NULL  -- 'player' | 'fan' | 'editor'  (CHECK 제약)
category     text           -- "한식" / "카페" / "술집" 등 자유 태그
address      text
lat          double precision
lng          double precision
source_url   text NOT NULL  -- 출처 링크 필수 (E8)
description  text
created_at   timestamptz NOT NULL DEFAULT now()
```

#### planb_places
```sql
id           uuid DEFAULT gen_random_uuid() PRIMARY KEY
stadium_id   uuid REFERENCES stadiums(id) NOT NULL
name         text NOT NULL
category     text NOT NULL  -- "카페" / "쇼핑몰" / "영화관" / "박물관" 등
address      text
lat          double precision
lng          double precision
source_url   text NOT NULL
description  text
created_at   timestamptz NOT NULL DEFAULT now()
```

#### profiles
```sql
id               uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
favorite_team_id uuid REFERENCES teams(id)
display_name     text
created_at       timestamptz NOT NULL DEFAULT now()
updated_at       timestamptz NOT NULL DEFAULT now()
```

> `id = auth.users.id` — 가입 시 trigger로 자동 생성 (아래 §3-3).

#### stamps
```sql
id          uuid DEFAULT gen_random_uuid() PRIMARY KEY
user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
stadium_id  uuid NOT NULL REFERENCES stadiums(id)
stamped_at  timestamptz NOT NULL DEFAULT now()
lat         double precision NOT NULL  -- 발급 시점 GPS
lng         double precision NOT NULL
UNIQUE(user_id, stadium_id)  -- 구장당 1회 (E7)
```

### 3-3. 자동 profile 생성 trigger

```sql
CREATE FUNCTION handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles(id) VALUES (NEW.id);
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();
```

### 3-4. RLS 정책

| 테이블 | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| teams | public | ✗ | ✗ | ✗ |
| stadiums | public | ✗ | ✗ | ✗ |
| games | public | ✗ | ✗ | ✗ |
| restaurants | public | ✗ | ✗ | ✗ |
| planb_places | public | ✗ | ✗ | ✗ |
| profiles | `uid = id` | `uid = id` | `uid = id` | ✗ |
| stamps | `uid = user_id` | `uid = user_id` | ✗ | ✗ |

> service_role은 RLS를 자동 우회 → 크롤러 `games` upsert, 시드 스크립트 INSERT 모두 별도 정책 불필요.

## 4. 대안 & 결정 ★

### D1 — 마이그레이션 실행 방법

| 방법 | 장점 | 단점 |
|---|---|---|
| **A. 단순 psql + sh 스크립트** | 툴 설치 0, 직관적 | CLI 없어도 됨. 재실행 멱등은 SQL로 직접 보장 필요 |
| B. Supabase CLI `supabase db push` | CLI가 migration 상태 추적 | self-hosted 에선 `--db-url` 플래그 필요. 선언형 pull 기능이 흐려짐 |
| C. dbmate | 마이그레이션 버전 추적, 롤백 | 별도 바이너리 설치, 오버킬(dogfood) |

→ **A 채택**. `supabase/migrations/*.sql` + `scripts/migrate.sh` (psql 래퍼). 멱등은 `IF NOT EXISTS` / `OR REPLACE` / `DO $$ BEGIN ... EXCEPTION WHEN duplicate_object ...` 패턴.

### D2 — pick_type 구현 (restaurants)

| 방법 | 장점 | 단점 |
|---|---|---|
| **text + CHECK constraint** | v1.5(LLM선수픽·팬제보픽) 값 추가 시 ALTER 불필요 | 오타 허용(스크립트 레벨에서 막아야) |
| Postgres ENUM | DB 레벨 강타입 | 값 추가 시 `ALTER TYPE` 필요 (v1.5 걸림돌) |

→ **text + CHECK 채택**. E8 배지가 v2에서 LLM·제보로 확장되므로 enum은 오버 잠금.

### D3 — 구장 가이드 저장 방식

| 방법 | 장점 | 단점 |
|---|---|---|
| **stadiums 에 text 컬럼 추가** | JOIN 없음, 단순 | 컬럼 수 많아짐 (4개) |
| 별도 stadium_guides 테이블 | 정규화, 다국어 확장 쉬움 | JOIN 추가, dogfood에 오버킬 |
| JSONB 1컬럼 | 유연 | 타입 불명확, 앱 파싱 부담 |

→ **stadiums 컬럼 추가 채택** (`parking_info`, `seating_info`, `route_info`, `convenience_info`). 4개 컬럼이 스키마를 읽기 명확하게 하고 JOIN 없이 사용 가능.

## 5. 영향 / 리스크

- **계약 범위**: 이 migration이 확정하면 task-003~017 전부가 이 컬럼명·타입을 기준으로 코드 작성. 스키마 변경 = 이후 task 파급.
- **롤백**: psql 직결 DROP TABLE (데이터 없는 개발 초기라 OK). 시딩 시작 이후엔 dump 먼저.
- **game_id 형식 미확정**: task-005 크롤러가 KBO 페이지에서 파싱할 고유값. text UNIQUE로 열어두고 task-005에서 실제 형식 채운다.
- **카카오 OAuth**: auth.users는 task-009에서 연결 — profiles trigger는 지금 심어두면 task-009 때 자동 동작.

## 6. 의존 / 사인오프

- **의존**: task-001 Supabase 구동 완료 (`127.0.0.1:5434` 접근 가능) ✅
- **차단**: task-003(시딩), task-004(콘텐츠), task-005(크롤러), task-007(앱 스캐폴드) 전부 이 스키마 대기
- **사인오프**: @arden (솔로)
