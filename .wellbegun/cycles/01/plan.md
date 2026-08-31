---
status: approved
cycle: 1
---

# kbo-away-fans — plan

## Phases
| phase | delivers | steps |
|---|---|---|
| 1 | 기반 + 강제 장치 (토큰·계약·공유 컴포넌트·파이프라인 공통·훅) | 1.1–1.6 |
| 2 | 첫 여정 슬라이스: 앱을 켜고 팀을 고르면 D-day 홈이 보인다 | 2.1–2.3 |
| 3 | 핵심 여정: 경기 당일 추천 목록 → 카드 긁기 → 앱 내 지도 | 3.1–3.4 |
| 4 | 실패 분기와 연출: 날씨 연동, 우천 플랜B, 구장 탐색 | 4.1–4.3 |
| 5 | 실데이터: 일정 크롤러, 콘텐츠 시드, 호스팅·배포 | 5.1–5.3 |

## Step contracts

### Step 1.1: Flutter 앱 스캐폴드
1. **Goal:** git 저장소 초기화와 Flutter 프로젝트 생성, 폴더 구조(lib/design, lib/ui/shared, lib/features, content-pipeline/)와 lint 기준선을 세운다.
2. **Acceptance criteria:** `flutter analyze` 경고 0으로 통과한다. `flutter test`가 통과한다. spec의 폴더 구조가 실제로 존재한다. git 첫 커밋이 있다.
3. **Boundary tests:** `flutter analyze` exit 0; `flutter test` exit 0; `test/smoke_test.dart`(앱 루트 위젯이 렌더된다) 통과; `ls lib/design lib/ui/shared content-pipeline` 성공.
4. **Registries to read:** spec.md의 4개 레지스트리 로스터 전부(구조의 원본).
5. **Verification tier:** fresh
6. **Discretion scope:** 상태 관리 라이브러리 선택, 폴더 구조 세부, lint 규칙 세부.

### Step 1.2: 콘텐츠 JSON 계약 + 검증기
1. **Goal:** teams/stadiums/places/schedule 4개 JSON Schema(schemaVersion 포함)와 샘플 데이터, 빌드 시 검증 스크립트를 만든다.
2. **Acceptance criteria:** 4개 스키마 파일이 `content-pipeline/schema/`에 존재한다. 샘플 데이터가 검증을 통과한다. 계약 필수 필드(구장 안정 id, places.source="curated", 경기 상태 enum(scheduled/canceled/rain_canceled), schemaVersion)가 스키마에 있다. 깨진 샘플은 검증이 실패시킨다.
3. **Boundary tests:** `content-pipeline` 검증 명령이 정상 샘플에 exit 0; 필수 필드를 뺀 픽스처에 exit 비0; 알 수 없는 경기 상태 값 픽스처에 exit 비0; schemaVersion 불일치 픽스처에 exit 비0.
4. **Registries to read:** DB schema 레지스트리(spec.md).
5. **Verification tier:** fresh
6. **Discretion scope:** 검증 스크립트 구현 언어, 스키마 파일 분할 방식, 샘플 데이터 내용.

### Step 1.3: 디자인 토큰 파일
1. **Goal:** `lib/design/tokens.dart`(color/space/radius/type/motion)와 `lib/design/team_themes.dart`(10팀 테마)를 실제 코드로 만든다.
2. **Acceptance criteria:** 토큰 그룹 5종이 이름 있는 상수로 존재한다. 10개 팀 각각 primary/secondary/on-color를 가진 테마가 있다. motion 토큰에 탄성 커브 기본값이 있다. lib/design/ 밖의 어떤 파일에도 raw hex가 없다.
3. **Boundary tests:** `test/design/tokens_test.dart` — 10팀 테마가 모두 존재하고 팀 id로 조회된다; 토큰 그룹 5종이 비어 있지 않다; `bash scripts/hooks/check-hardcoded-values.sh` exit 0.
4. **Registries to read:** Design tokens 레지스트리(spec.md).
5. **Verification tier:** fresh
6. **Discretion scope:** 구체 색·수치의 초기값(추후 디자인 단계에서 조정 가능), 토큰 상수의 코드 표현 방식.

