---
status: approved
cycle: 2
---

# kbo-away-fans — spec (사이클 2)

<!--
  델타 spec. 사이클 1의 spec 은 `cycles/01/spec.md` 에 있고, 레지스트리는 이미
  코드로 존재한다. 이 문서는 **이번 사이클이 더하거나 바꾸는 몫만** 적는다.
  입력: `.wellbegun/begin.md` (승인됨), `.wellbegun/audit.md`, `cycles/01/spec.md`
-->

## Resolved decisions
<!-- S로 내려간 항목은 표에 없고 Implementer discretion 에 있다 -->
| decision | grade | choice | ADR |
|---|---|---|---|
| 사용자 데이터 백엔드 도입 형태 | XL | Firebase Authentication + Cloud Firestore, 자체 운영 서버 없음. 콘텐츠는 기존 정적 JSON 파이프라인 유지 | see decisions.md 2026-09-01 |
| 소셜 로그인 세 제공자를 붙이는 방식 | L | 구글·애플은 Firebase Auth 기본 제공자, 카카오는 Cloud Functions 가 커스텀 토큰 발급 | see decisions.md 2026-09-01 |
| 구장 방문 확인 방식 (스탬프 인증) | L | 포그라운드 판정 — 경기일 + 구장 반경 + 시간 창 세 조건 | see decisions.md 2026-09-01 |
| 도장 중복 방지 (오프라인 포함) | L | 도장 문서 id 를 `{stadiumId}_{gameId}` 결정적 조합으로 두어 쓰기가 멱등 | see decisions.md 2026-09-01 |
| 최근 5경기 결과 데이터 범위 | L | 점수·승패·구장·날짜까지. 선발 투수·날씨는 제외, schedule 계약 schemaVersion 2 | see decisions.md 2026-09-01 |
| 위치 권한 요청 시점 | M | 온보딩 팀 선택 직후, 용도 설명과 함께. 거절해도 나머지 기능은 동작 | see decisions.md 2026-09-01 |
| 하단 5탭 구조 전환 방식 | M | 라우터 패키지 없이 BottomNavigationBar + IndexedStack + 탭별 Navigator | see decisions.md 2026-09-01 |
| 기기 저장값과 계정의 관계 | M | 선택 팀의 원본은 Firestore, shared_preferences 는 첫 렌더용 캐시로만 | see decisions.md 2026-09-01 |

## Registries
<!-- 델타 모드: **확장분만** 적는다. 기존 로스터는 `lib/ui/shared/REGISTRY.md`,
     `content-pipeline/REGISTRY.md`, `cycles/01/spec.md` 를 그대로 유지한다. -->

### Design tokens
**추가 위치:** `lib/design/tokens.dart` (기존 파일에 그룹 추가)

| name | purpose (one line) | location | use when |
|---|---|---|---|
| `text.*` | 폰트·크기·굵기·색을 묶은 **이름 있는 조합 스타일** (승격 후보 3) | `lib/design/tokens.dart` | 모든 텍스트 — 낱개 토큰 조합을 손으로 다시 쓰지 않는다 |
| `badge.*` | 배지 판 수치 — 칸 크기·간격, 빈 칸 투명도, 등급 표시 크기 | `lib/design/tokens.dart` | 배지 판과 도장 렌더 |
| `badgeTier.*` | 등급별 표현 값 (기본/중간/최고) — 팀 색 위에 얹는 등급 액센트 | `lib/design/tokens.dart` | 등급이 있는 도장 |
| `motion.stamp` | 도장이 찍히는 순간의 지속·커브 (`MotionTokens` 확장) | `lib/design/tokens.dart` | 도장 획득 연출 — begin 이 지목한 이 사이클의 대표 연출 |

> `text.*` 는 감사의 승격 후보 3(13개 파일 38회 반복)을 받는다. 기존 38곳도 같은
> 사이클에서 전부 교체한다 — 새 화면만 쓰고 기존을 남기면 두 방식이 공존해 훅으로
> 강제할 수 없다.

### Shared components
**추가 위치:** `lib/ui/shared/` (기존 폴더, 같은 커밋에 `REGISTRY.md` 행 추가)

| name | purpose (one line) | location | use when |
|---|---|---|---|
| `ContentFallback` | 로딩 스피너 / 실패 안내 + 재시도 버튼의 단일 구현 (승격 후보 1) | `lib/ui/shared/content_fallback.dart` | 콘텐츠·사용자 데이터를 못 얻은 모든 화면 |
| `TeamThemedAppBar` | 팀 테마에서 배경·전경색을 꺼내 오는 앱바 (승격 후보 2) | `lib/ui/shared/team_themed_app_bar.dart` | 팀 맥락이 있는 모든 화면 상단 |
| `MainTabScaffold` | 하단 5탭 골격 — 탭별 Navigator 스택 유지 | `lib/ui/shared/main_tab_scaffold.dart` | 로그인 이후 앱의 최상위 골격 |
| `StampBoard` | 10칸 배지 판 — 빈 칸까지 전부 렌더 | `lib/ui/shared/stamp_board.dart` | 배지 탭, 그리고 판을 요약해 보여줄 곳 |
| `StampBadge` | 칸 하나 — 빈 상태·획득·등급 세 모습 | `lib/ui/shared/stamp_badge.dart` | 판 안, 도장 획득 연출, 칸 상세 |
| `LikeButton` | 좋아요 토글 (낙관적 반영 + 실패 시 되돌림) | `lib/ui/shared/like_button.dart` | 장소 카드·상세 시트 등 좋아요가 붙는 모든 곳 |
| `SocialSignInButton` | 제공자별 로그인 버튼 (구글·카카오·애플) 한 모양 | `lib/ui/shared/social_sign_in_button.dart` | 로그인 화면 |

