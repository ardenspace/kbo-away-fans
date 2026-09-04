# lib/location/ — 작업 전 필독 (read-first)

기기의 위치와 닿는 코드는 이 폴더를 통과한다. 파일이 둘이고 아는 것이 다르다:
`location.dart` 는 **권한 상태 세 갈래**를(step 2.5), `visit_check.dart` 는
**좌표와 구장 방문 판정**을(step 4.1) 안다. 5.2(홈 상단 현재 위치)가 좌표를
쓸 자리도 이 계층 안이다.

- **위치 플러그인 import 는 이 폴더 안에만.** `package:permission_handler`·
  `package:geolocator` 를 `lib/features/`·`lib/ui/` 에서 import 하지 않는다.
  사이클 1이 지도·날씨 SDK 에 세운 규칙과 같다 — 화면은 이 계층이 내보내는
  타입(`LocationPermissionStatus`·`StadiumVisitResult`)만 소비한다.
  `scripts/hooks/check-firebase-import-boundary.sh` 가 이 경계를 잡고
  (pre-commit), 폴더가 아니라 **파일**로 좁혀 둔다 — `permission_handler` 는
  `lib/location/location.dart` 에만, `geolocator` 는
  `lib/location/visit_check.dart` 에만. 뒤엣것이 더 좁은 데는 까닭이 있다:
  기기의 좌표를 얻는 통로(`_readDeviceFix`)를 그 라이브러리 안에 private 으로
  가둬 두어야 다른 계층이 좌표를 손에 넣을 방법 자체가 없어진다. 그 통로를
  들고 도는 `StadiumVisitChecker` 도 그것을 **private 필드**로만 쥔다 —
  생성자로 넣을 수는 있어도(시험이 갈아 끼우는 이음매)
  `stadiumVisitCheckerProvider` 를 읽은 쪽이 다시 꺼내 부를 수는 없다.
- **SDK 예외를 밖으로 내보내지 않는다** (`lib/backend/CLAUDE.md` 의 같은 이름
  규칙의 짝). 이 폴더의 실패 계약은 오류 타입이 아니라 **값 하나**다: 권한
  조회는 던지지 않고, `kLocationPermissionTimeout` 안에 반드시 답하며,
  알아내지 못한 실행은 `LocationPermissionStatus.denied` 로 답한다. 좌표 조회도
  같은 모양이다 — 던지지 않고, `kLocationFixTimeout` 안에 답하며, 알아내지
  못한 실행은 `null` 로 답한다(판정은 그것을
  `StadiumVisitReason.locationUnavailable` 로 받는다). 그 계약을 실행하는
  자리는 `resolveLocationPermission`·`_readDeviceFix` 둘뿐이므로, 새 구현이나
  새 메서드를 더할 때 SDK 호출을 그 둘 중 하나의 모양으로 감싼다.
- **기다림에는 상한이 있다.** 이 규칙은 이 저장소가 이미 세 번 세웠다
  (`kAppCheckActivationTimeout`·`kProfileServerConfirmGrace`·
  `kCachedTeamReadTimeout`). 상한을 두는 까닭은 확률이 아니라 빠져나갈 길이
  없다는 성질이다 — 권한 조회를 기다리는 것은 온보딩 직후의 대기 화면이다.
  다만 **길이는 그 기다림이 무엇을 붙잡고 있는지에 따라 다르다**:
  `kLocationFixTimeout`(10초)이 위 넷보다 긴 것은 측위가 아무 화면도 붙잡지
  않기 때문이고, 그 근거는 그 상수 주석에 있다.
- **기기가 어디에 있었는지는 서버로 올리지 않는다** (되돌리기 비용 XL 의 제품
  결정, `.wellbegun/decisions.md` 2026-09-01). 좌표는 이 계층 안에서 판정에만
  쓰고 결과(어느 구장·어느 경기)만 백엔드로 넘긴다. 그래서 이 폴더는
  **`lib/backend/` 를 import 하지 않는다** — 업로드 계층에 닿을 수 있는 길을
  만들지 않으면 좌표가 payload 로 흘러갈 길도 없다. 백엔드로 넘길 결과가 있으면
  이 폴더가 아니라 부르는 쪽(feature)이 두 계층을 잇는다.
  `scripts/hooks/check-no-location-upload.sh` 가 이 폴더의 `import`·`export` 를
  잡는다(step 2.5, PostToolUse + pre-commit). 그 검사가 `lib/backend/` 에서처럼
  `lat`·`lng` 같은 **이름**을 막지 않는 것은 이 폴더에서는 좌표가 정당하기
  때문이다 — 여기서 막는 것은 이름이 아니라 나가는 길이다. 4.1 이 실제로
  좌표를 들여온 뒤로 이 폴더가 그 약속을 지키는 겹은 셋이고, 셋 다 훅이
  아니라 **구조나 시험**이 지킨다: (1) 좌표를 얻는 통로가 `visit_check.dart`
  안의 private 함수 하나이고 판정기(`StadiumVisitChecker`)도 그것을 private
  필드로만 쥐며, 그 밖에는 플러그인 직접 호출뿐인데 그 import 가 같은 파일로
  못 박혀 있다, (2) 이 폴더가 `lib/backend/` 를 import 하지 않아 안에서도
  보낼 곳이 없다, (3) 경계를 넘는 값(`StadiumVisitResult`)에 좌표가 없고, 그
  **필드 집합 자체**를 `test/features/badges/visit_check_test.dart` 의
  파수꾼이 이 파일의 소스를 읽어 표와 대조한다 — 그 타입에 좌표 필드를 하나
  더하면 빨간불이다. (1)·(3) 이 서술뿐이던 동안에는 어느 feature 든 판정기에서
  실 좌표를 꺼내 쓸 수 있었고 결과 타입에 좌표를 실어 보낼 수 있었다
  (`.wellbegun/decisions.md` 2026-09-04 `[M]`·`[S]`). 좌표는 어디에도 적히지 않는다 —
  캐시·`shared_preferences`·로그 어느 쪽으로도 흐르지 않고 판정이 끝나면
  버려진다.
- **백그라운드 위치는 쓰지 않는다** (`.wellbegun/decisions.md` 2026-09-01 [L]).
  묻는 권한은 `Permission.locationWhenInUse` 하나이고, "항상 허용"을 뜻하는
  `Permission.location` 을 요청하지 않는다. 구장 방문 확인은 앱이 열려 있을 때만
  하는 포그라운드 판정이다 — 그 판정을 트리거하는 자리도 앱이 열려 있을 때만
  도는 위젯(`lib/features/badges/stadium_visit.dart` 의 `StadiumVisitTrigger`)
  이고, 이 폴더에는 주기 실행도 백그라운드 작업도 없다.
- **이 폴더는 권한을 다시 묻지 않는다.** 2.5 가 온보딩에서 한 번 묻고, 4.1 의
  판정은 `status()`(다이얼로그 없는 조회)만 쓴다. "나중에 할게요"로 건너뛴
  사람에게 다시 묻는 진입점은 아직 저장소 어디에도 없다 — 그것을 세우는
  단계는 `StadiumVisitReason.permissionMissing` 을 신호로 쓸 수 있다(그 이유는
  **경기가 있는 날에만** 선다).