### Step 1.4: 공유 컴포넌트 뼈대 9종 + 로스터
1. **Goal:** spec의 공유 컴포넌트 9종을 골격(스켈레탈)으로 구현하고 `lib/ui/shared/REGISTRY.md`를 코드 옆에 둔다.
2. **Acceptance criteria:** 9개 컴포넌트 파일이 존재하고 각각 최소 props로 렌더된다. 모든 색·간격이 토큰을 쓴다. REGISTRY.md의 행과 폴더의 파일이 일치한다.
3. **Boundary tests:** `test/ui/shared/` 위젯 스모크 테스트 9건(각 컴포넌트가 예외 없이 렌더) 통과; `bash scripts/hooks/check-registry-sync.sh` exit 0; `bash scripts/hooks/check-hardcoded-values.sh` exit 0.
4. **Registries to read:** Shared components + Design tokens 레지스트리.
5. **Verification tier:** fresh
6. **Discretion scope:** 각 컴포넌트 내부 위젯 분해, 골격 단계의 props 세부.

### Step 1.5: 콘텐츠 파이프라인 공통 레이어
1. **Goal:** `content-pipeline/common/`에 fetch(재시도·타임아웃)/validate/log 공통과 deploy 스텁을 만들고 `content-pipeline/REGISTRY.md`를 둔다.
2. **Acceptance criteria:** 공통 4종이 존재하고 단위 테스트가 있다. validate는 1.2의 스키마를 사용한다. REGISTRY.md와 폴더가 일치한다.
3. **Boundary tests:** 파이프라인 단위 테스트(fetch 재시도 동작, validate가 1.2 픽스처를 동일 판정) 통과; `bash scripts/hooks/check-registry-sync.sh` exit 0.
4. **Registries to read:** Backend common(콘텐츠 파이프라인) + DB schema 레지스트리.
5. **Verification tier:** fresh
6. **Discretion scope:** 파이프라인 구현 언어, 로그 포맷 세부, 재시도 정책 수치.

### Step 1.6: 강제 훅 설치 + read-first 문서
1. **Goal:** check-hardcoded-values(Dart 각색)와 check-registry-sync를 `scripts/hooks/`에 두고 PostToolUse(.claude/settings.json)와 pre-commit에 wiring하며, 각 영역 CLAUDE.md에 "작업 전 로스터를 읽어라"를 명시한다.
2. **Acceptance criteria:** 깨끗한 트리에서 두 스크립트 모두 exit 0. 위반을 일부러 만들면 stderr 출력과 함께 exit 2. pre-commit이 위반 커밋을 막는다. lib/ui/shared/와 content-pipeline/에 read-first CLAUDE.md가 있다.
3. **Boundary tests:** 깨끗한 트리에서 두 스크립트 exit 0; `lib/features/`에 raw hex 파일을 임시 추가 → check-hardcoded-values exit 2 확인 후 제거; 로스터에 없는 파일을 lib/ui/shared/에 임시 추가 → check-registry-sync exit 2 확인 후 제거; 위반 상태에서 `git commit` 실패.
4. **Registries to read:** 4개 레지스트리 전부(동기화 대상 파악).
5. **Verification tier:** basic
6. **Discretion scope:** 스크립트 내부 grep 패턴 세부, 예외 목록 관리 방식.

### Step 2.1: 콘텐츠 로더 + 로컬 캐시
1. **Goal:** 앱이 원격 JSON 4종을 받아 schemaVersion을 확인하고 로컬에 캐시하며, 네트워크 실패 시 캐시로 동작하게 한다.
2. **Acceptance criteria:** URL 상수 하나만 바꾸면 소스가 바뀐다. 첫 로드 성공, 오프라인 재실행 시 캐시 사용, 미지원 schemaVersion이면 캐시 유지 + 갱신 거부가 관찰된다.
3. **Boundary tests:** 로더 단위 테스트 — 정상 응답 파싱; HTTP 실패 시 캐시 폴백; 캐시 없음+실패 시 명시적 에러 상태; schemaVersion 불일치 시 기존 캐시 유지; 계약 위반 JSON 거부.
4. **Registries to read:** DB schema 레지스트리, content-pipeline REGISTRY.
5. **Verification tier:** fresh
6. **Discretion scope:** 로컬 저장 방식(hive/shared_preferences 등), 캐시 만료 정책 세부.

