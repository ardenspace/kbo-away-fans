# Plan: KBO 원정팬 — Lane C (GPS 스탬프 + 네이버맵)
version: 1
status: approved

## Phase 1: GPS 스탬프 + 스탬프북 (NCP 키 불필요)
Goal: 홈에서 스탬프북(10칸)을 열고, 구장 반경 안에서 "도장 찍기"로 스탬프가
쾅 찍히는 완결 기능 — 발급/거부/중복/실패 분기가 모두 동작한다.
Phase acceptance: `flutter test` green. 위치 mock + 데이터 계층 fake로 발급
성공·반경 밖 거부·중복·권한 거부·서비스 꺼짐·네트워크 오류·잠실 칸 배정·연타
방지가 모두 테스트로 통과하고, 스탬프북이 10칸 그리드로 렌더되며 도장 애니·
햅틱이 발급 칸당 각 1회 트리거된다. (실기기 실GPS 발급은 수동 확인 대상.)

### Task 1.1: 시드 — 잠실 LG 행 추가 + 재적재
risk: light
covers: R15
files: scripts/seed/data/stadiums.json
acceptance:
- scripts/seed/data/stadiums.json 이 10개 구장 항목을 담는다.
- 잠실 좌표를 공유하는 두 항목이 존재하고, 하나는 name="잠실야구장"(기존),
  다른 하나는 그와 다른 고유 name(예: "잠실야구장 (LG)")이다.
- 새 LG 행은 기존 항목들과 동일한 스키마 필드를 쓴다 — 특히 팀 지정은
  `team_abbr: "LG"` 다 (seed.py 가 team_id 가 아니라 team_abbr 를 읽어
  team_id 로 해석하므로; 리터럴 team_id 필드는 무시되어 FK NULL 이 됨).
- LG 행의 name 이 크롤러 별칭표의 "잠실"→"잠실야구장" 매핑 대상 문자열과 다르다
  (파일 단언: 기존 "잠실야구장"과 문자열 불일치).
- 시드 재적재(멱등 upsert)는 원격 맥미니 DB 대상 ops 액션이라 자동 테스트가
  아니라 **task 절차의 수동 단계**로 기록한다: `python3 scripts/seed.py` 실행
  후 stadiums count=10 확인 (Phase 1 실기기 확인의 전제).

### Task 1.2: 위치 provider 추상화 + 플랫폼 권한 설정
risk: heavy
covers: R4, R11
files: app/lib/features/stamp/location_provider.dart, app/pubspec.yaml,
  app/ios/Runner/Info.plist, app/android/app/src/main/AndroidManifest.xml
acceptance:
- 위치 조회가 riverpod provider 인터페이스 뒤에 있고, 테스트에서 mock 구현을
  override 로 주입할 수 있다 (단위 테스트가 실기기·플러그인 없이 통과).
- provider 는 (권한거부 / 서비스꺼짐 / 좌표획득 / 타임아웃) 을 구분되는 결과
  타입으로 반환한다 — 각 분기가 mock 으로 재현 가능함을 단위 테스트로 확인.
- 위치 조회에 유한 타임아웃(상수로 정의)이 걸려 있어 fix 미획득 시 타임아웃
  결과를 반환한다 (mock 지연으로 검증).
- iOS Info.plist 에 NSLocationWhenInUseUsageDescription 문자열이, Android
  Manifest 에 ACCESS_FINE_LOCATION(및 COARSE) 권한이 선언돼 있다 (백그라운드
  위치 권한은 선언하지 않는다).

### Task 1.3: 데이터 계층 — stamp/stadium/games repository
risk: heavy
covers: R1, R3, R6, R13
files: app/lib/features/stamp/stamp_repository.dart,
  app/lib/features/stamp/stadium_repository.dart,
  app/lib/features/stamp/stamp_models.dart
acceptance:
- stamp 저장(insert) / 내 스탬프 목록 조회 / stadium 목록 조회 / 특정 날짜
  잠실 경기 팀 조회가 각각 repository 메서드로 있고, 전부 fake 구현으로 교체
  가능한 인터페이스다 (Supabase 클라이언트 직접 참조가 UI·도메인에 없음).
