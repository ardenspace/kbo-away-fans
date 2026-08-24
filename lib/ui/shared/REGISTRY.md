# Shared components registry — `lib/ui/shared/`

> 규칙: 두 군데 이상에서 렌더되면 여기 먼저. 로스터에 없는데 공유 성격이면
> 이 폴더에 만들고 **같은 커밋에서** 아래 표에 행을 추가한다.
> 전체 로스터(예정 목록)는 `.wellbegun/spec.md`의 Shared components 절 참조.
>
> 형식 규약: location 열에 저장소 기준 경로를 백틱으로 감싸 적는다
> (`scripts/hooks/check-registry-sync.sh`가 이 폴더의 파일과 표의 경로를 대조).

| name | purpose (one line) | location | use when |
|---|---|---|---|
| `TeamThemeScope` | 팀 테마 토큰을 하위 트리에 주입하는 테마 전환 지점 | `lib/ui/shared/team_theme_scope.dart` | 구장/팀 맥락 화면 전체 |
| `DdayHeader` | 다음 원정 경기 헤더 (기본 얼굴) — 오늘/D-day/빈 상태(`.empty`) 세 상태 렌더 | `lib/ui/shared/dday_header.dart` | 홈 화면 상단 |
| `PlaceCard` | 추천 장소 카드 (샤라웃 출처 뱃지 포함) | `lib/ui/shared/place_card.dart` | 추천 목록·미리보기 어디든 |
| `ScratchCard` | "오늘 뭐하지?" 긁기 카드 — 긁기 진행이 임계에 닿으면 숨김 내용(hiddenLabel/hiddenSublabel) 공개, onRescratch 로 재긁기 지원 | `lib/ui/shared/scratch_card.dart` | 추천 목록의 마지막 항목 |
| `StadiumMapView` | flutter_naver_map 래퍼 — 마커·모션·길안내 딥링크를 한곳에 | `lib/ui/shared/stadium_map_view.dart` | 앱 내 모든 지도 표시 |
| `PlaceDetailSheet` | 장소 상세 바텀시트 (지도 진입·OS 공유 진입점) | `lib/ui/shared/place_detail_sheet.dart` | 장소 카드 탭 시 |
| `CategoryChip` | 맛집/방탈출/카페 등 카테고리 필터 칩 | `lib/ui/shared/category_chip.dart` | 추천 목록 필터 |
| `kCategoryLabels` | places category enum ↔ 한국어 문구의 단일 매핑 (+ `categoryLabelOf`) | `lib/ui/shared/category_labels.dart` | 카테고리 문구가 필요한 모든 곳 |
| `WeatherBackdrop` | 날씨 연동 배경 연출 (비 애니메이션 → 플랜B 유도) | `lib/ui/shared/weather_backdrop.dart` | 홈·추천 화면 배경 |
| `StadiumPicker` | 구장 골라 구경하기 진입 (탐색 모드) | `lib/ui/shared/stadium_picker.dart` | 경기 없는 날·탐색 진입 |