### Step 2.2: 팀 선택 온보딩
1. **Goal:** 최초 실행 시 10팀 중 응원 팀을 고르고 기기에 저장하며, 선택 즉시 TeamThemeScope로 팀 테마가 적용되게 한다.
2. **Acceptance criteria:** 첫 실행에만 온보딩이 뜬다. 선택 후 재실행하면 온보딩 없이 홈으로 간다. 팀을 바꾸면(설정 진입점) 테마가 즉시 전환된다.
3. **Boundary tests:** 위젯 테스트 — 10팀이 모두 렌더; 선택 → 저장 값 확인; 저장 존재 시 온보딩 스킵; 팀 변경 시 primary 색이 해당 팀 토큰과 일치.
4. **Registries to read:** Shared components + Design tokens 레지스트리.
5. **Verification tier:** basic
6. **Discretion scope:** 온보딩 화면 연출·문구, 팀 변경 진입점 위치.

### Step 2.3: 홈 화면 — D-day 기본 얼굴
1. **Goal:** 선택 팀의 다음 원정 경기를 schedule에서 계산해 DdayHeader로 보여주고, 경기 없는 날에도 다음 원정 미리보기가 뜨는 기본 얼굴을 만든다.
2. **Acceptance criteria:** 오늘 원정 경기가 있으면 "오늘" 상태, 없으면 다음 원정 D-day가 뜬다. 남은 일정이 없으면(시즌 종료) 명시적 빈 상태가 뜬다. 홈팀 기준으로 구장 테마 색이 적용된다.
3. **Boundary tests:** 단위 테스트 — 오늘 경기 픽스처 → "오늘"; 미래 경기 픽스처 → 올바른 D-day 수; 일정 소진 픽스처 → 빈 상태; 잠실 경기 픽스처 → 홈팀 기준 테마 선택. 위젯 테스트 — DdayHeader가 세 상태 모두 렌더.
4. **Registries to read:** Shared components + Design tokens + DB schema 레지스트리.
5. **Verification tier:** basic
6. **Discretion scope:** 홈 레이아웃 세부, 미리보기에 보일 장소 개수, 문구.

### Step 3.1: 구장 주변 추천 목록
1. **Goal:** 경기 구장의 places를 카테고리 칩(맛집/카페/놀거리 등)과 실내 필터로 보여주는 추천 목록을 만든다. 샤라웃 맛집은 출처 뱃지로 구분한다.
2. **Acceptance criteria:** 구장 id로 장소가 필터된다. 칩 선택이 목록에 즉시 반영된다. 샤라웃 장소에 출처 뱃지가 보인다. 장소 0건 카테고리는 명시적 빈 상태가 뜬다.
3. **Boundary tests:** 단위 테스트 — 구장 id 필터 정확성; 카테고리+실내 조합 필터; 빈 결과 상태. 위젯 테스트 — PlaceCard에 뱃지 렌더; 칩 탭 → 목록 갱신.
4. **Registries to read:** Shared components + DB schema 레지스트리.
5. **Verification tier:** basic
6. **Discretion scope:** 정렬 기준, 카드 정보 밀도, 빈 상태 문구.

### Step 3.2: "오늘 뭐하지?" 카드 긁기
1. **Goal:** 추천 목록의 마지막 항목으로 ScratchCard를 넣어, 긁으면 현재 필터 조건 안에서 랜덤 장소가 드러나게 한다.
2. **Acceptance criteria:** 긁기 진행에 따라 장소가 드러난다. 같은 카드에서 다시 긁으면 다른 장소가 나올 수 있다(현재 필터 풀 안에서). 풀이 비어 있으면 카드가 숨겨진다.
3. **Boundary tests:** 단위 테스트 — 랜덤 선택이 현재 필터 풀 안에서만 나옴; 빈 풀 → 카드 비노출. 위젯 테스트 — 긁기 제스처 시뮬레이션 후 장소 정보가 드러남; motion 토큰 사용 확인(raw 수치 검사 훅 통과로 갈음).
4. **Registries to read:** Shared components + Design tokens 레지스트리.
5. **Verification tier:** basic
6. **Discretion scope:** 긁기 구현 방식(CustomPainter/shader), 연출 세부, 재긁기 정책.

### Step 3.3: 장소 상세 + 앱 내 지도
1. **Goal:** PlaceCard 탭 → PlaceDetailSheet → StadiumMapView(네이버 지도)로 이어지는 흐름과, 외부 길안내 딥링크·OS 공유를 만든다.
2. **Acceptance criteria:** 시트에서 지도 진입 시 앱 내 지도에 구장·장소 마커가 뜬다. "길안내" 탭이 네이버지도 앱/웹 딥링크로 나간다. OS 공유 시트에 장소 이름+지도 링크가 담긴다. 지도 SDK 코드는 StadiumMapView 래퍼 안에만 존재한다.
3. **Boundary tests:** `grep`으로 flutter_naver_map import가 stadium_map_view.dart 밖에 없음을 확인; 딥링크 URL 생성 단위 테스트(좌표·이름 인코딩); 공유 페이로드 단위 테스트; 위젯 테스트 — 카드 탭 → 시트 노출(지도는 mock 래퍼).
4. **Registries to read:** Shared components + Design tokens 레지스트리; decisions.md의 지도 L 결정.
5. **Verification tier:** fresh
6. **Discretion scope:** 시트 레이아웃, 마커 모션 세부, 지도 초기 줌 수치.