- stadium 모델이 팀 식별 정보(team_id 및 도장 색 결정에 쓸 팀 abbr/컬러 키)를
  포함한다 — Task 1.4(두산 vs LG 칸 식별)와 1.6(칸별 팀 컬러 도장)이 이 필드에
  의존하므로 여기서 미리 갖춘다 (모델 필드 존재를 단위 테스트로 확인).
- insert 메서드가 UNIQUE(user_id, stadium_id) 위반을 구분 가능한 예외/결과로
  표면화한다 (fake 가 위반을 던지면 호출부가 "중복"으로 식별).
- 스탬프 목록 조회는 서버(fake) 응답만을 소스로 하며 로컬 캐시 폴백이 없다
  (fake N개 반환 → 목록 길이 N; 다른 소스 없음).
- 조회 실패(fake 가 network error)를 호출부가 구분 가능한 에러로 받는다.

### Task 1.4: 근접 판정 + 거리 계산 + 잠실 칸 배정 도메인
risk: heavy
covers: R1, R2, R13
files: app/lib/features/stamp/stamp_domain.dart
acceptance:
- 하버사인 거리 함수가 있고, 좌표·반경(stamp_radius_m) 입력에 대해 반경 내/밖을
  boolean 으로 판정한다 (경계값 포함 단위 테스트).
- 반경 밖일 때 "가장 가까운 구장"과 거리(km, 소수 1자리 문자열 "N.Nkm")를
  계산하며, 동일 좌표 동률(잠실 두 행)이면 name="잠실야구장" 행을 택한다.
- 잠실 칸 배정: 기준 날짜(주입) + 주입된 잠실 경기 팀 목록으로 발급 대상 칸
  집합을 계산 — {두산,LG} 교집합에 발급, 맞대결/무경기(빈 목록)/교집합 공집합은
  두 칸 모두, 기준 날짜는 KST 달력일로 해석(UTC 저장 좌표 역변환)한다.
- 잠실 외 8구장은 반경 판정만으로 단일 칸이 대상이 된다.
- 모든 함수가 순수 Dart 로 실기기·시계 의존 없이 테스트된다 (기준 시각 주입).

### Task 1.5: 발급 컨트롤러 — 상태머신 + 실패 분기 + 연타/중복 방지
risk: heavy
covers: R3, R4, R5, R13, R14
files: app/lib/features/stamp/stamp_controller.dart
acceptance:
- 위치 provider mock + repository fake 주입만으로 컨트롤러 단위/위젯 테스트가
  `flutter test` 에서 통과한다.
- 반경 내 발급 → 대상 칸이 fake 저장 계층에 insert 되고 성공 상태가 방출된다.
- 반경 밖 → insert 미발생 + "구장까지 N.Nkm" 메시지 상태.
- 권한 거부 → 설정 유도 상태 방출 + 예외 없음(`tester.takeException()==null`).
- 서비스 꺼짐 / network error / 타임아웃 → insert 미발생 + 원인 메시지 + 재시도
  가능(재호출 시 fake 호출 카운트 +1)으로 수렴.
- 이미 찍힌 칸(선판정) 및 주입된 UNIQUE 위반 둘 다 동일한 "중복" 상태로 수렴.
- 발급 진행 중 재진입(연타) 시 저장 호출이 그 시도의 대상 칸 수를 넘지 않는다
  (단일=1, 잠실 2칸=2). 잠실 복수 칸의 부분 실패 시 성공 칸은 성공 처리하고
  나머지는 실패 상태.

### Task 1.6: 스탬프북 화면 — 10칸 그리드 + 수집률 + 로딩/오류
risk: light
covers: R6, R7
files: app/lib/features/stamp/stamp_screen.dart,
  app/lib/features/stamp/stampbook_widgets.dart
acceptance:
- fake 로 스탬프 M개·구장 10개 주입 시 10칸 그리드가 렌더되고 수집률 텍스트가
  "M/10" 이다.
