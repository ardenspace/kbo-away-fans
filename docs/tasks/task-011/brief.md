# task-011 brief — 구장 가이드 화면

- **왜**: 일정 카드(task-010) 탭 → `/stadium/:id` 가 지금 placeholder. 원정 가는 유저에게
  그 구장의 실용 정보(주차·좌석뷰·동선·편의점)를 보여준다. (PLAN task-011, E8·T9)
- **무엇**: `stadiums` 행을 id로 1회 조회해 헤더(name·city·address) + 4개 정보 섹션 표시.
  - 데이터: `stadiumProvider(id)` = `FutureProvider.autoDispose.family` (task-010 on-demand 패턴 그대로).
  - 모델: `Stadium`(id·name·city·address + parking/seating/route/convenience info, 모두 nullable).
  - UI: `stadium_screen.dart` placeholder → 실구현. 로딩/에러+재시도, null 필드 처리.
  - **out (YAGNI)**: 맛집·플랜B(task-012), 지도·좌표(task-016), 편집. lat/lng 표시 안 함.
- **완료조건(DoD)**:
  - ☐ `/stadium/:id` 진입 시 구장 name·city·address 헤더 + 주차·좌석·동선·편의점 4개 섹션이 뜬다
  - ☐ 정보 없는(null/빈) 필드는 "준비 중이에요" 로 깔끔히 처리 (레이아웃 안 깨짐)
  - ☐ 로딩 스피너 / 에러+재시도 / 당겨서새로고침(`ref.invalidate`) 동작
  - ☐ 일정 카드 탭 → 이 화면 진입 확인 (task-010 라우트 연결)
  - ☐ `flutter analyze` 0 issues, 기존 `flutter test` 회귀 없음
- **영향파일**: `app/lib/features/stadium/stadium.dart`(신규 모델),
  `stadium_provider.dart`(신규), `stadium_screen.dart`(수정: placeholder→실구현).
  계약 변경 없음 — 기존 stadiums 테이블 읽기만.
- **검증**: `cd app && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`