### Step 3.4: 분석 이벤트
1. **Goal:** Firebase Analytics를 붙이고 place_tap, map_open 익명 이벤트를 심어 성공 지표를 계측한다.
2. **Acceptance criteria:** 두 이벤트가 각 상호작용에서 정확히 1회 발생한다. 이벤트 파라미터에 개인 식별 정보가 없다(구장 id·카테고리만). 분석 호출은 래퍼 하나를 통과한다.
3. **Boundary tests:** mock 래퍼 단위 테스트 — 카드 탭 → place_tap 1회; 지도 진입 → map_open 1회; 파라미터 화이트리스트(허용 키 외 전송 시 테스트 실패).
4. **Registries to read:** Shared components 레지스트리.
5. **Verification tier:** basic
6. **Discretion scope:** 래퍼 구조, 추가 진단 이벤트 여부.

### Step 4.1: 날씨 연동 + 비 배경 연출
1. **Goal:** OpenWeatherMap 래퍼로 구장 좌표의 날씨를 받아 WeatherBackdrop이 비 오는 날 비 애니메이션을 틀게 한다.
2. **Acceptance criteria:** 비 상태에서 홈·추천 배경에 비 애니메이션이 뜬다. 날씨 API 실패 시 연출만 생략되고 여정은 정상 동작한다. 날씨 호출은 래퍼 하나를 통과한다.
3. **Boundary tests:** 래퍼 단위 테스트 — 응답 파싱, 실패 시 "연출 없음" 상태 반환(예외 전파 금지); 위젯 테스트 — 비 상태 주입 → 비 레이어 렌더, 맑음 주입 → 비 레이어 없음.
4. **Registries to read:** Shared components + Design tokens 레지스트리.
5. **Verification tier:** basic
6. **Discretion scope:** 비 애니메이션 구현 방식, 날씨 갱신 주기, 다른 날씨(눈 등) 연출 추가 여부.

### Step 4.2: 우천 취소 플랜B 분기
1. **Goal:** schedule의 경기 상태가 rain_canceled/canceled면 홈이 플랜B 모드로 바뀌어 실내 놀거리 중심 추천으로 유도되게 한다.
2. **Acceptance criteria:** 취소 상태 픽스처에서 홈에 플랜B 안내가 뜨고, 추천 목록이 실내 필터 켜진 상태로 열린다. 정상 경기에서는 아무 변화 없다. 비 연출(4.1)과 플랜B 유도가 함께 동작한다.
3. **Boundary tests:** 단위 테스트 — 상태별(scheduled/canceled/rain_canceled) 홈 모드 분기; 위젯 테스트 — rain_canceled 픽스처 → 플랜B 배너 렌더 + 목록 진입 시 실내 필터 활성.
4. **Registries to read:** Shared components + DB schema 레지스트리.
5. **Verification tier:** basic
6. **Discretion scope:** 플랜B 화면 구성·문구, 유도 연출 세부.

### Step 4.3: 구장 탐색 모드
1. **Goal:** StadiumPicker로 아무 구장이나 골라 그 구장 테마와 주변 추천을 구경할 수 있게 한다(경기 없는 날의 두 번째 진입점).
2. **Acceptance criteria:** 9개 구장이 모두 선택 가능하다. 선택 시 해당 구장 테마 색으로 전환되고 3.1의 추천 목록이 그 구장 기준으로 뜬다. 뒤로 가면 내 팀 홈으로 돌아온다.
3. **Boundary tests:** 위젯 테스트 — 9개 구장 렌더; 선택 → 추천 목록의 구장 id 일치; 잠실 선택 시 테마 결정 규칙(당일 홈팀, 경기 없으면 중립) 단위 테스트.
4. **Registries to read:** Shared components + Design tokens + DB schema 레지스트리.
5. **Verification tier:** basic
6. **Discretion scope:** 탐색 진입점 위치, 구장 목록 표현(지도/그리드).

