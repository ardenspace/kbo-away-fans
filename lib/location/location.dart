/// 위치 접근 계층 — 앱의 위치 권한 접점은 이 파일 하나를 통과한다.
///
/// - `package:permission_handler` import 는 `lib/` 안에서 이 파일에만 둔다
///   (사이클 1이 `lib/analytics/analytics.dart`·`lib/weather/weather.dart` 에
///   세운 규칙과 같다 — 비 UI 계층은 최상위 폴더 하나에 파일 하나, 화면은 SDK
///   타입을 직접 만지지 않는다). 이 경계를 처음 세우는 자리가 이 파일이다
///   (step 2.5 전에는 저장소에 위치 관련 코드가 하나도 없었다).
/// - 이 단계(2.5)가 다루는 것은 **권한 요청**뿐이다. 실제 좌표를 읽는 자리
///   (구장 근처 판정 — 4.1, 홈 상단 현재 위치 표시 — 5.2)는 이 계층이 내보내는
///   권한 상태 뒤에서 다음 단계가 짓는다. 그래서 이 파일은 좌표를 들고 있지
///   않고, 권한 상태 세 갈래만 안다 — 기기 위치를 서버에 올리지 않는다는
///   저장소의 약속(`lib/backend/CLAUDE.md`)이 이 계층에서부터 지켜진다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

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
abstract class LocationPermissionGateway {
  const LocationPermissionGateway();

  /// 지금 상태 — 다이얼로그를 띄우지 않는다.
  Future<LocationPermissionStatus> status();

  /// 상태가 [LocationPermissionStatus.denied] 일 때 OS 다이얼로그를 띄우고
  /// 결과를 돌려준다. 이미 [LocationPermissionStatus.granted]·
  /// [LocationPermissionStatus.permanentlyDenied] 인 상태에서 불러도 안전하다
  /// (다이얼로그 없이 그 상태를 그대로 돌려준다).
  Future<LocationPermissionStatus> request();
}

/// 실제 구현 — `permission_handler` 위의 "앱 사용 중" 위치 권한
/// (`Permission.locationWhenInUse`). 백그라운드 위치는 쓰지 않는다
/// (`.wellbegun/decisions.md` 2026-09-01 [L]: 구장 방문 확인은 포그라운드
/// 판정뿐이라 "항상 허용"을 물을 이유가 없다).
class DevicePermissionHandlerGateway extends LocationPermissionGateway {
  const DevicePermissionHandlerGateway();

  @override
  Future<LocationPermissionStatus> status() async =>
      _fromPlatform(await ph.Permission.locationWhenInUse.status);

  @override
  Future<LocationPermissionStatus> request() async =>
      _fromPlatform(await ph.Permission.locationWhenInUse.request());

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
