---
status: approved
---

# kbo-away-fans — spec

## Resolved decisions
<!-- S로 강등된 항목은 표에 없고 Implementer discretion으로 내려감 -->
| decision | grade | choice | ADR |
|---|---|---|---|
| 크로스플랫폼 프레임워크 | XL | Flutter (긴급 패치는 Shorebird 옵션) | see decisions.md 2026-08-24 |
| 콘텐츠 수집·저장·배포 구조 | L | 서버 없음 — 크롤링+수작업 큐레이션 결과를 버전 있는 정적 JSON 번들로 배포, 앱이 받아 캐시 | see decisions.md 2026-08-24 |
| KBO 경기 일정 데이터 소스 | L | 스케줄러(cron) 크롤링 → schedule.json 계약; 앱은 계약만 소비 | see decisions.md 2026-08-24 |
| 지도 SDK | L | 네이버 지도 SDK (flutter_naver_map) — 앱 내 지도 표시, 상세 길안내만 외부 앱 | see decisions.md 2026-08-24 |
| 우천 취소 감지 | M | 경기일 고빈도(15–30분) 크롤링으로 schedule.json 갱신, 앱 폴링 | see decisions.md 2026-08-24 |
| 날씨 데이터 소스 | M | OpenWeatherMap 무료 티어, 얇은 래퍼 뒤 직접 호출 | see decisions.md 2026-08-24 |
| 스탬프 인증 방식 | M | MVP 미결정 — 구장 ID를 안정적 식별자로 보장만 | see decisions.md 2026-08-24 |
| UGC 대비 구조 | M | places.source 필드("curated" 고정) 예약까지만 | see decisions.md 2026-08-24 |
| 구장/테마 목록 | M | 콘텐츠는 1군 정규 홈구장 9곳, 테마는 팀 10개(잠실은 홈팀 기준 전환) | see decisions.md 2026-08-24 |
| 성공 지표 측정 | M | Firebase Analytics 익명 이벤트 (place_tap, map_open) | see decisions.md 2026-08-24 |

## Registries
<!-- 로스터(명단)만. 실제 파일 생성은 wellplan phase 1의 일 -->

### Design tokens
**Token source file:** `lib/design/tokens.dart` (기본 토큰) + `lib/design/team_themes.dart` (팀별 테마 토큰)

> 규칙: 토큰 파일 밖에서 raw hex/치수/폰트 리터럴 금지. 모든 색·간격·모서리·타이포·모션 값은 이름 있는 토큰에서 온다.

| name | purpose (one line) | location | use when |
|---|---|---|---|
| `color.*` | 기본 팔레트 + 시맨틱 색 (배경, 텍스트, 성공/경고) | `lib/design/tokens.dart` | 팀 테마와 무관한 모든 색 |
| `team.<id>.*` | 10개 팀 테마 (primary/secondary/on-color) — 구장 화면의 컬러 테마 전환 근거 | `lib/design/team_themes.dart` | 팀·구장 맥락이 있는 모든 색 |
| `space.*` | 간격 스케일 | `lib/design/tokens.dart` | 마진, 패딩, 갭 |
| `radius.*` | 모서리 스케일 — "통통 튀는" 톤이라 큰 라운드가 기본 | `lib/design/tokens.dart` | 카드, 시트, 칩, 버튼 |
| `type.*` | 폰트 패밀리·크기·굵기 — 트렌디하고 둥근 볼드 지향 | `lib/design/tokens.dart` | 모든 텍스트 |
| `motion.*` | 지속시간·커브 — 탄성(bouncy spring) 기본, 비/테마 전환 연출 포함 | `lib/design/tokens.dart` | 모든 애니메이션 |

### Shared components
**Shared component folder:** `lib/ui/shared/` (+ `lib/ui/shared/REGISTRY.md`)

> 규칙: 두 군데 이상에서 렌더되면 여기 먼저. 로스터에 없는데 공유 성격이면 공유 폴더에 만들고 같은 커밋에서 로스터에 행 추가.

| name | purpose (one line) | location | use when |
|---|---|---|---|
| `TeamThemeScope` | 팀 테마 토큰을 하위 트리에 주입하는 테마 전환 지점 | `lib/ui/shared/team_theme_scope.dart` | 구장/팀 맥락 화면 전체 |
| `DdayHeader` | 다음 원정 경기 D-day와 경기 정보 헤더 (기본 얼굴) | `lib/ui/shared/dday_header.dart` | 홈 화면 상단 |
| `PlaceCard` | 추천 장소 카드 (샤라웃 출처 뱃지 포함) | `lib/ui/shared/place_card.dart` | 추천 목록·미리보기 어디든 |
| `ScratchCard` | "오늘 뭐하지?" 긁기 랜덤 추천 카드 | `lib/ui/shared/scratch_card.dart` | 추천 목록의 마지막 항목 |
| `StadiumMapView` | flutter_naver_map 래퍼 — 마커·모션·길안내 딥링크를 한곳에 | `lib/ui/shared/stadium_map_view.dart` | 앱 내 모든 지도 표시 |
| `PlaceDetailSheet` | 장소 상세 바텀시트 (지도 진입·OS 공유 진입점) | `lib/ui/shared/place_detail_sheet.dart` | 장소 카드 탭 시 |
| `CategoryChip` | 맛집/방탈출/카페 등 카테고리 필터 칩 | `lib/ui/shared/category_chip.dart` | 추천 목록 필터 |
| `WeatherBackdrop` | 날씨 연동 배경 연출 (비 애니메이션 → 플랜B 유도) | `lib/ui/shared/weather_backdrop.dart` | 홈·추천 화면 배경 |
| `StadiumPicker` | 구장 골라 구경하기 진입 (탐색 모드) | `lib/ui/shared/stadium_picker.dart` | 경기 없는 날·탐색 진입 |