### Step 5.1: KBO 일정 크롤러 + CI cron
1. **Goal:** 공개 웹에서 일정·경기 상태를 긁어 schedule.json을 만드는 크롤러를 파이프라인 공통 위에 구현하고, CI cron(평시 저빈도, 경기 시간대 15–30분)으로 돌린다.
2. **Acceptance criteria:** 크롤러 산출물이 1.2 스키마 검증을 통과한다. 파싱 실패 시 기존 schedule.json을 덮어쓰지 않고 실패 로그를 남긴다. cron 워크플로가 두 빈도로 정의돼 있다.
3. **Boundary tests:** 저장된 HTML 픽스처 → 파싱 결과 스냅샷 일치; 취소 표기 픽스처 → rain_canceled 매핑; 깨진 HTML 픽스처 → exit 비0 + 산출물 미변경; 산출물 validate exit 0.
4. **Registries to read:** content-pipeline REGISTRY + DB schema 레지스트리; decisions.md의 일정 L 결정.
5. **Verification tier:** fresh
6. **Discretion scope:** 크롤링 대상 사이트 선택과 파싱 세부, cron 정확 시각.

### Step 5.2: 콘텐츠 시드 — 구장·팀 전체 + 시범 구장 1곳 실데이터
1. **Goal:** teams(10)·stadiums(9) 실데이터를 확정 입력하고, 시범 구장 1곳의 places(샤라웃 맛집 + 실내 놀거리) 실데이터를 큐레이션 워크플로(입력 → 검증 → 병합)로 채운다.
2. **Acceptance criteria:** 전 팀·전 구장 데이터가 검증을 통과한다. 시범 구장에서 앱의 전체 여정(홈 → 추천 → 긁기 → 지도)이 실데이터로 걸어진다. 나머지 8개 구장 채우기는 동일 워크플로를 반복하는 운영 작업으로 문서화된다.
3. **Boundary tests:** validate exit 0; 시범 구장 places ≥ 10건, 카테고리 ≥ 3종, 실내 장소 ≥ 3건(플랜B 성립 조건); 좌표 유효 범위 검사; 앱 통합 테스트 — 시범 구장 픽스처로 홈→목록→상세 흐름 통과.
4. **Registries to read:** DB schema + content-pipeline REGISTRY.
5. **Verification tier:** basic
6. **Discretion scope:** 큐레이션 입력 형식(스프레드시트/CLI 등), 장소 설명 문구 톤.

### Step 5.3: 호스팅 + 배포 경로 연결
1. **Goal:** 검증 통과한 JSON을 정적 호스팅에 올리는 deploy 경로를 완성하고, 앱의 콘텐츠 URL을 실호스팅으로 연결해 실기기에서 전체 여정을 확인한다.
2. **Acceptance criteria:** deploy 한 번으로 4개 JSON이 호스팅에 올라간다. 검증 실패 시 배포가 중단된다. 실기기(iOS 또는 Android)에서 원격 콘텐츠로 핵심 여정이 완주된다.
3. **Boundary tests:** deploy 스크립트 — 정상 시 원격 URL에서 schemaVersion 일치 응답; 깨진 픽스처 주입 시 배포 중단 exit 비0; 앱 통합 테스트 — 실URL 대상 로더 성공(CI에서는 스테이징 URL).
4. **Registries to read:** content-pipeline REGISTRY + DB schema 레지스트리; decisions.md의 콘텐츠 구조 L 결정.
5. **Verification tier:** fresh
6. **Discretion scope:** 호스팅 위치(GitHub Pages/CDN 등), 배포 트리거 방식.

## Run preview
<!-- fresh 티어이거나 L/XL을 건드리는 step — 실행이 멈출 수 있는 지점 -->
| step | tier | touches |
|---|---|---|
| 1.1 | fresh | XL 프레임워크(Flutter) 기반 스캐폴드 |
| 1.2 | fresh | L 콘텐츠 JSON 계약 |
| 1.3 | fresh | 디자인 토큰 계약(전 화면 파급) |
| 1.4 | fresh | L급 공유 컴포넌트 API |
| 1.5 | fresh | L 콘텐츠 파이프라인 공통 계약 |
| 2.1 | fresh | L 콘텐츠 계약의 앱 쪽 소비 |
| 3.3 | fresh | L 지도 SDK(네이버) 통합 |
| 5.1 | fresh | L 일정 크롤링 파이프라인 |
| 5.3 | fresh | L 콘텐츠 배포 경로 |