- 방문 칸과 미방문 칸이 위젯 속성(Key 또는 색 프로퍼티)으로 구분되며, 방문 칸
  도장 색이 그 칸의 팀 컬러다 (미방문=회색 아웃라인).
- 원격 조회 중에는 로딩 인디케이터, 조회 실패 시 "0/10" 빈 그리드가 아니라
  오류+재시도 위젯이 렌더된다 (fake network error 로 검증).
- "도장 찍기" 버튼이 존재하고 발급 진행 중 비활성(onPressed==null)이다.

### Task 1.7: 도장 애니메이션 + 햅틱 순차 재생
risk: light
covers: R8
files: app/lib/features/stamp/stamp_stamp_animation.dart,
  app/lib/features/stamp/stamp_screen.dart
acceptance:
- 단일 칸 발급 성공 시 도장 애니 트리거와 햅틱 플랫폼 채널 호출이 각 정확히
  1회 발생한다 (위젯 테스트로 애니 컨트롤러 forward 호출 및 HapticFeedback
  채널 메시지 카운트 검증).
- 잠실 2칸 발급 시 애니·햅틱이 각 2회, 칸 순서대로 순차 발생한다 (호출 순서
  검증).
- 외부 애니 에셋(Lottie/Rive) 의존 없이 Flutter 기본 애니 프리미티브만 사용한다
  (pubspec 에 해당 패키지 추가 없음 — 파일 단언).

## Phase 2: 네이버맵 + 경로 애니 (NCP 키 필요 — 실기기 확인은 키 공급 후)
Goal: 홈 "원정 지도" 버튼으로 /map 을 열면 10구장 마커·내 위치가 뜨고, 방문
구장 2곳 이상이면 방문 순서대로 경로 애니가 재생된다.
Phase acceptance: `flutter test` green (마커 모델·경로 시퀀스·재진입 재발화
단위/위젯 테스트 포함). Client ID 주입 실행에서 /map 이 네이버맵+마커+내 위치+
경로를 렌더하고, 미주입 실행에서 지도 대신 안내 텍스트로 degrade 하며 crash
없음. (네이티브 지도·애니 렌더 자체는 실기기 수동 확인 대상.)

### Task 2.1: 지도 마커 모델 — 잠실 병합 + 방문 플래그
risk: light
covers: R9
files: app/lib/features/map/map_models.dart, app/lib/features/map/map_domain.dart
acceptance:
- 구장 목록 + 내 스탬프 목록 입력으로 마커 모델 리스트를 만든다 — 동일 좌표
  (잠실 두 행)는 마커 1개로 병합된다 (10구장 → 마커 9개).
- 병합된 잠실 마커는 두 칸 중 하나라도 방문이면 isVisited=true 다.
- 각 마커에 방문 여부 플래그가 있고, 잠실 외 구장은 1:1 로 매핑된다.
- 전부 순수 Dart 단위 테스트 (네이티브·키 의존 없음).

### Task 2.2: 경로 좌표 시퀀스 로직
risk: light
covers: R10
files: app/lib/features/map/map_domain.dart
acceptance:
- 방문 스탬프 목록(stamped_at 포함) 입력에 대해 stamped_at 오름차순으로 정렬된
  구장 좌표 시퀀스를 반환한다.
- 연속 동일 좌표(잠실 두 칸 연속 방문)는 중복 제거된다.
- 방문 칸 ≤1 이면 빈(또는 길이<2) 시퀀스를 반환해 "경로 없음" 을 나타낸다.
- 전부 순수 Dart 단위 테스트.

### Task 2.3: NCP Client ID 배선 + ops 문서 + 미주입 degrade
risk: light
covers: R12
files: app/lib/features/map/naver_map_config.dart, app/lib/main.dart,
  docs/ops/ncp-maps-setup.md
acceptance:
- NCP Client ID 를 `--dart-define`(String.fromEnvironment) 로 읽는 참조가
  코드에 존재한다 (git grep 로 확인).
