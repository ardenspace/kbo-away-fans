/// 위치 접근 계층 — 앱의 위치 권한 접점은 이 파일 하나를 통과한다.
///
/// - `package:permission_handler` import 는 `lib/` 안에서 이 파일에만 둔다
///   (사이클 1이 `lib/analytics/analytics.dart`·`lib/weather/weather.dart` 에
///   세운 규칙과 같다 — 비 UI 계층은 최상위 폴더 하나에 파일 하나, 화면은 SDK
///   타입을 직접 만지지 않는다). 이 경계를 처음 세우는 자리가 이 파일이다
///   (step 2.5 전에는 저장소에 위치 관련 코드가 하나도 없었다). 서술로만 두지
///   않는다 — `scripts/hooks/check-firebase-import-boundary.sh` 가 이 파일 밖의
///   `permission_handler` import 를 잡아 커밋을 막는다.
/// - **이 파일이 다루는 것은 권한뿐이고, 좌표를 들고 있지 않다.** 실제 좌표를
///   읽는 자리는 같은 폴더의 `visit_check.dart`(구장 방문 판정 — 4.1)이고,
///   그 파일이 이 파일의 `LocationPermissionStatus` 를 소비한다. 둘을 나눠
///   둔 것은 좌표를 얻는 통로를 판정과 같은 라이브러리 안에 가두기
///   위해서다(그 까닭은 `visit_check.dart` 첫 문단). 홈 상단 현재 위치
///   표시(5.2)도 그 계층 안에 짓는다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// 위치 권한을 알아내는 기다림의 상한.
///
/// `kAppCheckActivationTimeout`·`kProfileServerConfirmGrace`·
/// `kCachedTeamReadTimeout` 과 같은 판단이고 같은 길이다: **사람이 보는 화면을
/// 붙잡는 기다림에는 상한이 있다.** 이 기다림을 붙잡고 있는 것은 팀 선택 직후의
/// 대기 화면이라, 끝나지 않는 조회는 곧 앱을 다시 켜는 것 말고 나갈 길이 없는
/// 상태가 된다. 상한을 두는 까닭은 확률이 아니라 그 성질이다
/// (`selected_team.dart` 의 `kCachedTeamReadTimeout` 주석과 같은 논거).
///
/// 넘어도 던지지 않는다 — 넘은 실행은 [resolveLocationPermission] 이 정한
/// 답으로 흘러간다.
const Duration kLocationPermissionTimeout = Duration(seconds: 5);

/// 이 계층의 실패 계약을 실행하는 한 자리.
///
/// [ask] 가 던지거나 [kLocationPermissionTimeout] 안에 답하지 않으면
/// [LocationPermissionStatus.denied] 로 답한다 — **알아내지 못한 것은 아직
/// 물어볼 수 있는 상태와 같이 다룬다.** 그렇게 정한 까닭은
/// `.wellbegun/decisions.md` 2026-09-04 [S] 에 있다: 이 신호는 계정당 한 번만
/// 서므로, 일시적인 실패를 "이미 결정됨"으로 접으면 그 사람에게는 설명과 요청이
/// 영영 오지 않는다. `denied` 로 접으면 설명이 뜨고, 어느 버튼을 눌러도 홈으로
/// 나가므로 사람이 갇히지 않는다.
///
/// 두 자리가 이 함수를 통과한다 — 실 구현([DevicePermissionHandlerGateway])과
/// 이 계층을 쓰는 화면(`lib/features/onboarding/location_consent.dart`)이다.
/// 화면 쪽에도 두는 것은, 게이트웨이가 **갈아 끼우는 이음매**라 화면이 자기가
/// 받는 구현이 이 계약을 지키는지 확인할 방법이 없기 때문이다. 정상 실행에서는
/// 안쪽 상한이 먼저 걸리므로 바깥 상한은 아무 일도 하지 않는다.
Future<LocationPermissionStatus> resolveLocationPermission(
  Future<LocationPermissionStatus> Function() ask,
) async {
  try {
    return await ask().timeout(kLocationPermissionTimeout);
  } catch (_) {
    // 무엇이 왔든(플랫폼 예외·타임아웃·그 밖의 오류) 이 계층 밖으로는 상태
    // 하나만 나간다 — `lib/backend/CLAUDE.md` 의 "SDK 예외를 밖으로 내보내지
    // 않는다"와 같은 규칙이고, 이 폴더의 짝은 `lib/location/CLAUDE.md` 다.
    return LocationPermissionStatus.denied;
  }
}

/// 위치 권한 상태 — 화면이 아는 것은 이 세 갈래뿐이다.
enum LocationPermissionStatus {
  /// 허용됨. iOS 의 "정확한 위치"·"대략적 위치"·"이번만 허용"을 구분하지
  /// 않고 하나로 접는다 — 이 앱은 구장 반경 판정에 정밀도 차이를 쓰지 않는다.
  granted,

  /// 아직 한 번도 결정하지 않았거나, 결정했지만 다시 물어볼 수 있는 거절.
  ///
  /// `permission_handler`(따라서 그 밑의 OS)는 "한 번도 안 물어봄"과 "물어봤고
  /// 거절했지만 또 물어볼 수 있음"을 같은 값으로 돌려준다 — 플랫폼 자체의
  /// 제약이라 이 계층에서 갈라낼 수 없다.
  denied,

