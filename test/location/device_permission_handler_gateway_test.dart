/// 실 게이트웨이(`DevicePermissionHandlerGateway`) **그 자체**를 돌린다.
///
/// 이 자리가 서기 전까지 phase 2 에서 실 구현에 닿는 시험은 하나도 없었다 —
/// 매핑을 통째로 상수로 바꾸거나, 묻는 권한을 "항상 허용"(`Permission.location`)
/// 으로 바꾸거나, 영구 거절 매핑을 지워도 `flutter test` 는 전부 초록불이었다.
/// 앞의 것은 화면이 상태를 잘못 읽는 문제이고, 가운데 것은 되돌리기 비용 **L**
/// 의 제품 결정(`.wellbegun/decisions.md` 2026-09-01 [L]: 백그라운드 위치는
/// 쓰지 않는다)이 코드에서 깨지는 문제다.
///
/// 플랫폼 인터페이스를 갈아 끼워 실 구현을 돌리는 방식은
/// `test/backend/app_check_activation_test.dart`·
/// `test/backend/firebase_auth_service_adversarial_probe_test.dart` 의 선례와
/// 같다 — 실기기 채널을 타지 않으면서 우리 코드의 모든 줄을 실제로 지난다.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// 상한이 **있다면** 그 안에는 끝나야 하는 시간 — 아래 "답하지 않아도 상한에서
/// 끝난다"가 미는 시간이다. `kLocationPermissionTimeout` 에서 세지 않는 것은,
/// 그러면 상수를 키우는 변이가 미는 시간까지 함께 키워 그 케이스가 어떤 값도
/// 지키지 못하기 때문이다. 값 자체는 '사람을 붙잡는 상한이 실제로 사람이 견딜
/// 길이다'가 따로 잰다.
const Duration _generousLocationBound = Duration(seconds: 10);

/// 상한 **앞**을 딛는 시간 — 이만큼 밀어도 아직 답이 없어야 "기다린다"가 참이다.
const Duration _beforeAnyBound = Duration(seconds: 1);

/// `permission_handler` 가 실제로 무엇을 물었는지 기록하는 플랫폼 대역.
class _RecordingPermissionHandler extends PermissionHandlerPlatform {
  /// [checkPermissionStatus] 로 물어본 권한들 (순서대로).
  final List<Permission> checked = <Permission>[];

  /// [requestPermissions] 로 요청한 권한 묶음들 (순서대로).
  final List<List<Permission>> requested = <List<Permission>>[];

  /// 플랫폼이 돌려줄 상태.
  PermissionStatus reply = PermissionStatus.denied;

  /// null 이 아니면 플랫폼이 이 오류를 던진다.
  Object? error;

  /// 참이면 플랫폼이 영영 답하지 않는다 (멎은 채널).
  bool neverAnswers = false;

  Future<T> _answer<T>(T value) {
    if (neverAnswers) return Completer<T>().future;
    final failure = error;
    if (failure != null) return Future<T>.error(failure);
    return Future<T>.value(value);
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) {
    checked.add(permission);
    return _answer(reply);
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) {
    requested.add(permissions);
    return _answer(<Permission, PermissionStatus>{
      for (final permission in permissions) permission: reply,
    });
  }
}

