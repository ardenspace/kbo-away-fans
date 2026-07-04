# Handoff
version: 1
trigger: context-threshold
position: Phase 2 진행 중. 1.x 전부 + 2.1·2.2 done+검증. 다음 = Task 2.3 (NCP Client ID 배선 + ops 문서 + 미주입 degrade).

## Next session must know
- 전체 테스트 baseline = **109/109 green**, analyze clean. 이 세션에서 1.5~1.7(Phase 1 완결+경계검증), 2.1(마커 모델), 2.2(경로 시퀀스) 완료.
- Phase 2는 **NCP Client ID 없이 완료 가능하게 설계됨** — 모든 2.x acceptance는 `flutter test` green + 추상화(map_view 테스트 대체 위젯) + degrade 경로로 검증. 실기기 네이티브 지도/애니 렌더만 키 공급 후 수동 확인. → external-blocker HALT 불필요, 정상 진행.
- 남은 Phase 2: 2.3(키 배선+ops문서+degrade, light), 2.4(지도 화면 골격 map_view 추상화, heavy), 2.5(view-state 내위치/경로애니, heavy), 2.6(홈 "원정 지도" 버튼+/map 라우트, light), 2.7(네이티브 플랫폼 설정, light). 2.7 이후 Phase 2 경계 검증(마지막 phase → run 완료).

## 재사용 계약 (Phase 2가 의존)
- app/lib/features/map/map_domain.dart: `buildMapMarkers(stadiums, visitedStadiumIds)` → 10구장→9마커, 좌표 (lat,lng) record 키 병합, isVisited=그룹 OR. `buildStadiumRouteSequence(stamps, stadiums)` → stampedAt 오름차순 좌표 시퀀스, 인접 중복만 dedup, ≤1→길이<2. 좌표 동일성=`(lat,lng)` Dart record 구조적 동등(양 함수 통일). Task 2.4/2.5가 이 둘을 map_view에 전달.
- app/lib/features/map/map_models.dart: 2.1 마커 모델(방문 플래그 포함).
- stamp_models.dart: Stadium(id/lat/lng/team_id/team abbr·컬러 키), Stamp(stampedAt=non-null DateTime, stadiumId). 두산 abbr="OB", LG="LG".
- app/lib/shared/theme: kTeamColors[abbr] (마커 강조색 재사용).
- StampRepository.myStamps / StadiumRepository.listStadiums — 데이터 소스.
- 위치: currentLocationProvider seam + sealed LocationResult 4분기(Acquired/PermissionDenied/ServiceDisabled/Timeout) — 지도 내 위치 표시(2.5)에 재사용.
- 라우터: app/lib/router/router.dart(기존 /stamp 등록됨, 2.6이 /map 추가), home_screen.dart(기존 "내 스탬프" 버튼, 2.6이 "원정 지도" 추가).

## Watch out for
- 구현자 보고의 "N tests" 카운트는 서브셋(예: map/stamp만) — 검증자가 항상 전체 `flutter test`로 재확인. 현재 전체 baseline=109.
- riverpod 3.1.0: `Override` public export 안 됨 — 테스트는 내부 컨트롤러 override 패턴(Phase 1 stamp 테스트 참고).
- flutter_naver_map = 네이티브 SDK, 위젯 테스트 불가 → 2.4에서 map_view 추상 위젯 뒤에 두고 테스트 대체 구현으로 pump. Client ID 미주입 시 네이티브 위젯 생성 안 하고 안내 텍스트 degrade(crash 없음, tester.takeException()==null).
- Task 2.3 docs/ops/ncp-maps-setup.md 신규 필요(grep 토큰 각 1건+: 발급 / 번들ID·패키지명 / 한도설정 / 무료이용량). 실키 하드코딩 금지(grep 0건). 참고 패턴: 기존 task-009 ops-kakao-setup.md.
- 잠실 games 조회 규약(1.5): name==kJamsilCanonicalName("잠실야구장", OB행) id. 지도쪽 무관하나 인지.

## Project Facts (state.md 동일 — 편의 복제)
- test: cd app && flutter test
- analyze: cd app && flutter analyze
- build/run(Phase 2): cd app && flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=NCP_MAP_CLIENT_ID=...
