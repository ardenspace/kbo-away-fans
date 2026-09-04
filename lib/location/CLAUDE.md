# lib/location/ — 작업 전 필독 (read-first)

기기의 위치와 닿는 코드는 이 폴더를 통과한다. 오늘 이 폴더가 아는 것은 **권한
상태 세 갈래**뿐이고(step 2.5), 좌표를 실제로 읽는 자리는 4.1(구장 근처 판정)·
5.2(홈 상단 현재 위치)가 이 계층 안에 짓는다.

- **위치 플러그인 import 는 이 폴더 안에만.** `package:permission_handler` 를
  `lib/features/`·`lib/ui/` 에서 import 하지 않는다. 사이클 1이 지도·날씨 SDK 에
  세운 규칙과 같다 — 화면은 이 계층이 내보내는 타입(`LocationPermissionStatus`)
  만 소비한다. 좌표를 다루는 플러그인이 뒤에 들어와도 같은 규칙이 걸린다.
  `scripts/hooks/check-firebase-import-boundary.sh` 가 이 경계를 잡는다(step
  2.5, pre-commit) — `lib/location/location.dart` 밖의 `permission_handler`
  import 는 커밋을 막는다.
- **SDK 예외를 밖으로 내보내지 않는다** (`lib/backend/CLAUDE.md` 의 같은 이름
  규칙의 짝). 이 폴더의 실패 계약은 오류 타입이 아니라 **상태 하나**다:
  권한 조회는 던지지 않고, `kLocationPermissionTimeout` 안에 반드시 답하며,
  알아내지 못한 실행은 `LocationPermissionStatus.denied` 로 답한다. 그 계약을
  실행하는 자리는 `resolveLocationPermission` 하나이므로, 새 구현이나 새
  메서드를 더할 때 SDK 호출을 그 함수로 감싼다.
- **사람이 보는 화면을 붙잡는 기다림에는 상한이 있다.** 이 규칙은 이 저장소가
  이미 세 번 세웠다(`kAppCheckActivationTimeout`·`kProfileServerConfirmGrace`·
  `kCachedTeamReadTimeout`). 상한을 두는 까닭은 확률이 아니라 빠져나갈 길이
  없다는 성질이다 — 위치 조회를 기다리는 것은 온보딩 직후의 대기 화면이다.
- **기기가 어디에 있었는지는 서버로 올리지 않는다** (되돌리기 비용 XL 의 제품
  결정, `.wellbegun/decisions.md` 2026-09-01). 좌표는 이 계층 안에서 판정에만
  쓰고 결과(어느 구장·어느 경기)만 백엔드로 넘긴다. 그래서 이 폴더는
  **`lib/backend/` 를 import 하지 않는다** — 업로드 계층에 닿을 수 있는 길을
  만들지 않으면 좌표가 payload 로 흘러갈 길도 없다. 백엔드로 넘길 결과가 있으면
  이 폴더가 아니라 부르는 쪽(feature)이 두 계층을 잇는다.
  `scripts/hooks/check-no-location-upload.sh` 가 이 폴더의 `import`·`export` 를
  잡는다(step 2.5, PostToolUse + pre-commit). 그 검사가 `lib/backend/` 에서처럼
  `lat`·`lng` 같은 **이름**을 막지 않는 것은 이 폴더에서는 좌표가 정당하기
  때문이다 — 여기서 막는 것은 이름이 아니라 나가는 길이다.
- **백그라운드 위치는 쓰지 않는다** (`.wellbegun/decisions.md` 2026-09-01 [L]).
  묻는 권한은 `Permission.locationWhenInUse` 하나이고, "항상 허용"을 뜻하는
  `Permission.location` 을 요청하지 않는다. 구장 방문 확인은 앱이 열려 있을 때만
  하는 포그라운드 판정이다.