void main() {
  late PermissionHandlerPlatform original;
  late _RecordingPermissionHandler platform;
  const gateway = DevicePermissionHandlerGateway();

  setUp(() {
    original = PermissionHandlerPlatform.instance;
    platform = _RecordingPermissionHandler();
    PermissionHandlerPlatform.instance = platform;
  });

  tearDown(() => PermissionHandlerPlatform.instance = original);

  group('묻는 권한은 "앱 사용 중" 하나뿐이다', () {
    // 되돌리기 비용 L 의 결정을 코드에서 재는 자리다. `Permission.location` 은
    // 안드로이드의 `ACCESS_BACKGROUND_LOCATION`·iOS 의 "항상 허용"까지 요구해
    // 거부율과 심사 부담을 지는데, 이 앱의 구장 방문 확인은 포그라운드
    // 판정뿐이라 그 권한을 물을 이유가 없다.

    test('status() 는 locationWhenInUse 만 조회한다', () async {
      await gateway.status();

      expect(platform.checked, <Permission>[Permission.locationWhenInUse]);
      expect(
        platform.checked,
        isNot(contains(Permission.location)),
        reason: '백그라운드 위치는 쓰지 않는다 (decisions.md 2026-09-01 [L])',
      );
    });

    test('request() 는 locationWhenInUse 만 요청한다', () async {
      await gateway.request();

      expect(platform.requested, <List<Permission>>[
        <Permission>[Permission.locationWhenInUse],
      ]);
      expect(
        platform.requested.expand((each) => each),
        isNot(contains(Permission.location)),
        reason: '"항상 허용"을 묻는 순간 L 결정이 코드에서 깨진다',
      );
      expect(platform.checked, isEmpty, reason: '요청은 조회를 대신 부르지 않는다');
    });
  });

  group('플랫폼 상태를 이 계층의 세 갈래로 옮긴다', () {
    // 실 구현이 무엇을 돌려주는지 재는 유일한 자리다 — 매핑이 통째로 상수가
    // 되어도, permanentlyDenied 가 denied 로 접혀도 여기 말고는 드러나지
    // 않는다. permanentlyDenied 가 접히면 acceptance 의 "이미 거절한 상태에서는
    // 다시 묻지 않는다"가 실 구현 쪽에서 거짓이 된다(화면은 denied 를 "아직
    // 물어볼 수 있다"로 읽어 설명을 다시 띄운다).
    const cases = <PermissionStatus, LocationPermissionStatus>{
      PermissionStatus.granted: LocationPermissionStatus.granted,
      PermissionStatus.limited: LocationPermissionStatus.granted,
      PermissionStatus.provisional: LocationPermissionStatus.granted,
      PermissionStatus.permanentlyDenied:
          LocationPermissionStatus.permanentlyDenied,
      PermissionStatus.denied: LocationPermissionStatus.denied,
      PermissionStatus.restricted: LocationPermissionStatus.denied,
    };

    for (final entry in cases.entries) {
      test('${entry.key.name} → ${entry.value.name}', () async {
        platform.reply = entry.key;

        expect(await gateway.status(), entry.value);
        expect(await gateway.request(), entry.value);
      });
    }
  });

  group('실패 계약 — 던지지 않고, 상한 안에 답한다', () {
    test('플랫폼이 던져도 예외가 아니라 denied 로 답한다', () async {
      platform.error = PlatformException(code: 'channel-error');

      expect(await gateway.status(), LocationPermissionStatus.denied);
      expect(await gateway.request(), LocationPermissionStatus.denied);
    });

    test('플랫폼이 답하지 않아도 상한에서 denied 로 끝난다', () {
      platform.neverAnswers = true;

      fakeAsync((async) {
        LocationPermissionStatus? answered;
        unawaited(gateway.status().then((value) => answered = value));

        async.elapse(_beforeAnyBound);
        async.flushMicrotasks();
        expect(answered, isNull, reason: '상한 전에는 답을 기다린다');

        async.elapse(_generousLocationBound);
        async.flushMicrotasks();
        expect(answered, LocationPermissionStatus.denied);
      });
    });

    test('사람을 붙잡는 상한이 실제로 사람이 견딜 길이다', () {
      // 바로 위 케이스는 상한이 **있는지**만 잰다. 그 시간을 상수에서 세지
      // 않는 것은(처음에는 `kLocationPermissionTimeout ± 1초` 였다) 상수를
      // 키우는 변이가 미는 시간까지 함께 키워 아무것도 지키지 못하기 때문이다 —
      // `kCachedTeamReadTimeout` 이 실제로 그 함정에 걸려 있었다
      // (`team_select_test.dart` 의 `_generousCacheBound` 주석 참조).
      //
      // 이 값은 곧 팀 선택을 막 마친 사람이 문구 하나 없는 대기 화면 앞에
      // 앉아 있는 최대 시간이고, 설명 화면에서 "허용하기"를 누른 뒤 아무 일도
      // 일어나지 않는 것처럼 보이는 최대 시간이다. 길이 자체가 계약이므로
      // 여기서 못 박는다 — 짝인 `kAppCheckActivationTimeout`·
      // `kProfileServerConfirmGrace`·`kCachedTeamReadTimeout` 에 같은 모양의
      // 시험이 서 있다.
      expect(kLocationPermissionTimeout, greaterThan(Duration.zero));
      expect(
        kLocationPermissionTimeout,
        lessThanOrEqualTo(const Duration(seconds: 10)),
        reason: '늘리면 그만큼 온보딩 직후의 대기 화면이 길어진다 — 그 화면에는 '
            '문구도 되돌아갈 길도 없다',
      );
    });
  });
}