- docs/ops/ncp-maps-setup.md 파일이 존재하고 "발급", "번들 ID" 또는 "패키지명",
  "한도 설정", "무료 이용량" 토큰이 grep 으로 각 1건 이상 검출된다 (콘솔에서
  Mobile Dynamic Map 무료 이용량 수치·한도 설정 적용을 확인하는 단계 문서화).
- Client ID 값이 저장소 추적 파일에 하드코딩돼 있지 않다 (관행 — 실키 미공급
  상태라 grep 0건).
- Client ID 미주입(빈 문자열) 판정 함수가 있어 미주입 시 지도 화면이 degrade
  경로를 타도록 한다 (단위 테스트: 빈 값 → shouldDegrade==true).

### Task 2.4: 지도 화면 골격 — flutter_naver_map 통합 + 추상화 seam + degrade
risk: heavy
covers: R9, R12
files: app/lib/features/map/map_screen.dart, app/lib/features/map/map_view.dart,
  app/pubspec.yaml
acceptance:
- 지도 화면은 네이티브 네이버맵 위젯을 테스트 대체 가능한 추상 위젯(map_view)
  뒤에 두며, 위젯 테스트는 그 대체 구현으로 pump 되어 `flutter test` 에서
  통과한다 (네이티브 SDK 미로딩).
- Client ID 미주입 시 네이티브 지도 위젯을 생성하지 않고 화면 중앙 안내
  텍스트를 렌더한다 (`tester.takeException()==null`).
- Client ID 주입 시에는 map_view 추상 위젯이 (테스트 대체 구현이 아닌) 실제
  네이버맵 경로로 구성되도록 배선한다 (구성 분기를 단위 테스트로 확인).
- 마커 모델(Task 2.1) 을 받아 map_view 에 전달한다 (마커 목록 전달을 위젯
  테스트로 확인).

### Task 2.5: 지도 view-state — 내 위치/권한 + 경로 애니 재생 + 오류
risk: heavy
covers: R9, R10
files: app/lib/features/map/map_screen.dart,
  app/lib/features/map/map_controller.dart
acceptance:
- 위치 권한 거부 시 view-state 가 (내위치=off, 안내 메시지≠null, 마커·경로=
  정상) 이다 (단위/위젯 테스트).
- 방문 칸 ≥2 로 진입 시 경로 애니 트리거가 발화하고 ≤1 이면 발화하지 않으며,
  화면을 떠났다 재진입하면 트리거가 다시 발화한다 (대체 위젯으로 pump 검증).
- 경로 좌표는 Task 2.2 시퀀스 로직 결과를 사용한다 (주입된 방문 목록 → 예상
  좌표 시퀀스가 map_view 에 전달됨을 위젯 테스트로 확인).
- 마커·경로 데이터 조회 실패 시 빈 지도가 아니라 오류+재시도 상태를 표시한다.

### Task 2.6: 홈 "원정 지도" 버튼 + /map 라우트
risk: light
covers: R9
files: app/lib/router/router.dart, app/lib/router/home_screen.dart
acceptance:
- go_router 에 '/map' 라우트가 등록되고 MapScreen 을 빌드한다.
- 홈 화면에 "원정 지도" 버튼이 있고 탭 시 /map 으로 이동한다 (위젯 테스트:
  버튼 탭 → 라우트 변경).
- 기존 홈 버튼(내 스탬프 등) 회귀 없음 (기존 위젯 테스트 green 유지).

### Task 2.7: flutter_naver_map 네이티브 플랫폼 설정
risk: light
covers: R12
files: app/ios/Runner/AppDelegate.swift 또는 Info.plist,
  app/android/app/src/main/AndroidManifest.xml, app/android/build.gradle
acceptance:
- `flutter analyze` 가 통과하고, flutter_naver_map 이 요구하는 iOS/Android
  네이티브 항목(클라이언트 ID 주입 지점, 최소 SDK 버전 라인)이 양 플랫폼 설정
  파일에 존재한다 (grep 파일 단언).
- Client ID 는 빌드 타임 주입 지점을 통해 전달되며 네이티브 파일에 값이
  하드코딩되지 않는다.

## Re-plans
(없음)
