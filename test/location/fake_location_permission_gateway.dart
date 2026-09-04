import 'package:kbo_away_fans/location/location.dart';

/// 위치 권한 게이트웨이의 기록용 대역.
///
/// [status] 는 몇 번 불렸는지와 무관하게 지금 값을 그대로 돌려주고, [request]
/// 가 불리면 그 결과로 값이 바뀐다 — 실 `permission_handler` 가 이미 결정된
/// 상태에서는 다이얼로그 없이 그 값을 그대로 돌려주는 것과 같은 모양이다.
class FakeLocationPermissionGateway extends LocationPermissionGateway {
  FakeLocationPermissionGateway({
    LocationPermissionStatus initial = LocationPermissionStatus.denied,
    LocationPermissionStatus? afterRequest,
  }) : _status = initial,
       _afterRequest = afterRequest ?? initial;

  LocationPermissionStatus _status;
  final LocationPermissionStatus _afterRequest;

  /// [status] 가 불린 횟수.
  int statusCalls = 0;

  /// [request] 가 불린 횟수 — 0 이면 OS 에 한 번도 묻지 않았다는 뜻이다.
  int requestCalls = 0;

  @override
  Future<LocationPermissionStatus> status() async {
    statusCalls++;
    return _status;
  }

  @override
  Future<LocationPermissionStatus> request() async {
    requestCalls++;
    _status = _afterRequest;
    return _status;
  }
}
