import 'dart:async';

import 'package:kbo_away_fans/location/location.dart';

/// 위치 권한 게이트웨이의 기록용 대역.
///
/// [status] 는 몇 번 불렸는지와 무관하게 지금 값을 그대로 돌려주고, [request]
/// 가 불리면 그 결과로 값이 바뀐다 — 실 `permission_handler` 가 이미 결정된
/// 상태에서는 다이얼로그 없이 그 값을 그대로 돌려주는 것과 같은 모양이다.
///
/// **실패하는 대역도 이 한 클래스로 만든다.** 실 플러그인은 플랫폼 채널이
/// 답하지 않거나 `PlatformException` 을 던질 수 있고, 그때 사람이 어디로
/// 가는지가 이 계층의 계약이다([kLocationPermissionTimeout] 참조). 그 갈래를
/// 재려면 대역이 그렇게 **행동할 수** 있어야 한다.
class FakeLocationPermissionGateway extends LocationPermissionGateway {
  FakeLocationPermissionGateway({
    LocationPermissionStatus initial = LocationPermissionStatus.denied,
    LocationPermissionStatus? afterRequest,
    this.statusError,
    this.requestError,
    this.statusNeverAnswers = false,
    this.requestNeverAnswers = false,
    this.openSettingsResult = true,
  }) : _status = initial,
       _afterRequest = afterRequest ?? initial;

  LocationPermissionStatus _status;
  final LocationPermissionStatus _afterRequest;

  /// [status] 가 던질 오류 — null 이면 정상으로 답한다.
  final Object? statusError;

  /// [request] 가 던질 오류 — null 이면 정상으로 답한다.
  final Object? requestError;

  /// 참이면 [status] 가 영영 끝나지 않는다 (멎은 플랫폼 채널).
  final bool statusNeverAnswers;

  /// 참이면 [request] 가 영영 끝나지 않는다 (멎은 플랫폼 채널).
  final bool requestNeverAnswers;

  /// [openSettings] 가 돌려줄 값.
  final bool openSettingsResult;

  /// [status] 가 불린 횟수.
  int statusCalls = 0;

  /// [request] 가 불린 횟수 — 0 이면 OS 에 한 번도 묻지 않았다는 뜻이다.
  int requestCalls = 0;

  /// [openSettings] 가 불린 횟수 — 0 이면 설정 화면을 연 적이 없다는 뜻이다.
  int openSettingsCalls = 0;

  @override
  Future<LocationPermissionStatus> status() async {
    statusCalls++;
    if (statusNeverAnswers) return Completer<LocationPermissionStatus>().future;
    final error = statusError;
    if (error != null) throw error;
    return _status;
  }

  @override
  Future<LocationPermissionStatus> request() async {
    requestCalls++;
    if (requestNeverAnswers) {
      return Completer<LocationPermissionStatus>().future;
    }
    final error = requestError;
    if (error != null) throw error;
    _status = _afterRequest;
    return _status;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return openSettingsResult;
  }
}