### Backend common layers
이 사이클에서 이 영역이 **둘로 갈린다.** 기존 콘텐츠 파이프라인은 그대로 두고,
사용자 데이터용 계층이 새로 생긴다.

**새 위치:** `lib/backend/` (+ `lib/backend/REGISTRY.md`, `lib/backend/CLAUDE.md`)

> 규칙: Firebase SDK import 는 이 폴더 안에만 둔다. 화면은 이 계층의 타입만
> 소비한다 (사이클 1이 `StadiumMapView`·`analytics`·`weather` 에 쓴 경계와 같은 규칙).

| name | purpose (one line) | location | use when |
|---|---|---|---|
| 인증 공통 | 세 제공자 로그인·로그아웃·세션 상태를 한 타입 뒤로 | `lib/backend/auth.dart` | 로그인 게이트, 마이페이지 |
| 사용자 데이터 접근 | 사용자 문서·도장·좋아요 읽기/쓰기의 단일 경로 | `lib/backend/user_data.dart` | 배지·좋아요·프로필을 다루는 모든 곳 |
| 오류 봉투 | Firebase 예외를 앱 도메인 오류(네트워크/권한/알수없음)로 변환 | `lib/backend/errors.dart` | 백엔드 호출의 모든 실패 경로 |
| 카카오 커스텀 토큰 함수 | 카카오 액세스 토큰 검증 → Firebase 커스텀 토큰 발급 | `functions/` (Cloud Functions) | 카카오 로그인 |

**기존 파이프라인 확장분** (`content-pipeline/`)

| name | purpose (one line) | location | use when |
|---|---|---|---|
| 과거 경기 크롤 창 | 크롤 범위를 과거로 넓혀 최근 경기 결과를 산출물에 남김 | `content-pipeline/crawl-schedule.mjs` | 최근 5경기 요약의 데이터 원천 |

### DB schema
사용자 데이터는 **Firestore**, 콘텐츠는 기존 **JSON 계약** — 둘 다 계약 변경은
마이그레이션급(L)으로 다룬다.

**Firestore (새로 생김)** — 규칙: 모든 문서는 본인만 읽고 쓴다.

| entity | purpose (one line) | path | ownership notes |
|---|---|---|---|
| 사용자 | 닉네임, 프로필 색(팀 테마 키), 선택 팀, 가입 시각 | `users/{uid}` | 본인 소유. 선택 팀의 원본이 여기로 옮겨온다 |
| 도장 | 구장, 찍힌 팀 색, 경기 id, 날짜 | `users/{uid}/stamps/{stadiumId}_{gameId}` | 본인 소유. id 가 결정적이라 쓰기가 멱등 |
| 좋아요 | 장소 id, 구장 id, 카테고리, 누른 시각 | `users/{uid}/likes/{placeId}` | 본인 소유 |

> **위치 좌표 필드를 두지 않는다.** begin 의 데이터 소유권 결정("위치는 남기지
> 않는다")이 스키마 수준의 규칙이다. 구장 근처 판정은 기기에서 하고 결과만 올린다.

**JSON 계약 변경분**

| entity | 변경 | defined in | ownership notes |
|---|---|---|---|
| `schedule.json` | 점수·승패 필드 추가 + 과거 경기 포함 → `schemaVersion` 1 → **2** | `content-pipeline/schema/schedule.schema.json` | 마이그레이션급: 앱 파서 하위 호환 확인 필요 |

## Implementer discretion
아래는 **의도적으로** 정하지 않는다. 구현자가 그 자리에서 결정한다.
- 배지 등급이 갈리는 임계 개수와 등급 이름
- 구장 반경·시간 창의 구체적 수치(초기값을 잡고 실측으로 조정)
- 배지 판의 배치(격자/지도형)와 칸 상세 화면의 레이아웃
- Firestore 문서의 필드 이름과 인덱스 구성
- 로그인·권한 요청 화면의 문구와 카피 톤
- 좋아요 목록의 정렬과 카테고리 묶는 방식
- 탭 아이콘 선택, 탭 전환 연출 세부
- Cloud Functions 의 런타임·언어와 내부 구조
- `text.*` 조합 스타일의 정확한 항목 이름과 개수

## Enforcement plan
사이클 1의 두 검사를 유지하고 새 경계 두 개를 추가한다. 설치는 wellplan phase 1
의 단계로 수행한다.

- `check-hardcoded-values.sh` — 그대로 유지 (PostToolUse + pre-commit).
- `check-registry-sync.sh` — 짝을 하나 늘린다: `lib/backend/` ↔
  `lib/backend/REGISTRY.md`. 기존 두 짝은 그대로. (pre-commit)
- **`check-no-location-upload.sh` (신설)** — `lib/backend/` 안에서 위도·경도로
  읽히는 필드명(`lat`, `lng`, `latitude`, `longitude`, `coord`)이 서버로 올라가는
  자리에 나타나면 막는다. begin 의 "위치는 남기지 않는다"는 개인정보 약속을 사람의
  주의력이 아니라 검사로 지킨다. (PostToolUse + pre-commit)
- **`check-firebase-import-boundary.sh` (신설)** — `firebase_*` / `cloud_firestore`
  import 가 `lib/backend/` 와 `lib/analytics/` 밖에 나타나면 막는다. 사이클 1이
  지도 SDK·날씨에 세운 경계를 백엔드에도 같은 방식으로 강제한다. (pre-commit)
