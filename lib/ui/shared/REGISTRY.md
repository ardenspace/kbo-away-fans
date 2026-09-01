# Shared components registry — `lib/ui/shared/`

> 규칙: 두 군데 이상에서 렌더되면 여기 먼저. 로스터에 없는데 공유 성격이면
> 이 폴더에 만들고 **같은 커밋에서** 아래 표에 행을 추가한다.
> 전체 로스터(예정 목록)는 `.wellbegun/spec.md`의 Shared components 절 참조.
>
> 형식 규약: location 열에 저장소 기준 경로를 백틱으로 감싸 적는다
> (`scripts/hooks/check-registry-sync.sh`가 이 폴더의 파일과 표의 경로를 대조).

| name | purpose (one line) | location | use when |
|---|---|---|---|
| `TeamThemeScope` | 팀 테마 토큰을 하위 트리에 주입하는 테마 전환 지점 — 같은 자리에서 팀이 바뀌면 네 색을 `MotionTokens.themeShift` 동안 보간, 정지 상태에서는 목표 테마 인스턴스를 그대로 전달 | `lib/ui/shared/team_theme_scope.dart` | 구장/팀 맥락 화면 전체 |
| `DdayHeader` | 다음 원정 경기 헤더 (기본 얼굴) — 오늘/D-day/빈 상태(`.empty`) 세 상태 렌더 | `lib/ui/shared/dday_header.dart` | 홈 화면 상단 |
| `PlaceCard` | 추천 장소 카드 (샤라웃 출처 뱃지 포함) | `lib/ui/shared/place_card.dart` | 추천 목록·미리보기 어디든 |
| `ScratchCard` | "오늘 뭐하지?" 긁기 카드 — 긁기 진행이 임계에 닿으면 숨김 내용(hiddenLabel/hiddenSublabel) 공개, onRescratch 로 재긁기 지원 | `lib/ui/shared/scratch_card.dart` | 추천 목록의 마지막 항목 |
| `StadiumMapView` | flutter_naver_map 래퍼 — SDK 코드(import 포함)는 이 파일 안에만, 마커는 `StadiumMapMarker` 값 객체로 받고 키 미주입 시 자리 표시 폴백 | `lib/ui/shared/stadium_map_view.dart` | 앱 내 모든 지도 표시 |
| `map_links` | 네이버지도 길안내 딥링크(nmap://)·웹 폴백·장소 링크·공유 페이로드 빌더 + `launchNaverMapRoute` (SDK 무관) | `lib/ui/shared/map_links.dart` | 지도 링크·길안내·공유 문구가 필요한 모든 곳 |
| `PlaceDetailSheet` | 장소 상세 바텀시트 (지도 진입·길안내·OS 공유 진입점) | `lib/ui/shared/place_detail_sheet.dart` | 장소 카드 탭 시 |
| `CategoryChip` | 맛집/방탈출/카페 등 카테고리 필터 칩 | `lib/ui/shared/category_chip.dart` | 추천 목록 필터 |
| `kCategoryLabels` | places category enum ↔ 한국어 문구의 단일 매핑 (+ `categoryLabelOf`) | `lib/ui/shared/category_labels.dart` | 카테고리 문구가 필요한 모든 곳 |
| `WeatherBackdrop` | 날씨 연동 배경 연출 — 비 상태면 배경 오버레이 + 빗줄기 레이어(`RainLayer`), bool 주입이라 날씨 계층과 비결합 | `lib/ui/shared/weather_backdrop.dart` | 홈·추천 화면 배경 |
| `StadiumPicker` | 구장 골라 구경하기 진입 (탐색 모드) | `lib/ui/shared/stadium_picker.dart` | 경기 없는 날·탐색 진입 |
| `TeamBadge` | 팀 표시 — 약칭 글자 + 대표색 몸통 + 좌측 보조색 탭 (엠블럼·마스코트 대체), 좁은 자리는 `compact` | `lib/ui/shared/team_badge.dart` | 팀을 가리켜야 하는 모든 곳 |
| `ContentFallback` | 로딩 스피너 / 실패 안내 + 재시도 버튼의 단일 구현 — `onRetry` 가 없으면 버튼 자체를 두지 않는다 | `lib/ui/shared/content_fallback.dart` | 콘텐츠·사용자 데이터를 못 얻은 모든 화면 |
| `TeamThemedAppBar` | 팀 테마에서 배경·전경색을 꺼내 오는 앱바 (`maybeOf` 폴백 — 팀 맥락이 없으면 팔레트 기본색) | `lib/ui/shared/team_themed_app_bar.dart` | 팀 맥락이 있는 모든 화면 상단 |
| `MainTabScaffold` | 하단 탭 골격 — `IndexedStack` + 탭별 `Navigator`(`MainTab` 으로 탭을 받고, 같은 탭 재탭은 뿌리로, 뒤로가기는 보고 있는 탭부터) | `lib/ui/shared/main_tab_scaffold.dart` | 로그인 이후 앱의 최상위 골격 |
| `StampBoard` | 10칸 배지 판 — `kBoardCellIds` 를 훑어 빈 칸까지 전부 격자로 렌더, 사용자 문서의 칸별 요약(`board` map) 하나만 읽는다 | `lib/ui/shared/stamp_board.dart` | 배지 탭, 그리고 판을 요약해 보여줄 곳 |
| `StampBadge` | 칸 하나 — 빈 상태·획득·등급 세 모습(도장 개수 하나로 갈린다). 등급 링은 `BadgeTierTokens` 값을 `BadgeTierRingPainter` 가 그대로 그린다 | `lib/ui/shared/stamp_badge.dart` | 판 안, 도장 획득 연출, 칸 상세 |
| `LikeButton` | 좋아요 토글 — 낙관적 반영 + 실패 시 되돌림 + `onFailed` 통지, 응답 대기 중 연타 무시 | `lib/ui/shared/like_button.dart` | 장소 카드·상세 시트 등 좋아요가 붙는 모든 곳 |
| `SocialSignInButton` | 제공자별 로그인 버튼 (구글·카카오·애플) 한 모양 — 몸통은 팔레트 한 벌이고 아이콘·문구가 제공자를 가르며, 진행 중(`busy`)이면 아이콘 자리가 스피너가 된다 | `lib/ui/shared/social_sign_in_button.dart` | 로그인 화면 |
