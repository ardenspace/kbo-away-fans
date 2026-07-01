# task-012 brief — 맛집·플랜B 화면

- **왜**: 원정 구장 근처 맛집·플랜B(우천 대비 실내 코스)를 pick 근거·출처와 함께 보여준다.
  구장 가이드(task-011) 다음 실용 콘텐츠. (PLAN task-012, E8·T9)
- **무엇**: 별도 라우트 `/places/:stadiumId` — 탭 2개(맛집 | 플랜B). 구장 화면에서 진입.
  - 데이터: `restaurantsProvider(sid)` · `planbPlacesProvider(sid)` = autoDispose.family (on-demand).
  - 모델: `Restaurant`(name·pick_type·category·description·source_url) · `PlanbPlace`(name·category·description·source_url).
  - UI: `TabBar` 맛집|플랜B. 맛집 카드 = pick_type 배지(선수/팬/에디터 PICK) + 이름·카테고리·설명 + 출처 링크.
    플랜B 카드 = 이름·카테고리·설명 + 출처 링크. 출처 = `url_launcher` 외부 브라우저.
  - 진입: `stadium_screen.dart` 에 "주변 맛집·플랜B" 버튼 추가 → `/places/:sid`.
  - **딥링크 대비**: `?tab=planb` 로 플랜B 탭 바로 열기 (task-013 우천취소 유도가 씀).
  - **out (YAGNI)**: 지도·좌표(task-016), 우천취소 자동유도 흐름(task-013), 정렬·필터, 이미지.
- **완료조건(DoD)**:
  - ☐ `/places/:stadiumId` 진입 시 맛집|플랜B 탭이 뜨고 각 목록이 로드된다
  - ☐ 맛집 카드에 pick_type 배지(선수/팬/에디터 PICK, 색 구분) + 이름·카테고리·설명
  - ☐ 각 카드 "출처" 링크 탭 → source_url 외부 브라우저로 열림 (url_launcher)
  - ☐ 구장 화면(task-011)에서 "주변 맛집·플랜B" 버튼으로 진입
  - ☐ `?tab=planb` 쿼리로 플랜B 탭이 초기 선택됨 (task-013 딥링크 대비)
  - ☐ 로딩/에러+재시도/빈 목록 상태
  - ☐ `flutter analyze` 0 issues, 기존 `flutter test` 회귀 없음
- **영향파일**: `features/places/restaurant.dart`·`planb_place.dart`·`places_provider.dart`·`places_screen.dart`(신규),
  `router.dart`(`/places/:stadiumId` 라우트), `stadium_screen.dart`(진입 버튼), `pubspec.yaml`(url_launcher ✅ 추가됨).
  계약 변경 없음 — restaurants/planb_places 읽기만.
- **검증**: `cd app && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`