### Backend common layers
서버가 없으므로 이 영역은 **콘텐츠 파이프라인**(`content-pipeline/` + `content-pipeline/REGISTRY.md`)으로 대체한다.

> 규칙: 모든 크롤러·빌드 스크립트는 공통 레이어를 통과한다. 스크립트마다 fetch/검증/로그를 새로 만들지 않는다.

| name | purpose (one line) | location | use when |
|---|---|---|---|
| Fetch 공통 | HTTP 요청·재시도·타임아웃·User-Agent 한곳 | `content-pipeline/common/fetch.*` | 모든 외부 요청 |
| 스키마 검증 | 산출 JSON이 계약(스키마 버전 포함)을 지키는지 빌드 시 검증 | `content-pipeline/common/validate.*` | 모든 JSON 산출 직전 |
| 로깅 | 크롤 성공/실패 구조화 로그 | `content-pipeline/common/log.*` | 모든 스크립트 |
| 배포 스텝 | 검증 통과한 JSON을 호스팅으로 올리는 단일 경로 | `content-pipeline/deploy.*` + CI cron | 모든 콘텐츠 갱신 |

### DB schema
DB 서버가 없으므로 **콘텐츠 JSON 계약 + 앱 로컬 저장**이 스키마다. 계약 변경은 마이그레이션급(L)으로 취급: `schemaVersion` 필드를 올리고 앱의 하위 호환을 확인한다.

**계약 정의 위치:** `content-pipeline/schema/` (JSON Schema 파일이 원본)

| entity | purpose (one line) | defined in | ownership notes |
|---|---|---|---|
| `teams.json` | 팀 10개 — id, 이름, 테마 키 | `content-pipeline/schema/teams.schema.json` | 파이프라인 소유, 앱은 읽기만 |
| `stadiums.json` | 구장 9곳 — 안정적 id, 좌표, 홈팀 목록 | `content-pipeline/schema/stadiums.schema.json` | 파이프라인 소유; id는 스탬프 대비 불변 |
| `places.json` | 추천 장소 — 구장 id, 카테고리, 실내 여부, 샤라웃 출처, source("curated") | `content-pipeline/schema/places.schema.json` | 파이프라인 소유; source 필드는 UGC 문 |
| `schedule.json` | 경기 일정 + 상태(예정/취소/우천취소) | `content-pipeline/schema/schedule.schema.json` | 파이프라인 소유; 경기일 고빈도 갱신 |
| 로컬 prefs | 선택한 응원 팀, 콘텐츠 캐시 | 앱 로컬 저장소 (구현 재량) | 앱 소유; 서버 전송 없음 |

## Implementer discretion
아래는 **의도적으로** 정하지 않는다. 구현자가 그 자리에서 결정하고, 허락을 기다리지 않는다.
- 상태 관리 라이브러리(Riverpod/Bloc 등)와 앱 폴더 구조 세부
- 카드 긁기 연출의 구현 방식(CustomPainter/shader 등)과 세부 커브 값
- 로컬 저장 방식(shared_preferences/hive 등)과 캐시 만료 정책 세부
- 콘텐츠 JSON 호스팅 위치(GitHub Pages/CDN 등 — 앱에는 URL 상수 하나)
- 크롤러 구현 언어와 파싱 세부
- 날씨 래퍼 내부 구조, 화면별 문구·카피 톤 세부
- 각 화면의 내부 위젯 분해와 비공유 화면 전용 위젯

## Enforcement plan
- `check-hardcoded-values.sh` — Dart용으로 각색: `lib/**/*.dart`에서 `Color(0x...)`·raw 치수 리터럴을 잡되 `lib/design/`은 제외. **PostToolUse 훅 + pre-commit 양쪽**에 wiring.
- `check-registry-sync.sh` — `lib/ui/shared/` ↔ `lib/ui/shared/REGISTRY.md`, `content-pipeline/common/` ↔ `content-pipeline/REGISTRY.md` 짝으로 각색. **pre-commit**에 wiring (PostToolUse는 파일 추가 시점마다 소음이 커서 제외).
- 설치 자체는 wellplan phase 1의 단계로 수행한다.
