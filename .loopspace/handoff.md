# Handoff
version: 1
trigger: phase-boundary
position: Phase 1 완료·검증됨. 다음 = Phase 2, Task 2.1 (지도 마커 모델).

## Next session must know
- Phase 1 (GPS 스탬프+스탬프북) 전부 done+검증. 전체 테스트 95/95 green, analyze clean.
- Phase 2 = 네이버맵 + 경로 애니. **NCP Client ID 없이 완료 가능하게 설계됨** — 모든 2.x
  acceptance는 `flutter test` green + 추상화(map_view 테스트 대체 위젯) + degrade 경로로
  검증. 실기기 네이티브 지도/애니 렌더만 키 공급 후 수동 확인 대상. → external-blocker
  HALT 불필요, 정상 진행.
- 기존 재사용 계약(Phase 1에서 확립, Phase 2가 의존):
  - stadiums: 잠실 두 행(같은 좌표) — "잠실야구장"(OB, canonical) + "잠실야구장 (LG)".
    Task 2.1 마커 병합은 이 동일 좌표를 1개로 합침(10구장→마커 9개).
  - stamp_models.dart: stadium 모델에 team_id + team abbr/컬러 키. 두산 abbr="OB", LG="LG".
  - app/lib/shared/theme: 팀 컬러 kTeamColors[abbr] (도장·마커 강조색 재사용).
  - StampRepository.myStamps / StadiumRepository.listStadiums — 마커·경로 데이터 소스.
    stamp에 stamped_at 존재(경로 시퀀스 stamped_at 오름차순 정렬 — Task 2.2).
  - 위치: currentLocationProvider seam + sealed LocationResult 4분기 (지도 내 위치 표시 재사용).
  - riverpod 3.1.0: `Override` public export 안 됨 — 테스트는 내부 컨트롤러 override 패턴 사용.

## Watch out for
- 구현자 보고의 "N stamp tests" 카운트는 stamp 서브셋 — 전체 스위트 카운트와 다름. 검증자가
  항상 전체 `flutter test`로 재확인(현재 전체 baseline = 95).
- 잠실 games 조회 규약(Task 1.5): name==kJamsilCanonicalName("잠실야구장", OB행) id로 조회.
  games FK가 실제 LG행을 가리키면 그 한 줄만 조정 — 지도쪽엔 무관하나 인지.
- flutter_naver_map = 네이티브 SDK라 위젯 테스트 불가 → Task 2.4에서 map_view 추상 위젯
  뒤에 두고 테스트 대체 구현으로 pump. 마커/경로/애니 조건 로직은 순수 Dart(2.1/2.2)로 분리.
- Task 2.3: docs/ops/ncp-maps-setup.md 신규 작성 필요(grep 토큰: 발급/번들ID·패키지명/한도설정/무료이용량).
  실키 하드코딩 금지(grep 0건).

## Project Facts (state.md와 동일 — 편의 복제)
- test: cd app && flutter test
- analyze: cd app && flutter analyze
- build/run(Phase 2): cd app && flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=NCP_MAP_CLIENT_ID=...