  /// 영구 거절 — 앱 설정 화면을 거치지 않고는 다시 물어볼 길이 없다.
  permanentlyDenied,
}

/// 위치 권한 접점 — 테스트가 갈아 끼우는 경계.
///
/// 두 메서드로 나눈 것은 뜻이 다르기 때문이다: [status] 는 OS 다이얼로그를
/// 띄우지 않고 지금 상태만 읽고, [request] 는 상태가 [LocationPermissionStatus.denied]
/// (아직 물어볼 수 있는 상태)일 때만 실제로 다이얼로그를 띄운다 — 이미
/// 결정된 상태에서 부르면 `permission_handler` 자체가 다이얼로그 없이 지금
/// 상태를 그대로 돌려준다. 화면 쪽(`lib/features/onboarding/location_consent.dart`)
/// 이 "이미 허용·거절된 상태에서는 다시 묻지 않는다"를 지키는 자리가
/// [status] 이고, 그 판정을 이 계층이 아니라 화면 쪽에 둔 것은 "언제 물을지"가
/// 이 단계의 제품 결정(`decisions.md` 2026-09-01 [M])이지 SDK 배선이 아니기
/// 때문이다.
///
/// **실패 계약: 이 두 메서드는 던지지 않고, 상한 안에 반드시 답한다.** 알아내지
/// 못한 실행([kLocationPermissionTimeout] 을 넘겼거나 플랫폼이 예외를 던진
/// 실행)은 [LocationPermissionStatus.denied] 로 답한다. 구현이 그 계약을 지키는
/// 자리는 [resolveLocationPermission] 이고, 부르는 쪽은 그것을 믿되 자기
/// 화면을 붙잡는 기다림에는 같은 상한을 한 번 더 두어도 된다(그 까닭은
/// [resolveLocationPermission] 문서 참조).
abstract class LocationPermissionGateway {
  const LocationPermissionGateway();

  /// 지금 상태 — 다이얼로그를 띄우지 않는다.
  Future<LocationPermissionStatus> status();

  /// 상태가 [LocationPermissionStatus.denied] 일 때 OS 다이얼로그를 띄우고
  /// 결과를 돌려준다. 이미 [LocationPermissionStatus.granted]·
  /// [LocationPermissionStatus.permanentlyDenied] 인 상태에서 불러도 안전하다
  /// (다이얼로그 없이 그 상태를 그대로 돌려준다).
  Future<LocationPermissionStatus> request();

  /// 앱의 OS 설정 화면을 연다 — [LocationPermissionStatus.permanentlyDenied]
  /// 뒤에 [request] 로는 다시 물을 길이 없을 때의 유일한 경로다(step 4.5).
  ///
  /// [status]·[request] 와 달리 상한을 두지 않는다 — 이 호출이 붙잡는 화면이
  /// 없기 때문이다: 이것을 부르면 OS 가 앱을 배경으로 보내고 설정 앱을
  /// 열므로, 우리 화면은 그 순간 이미 포그라운드에서 사라져 있다(돌아오면
  /// `StadiumVisitTrigger` 의 `resumed` 가 다시 판정한다). 열기 자체가
  /// 실패해도(예: 플랫폼이 지원하지 않음) 안내는 그대로 화면에 남아 있으므로
  /// 사람이 갇히지 않는다 — 그래서 이 메서드도 던지지 않고 성공 여부를
  /// `bool` 로 답한다.
  Future<bool> openSettings();
}

/// 실제 구현 — `permission_handler` 위의 "앱 사용 중" 위치 권한
/// (`Permission.locationWhenInUse`). 백그라운드 위치는 쓰지 않는다
/// (`.wellbegun/decisions.md` 2026-09-01 [L]: 구장 방문 확인은 포그라운드
/// 판정뿐이라 "항상 허용"을 물을 이유가 없다).
class DevicePermissionHandlerGateway extends LocationPermissionGateway {
  const DevicePermissionHandlerGateway();

  @override
  Future<LocationPermissionStatus> status() => resolveLocationPermission(
    () async => _fromPlatform(await ph.Permission.locationWhenInUse.status),
  );

  @override
  Future<LocationPermissionStatus> request() => resolveLocationPermission(
    () async => _fromPlatform(await ph.Permission.locationWhenInUse.request()),
  );

  @override
  Future<bool> openSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (_) {
      // 이 폴더의 나머지와 같은 규칙 — SDK 예외를 밖으로 내보내지 않는다.
      return false;
    }
  }

  static LocationPermissionStatus _fromPlatform(ph.PermissionStatus status) =>
      switch (status) {
        ph.PermissionStatus.granted ||
        ph.PermissionStatus.limited ||
        ph.PermissionStatus.provisional => LocationPermissionStatus.granted,
        ph.PermissionStatus.permanentlyDenied =>
          LocationPermissionStatus.permanentlyDenied,
        // ph.PermissionStatus.denied · restricted 를 포함한 나머지 전부.
        _ => LocationPermissionStatus.denied,
      };
}

/// 화면이 소비하는 위치 권한 게이트웨이 — 테스트는 override 로 갈아끼운다.
final locationPermissionGatewayProvider = Provider<LocationPermissionGateway>(
  (_) => const DevicePermissionHandlerGateway(),
);
