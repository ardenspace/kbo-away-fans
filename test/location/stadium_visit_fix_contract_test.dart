/// 판정기 provider 와 **실 측위 함수**(`visit_check.dart` 의 private
/// `_readDeviceFix`)를 그대로 돌린다.
///
/// 이 자리가 서기 전까지 그 함수에 닿는 시험은 하나도 없었다 — 바깥
/// `.timeout` 을 지워도, `catch (_)` 를 좁혀 SDK 예외가 새게 해도, 플러그인에
/// 넘기는 `timeLimit` 을 빼도 저장소 전체가 초록불이었다. `lib/location/` 의
/// 실패 계약("던지지 않고, 상한 안에 답하며, 알아내지 못한 실행은 `null`")을
/// 실행하는 자리가 둘인데 그중 하나가 무방비였다는 뜻이다. 짝은
/// `device_permission_handler_gateway_test.dart` 이고 방식도 같다: 플러그인의
/// **플랫폼 인터페이스**를 갈아 끼워 실기기 채널을 타지 않으면서 우리 코드의
/// 모든 줄을 지난다.
///
/// **좌표를 얻는 새 공개 통로를 만들지 않으려고 이 방식을 골랐다.** 측위
/// 함수를 시험이 부를 수 있게 공개 이음매로 뽑아내면 그것이 곧 어느 계층에서든
/// 좌표를 얻는 자리가 되는데, 그 모양의 결함을 4.1 의 fresh 검증 round 1 이
/// 이미 잡았다(`.wellbegun/decisions.md` 2026-09-04 `[M]`). 플랫폼 인터페이스는
/// `lib/` 에 아무것도 더하지 않는다.
///
/// 함께 재는 것: **이 폴더는 권한을 다시 묻지 않는다**는
/// `lib/location/CLAUDE.md` 의 규칙. `stadiumVisitCheckerProvider` 가
/// `LocationPermissionGateway.status`(다이얼로그 없는 조회) 대신
/// `request` 를 쥐면 경기가 있는 날마다 앱을 열 때 OS 다이얼로그가 뜨는데,
/// 그 한 글자를 지키는 자리가 없었다.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';

import 'fake_location_permission_gateway.dart';

/// 잠실야구장 좌표 — 반경 안/밖을 가르는 기준점.
const double _jamsilLat = 37.5121;
const double _jamsilLng = 127.0719;

/// 상한이 **있다면** 그 안에는 끝나야 하는 시간. `kLocationFixTimeout` 에서
/// 세지 않는 것은 상수를 키우는 변이가 미는 시간까지 함께 키워 아무것도
/// 지키지 못하기 때문이다(짝 시험 `device_permission_handler_gateway_test.dart`
/// 의 `_generousLocationBound` 와 같은 까닭). 길이 자체는 아래 '상한의 길이'
/// 케이스가 따로 못 박는다.
const Duration _generousFixBound = Duration(seconds: 30);

/// 상한 **앞**을 딛는 시간 — 이만큼 밀어도 답이 없어야 "기다린다"가 참이다.
const Duration _beforeAnyBound = Duration(seconds: 1);

/// 기준 시각: 2026-08-25(화) 잠실 18:30 경기의 1시간 전.
final DateTime _duringPregame = DateTime.parse('2026-08-25T17:30:00+09:00');

StadiumVisitCandidate _jamsilTonight() => StadiumVisitCandidate(
  gameId: 'g-jamsil',
  stadiumId: 'jamsil',
  startsAt: DateTime.parse('2026-08-25T18:30:00+09:00'),
  lat: _jamsilLat,
  lng: _jamsilLng,
);

Position _positionAt(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.utc(2026, 8, 25, 8, 30),
  accuracy: 12,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// `geolocator` 가 실제로 무엇을 물었는지 기록하는 플랫폼 대역.
class _RecordingGeolocator extends GeolocatorPlatform {
  /// [getCurrentPosition] 이 불린 횟수 — 0 이면 OS 에 측위를 묻지 않았다.
  int fixCalls = 0;

  /// 마지막 호출이 플러그인에 넘긴 설정 — 플러그인 자신의 상한을 재는 자리.
  LocationSettings? lastSettings;

  /// 플랫폼이 돌려줄 지점.
  Position? reply;

  /// null 이 아니면 플랫폼이 이 오류를 던진다.
  Object? error;

  /// 참이면 플랫폼이 영영 답하지 않는다 (멎은 채널 — `timeLimit` 을 스스로
  /// 지키지 않는 구현이기도 하다).
  bool neverAnswers = false;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    fixCalls++;
    lastSettings = locationSettings;
    if (neverAnswers) return Completer<Position>().future;
    final failure = error;
    if (failure != null) return Future<Position>.error(failure);
    return Future<Position>.value(reply ?? _positionAt(_jamsilLat, _jamsilLng));
  }
}

void main() {
  late GeolocatorPlatform original;
  late _RecordingGeolocator platform;

  setUp(() {
    original = GeolocatorPlatform.instance;
    platform = _RecordingGeolocator();
    GeolocatorPlatform.instance = platform;
  });

  tearDown(() => GeolocatorPlatform.instance = original);

  /// 실 판정기(`stadiumVisitCheckerProvider`)를 돌려주는 컨테이너 — 갈아 끼우는
  /// 것은 **권한 게이트웨이 하나**이고, 측위는 실 코드 그대로 간다.
  StadiumVisitChecker checkerWith(FakeLocationPermissionGateway gateway) {
    final container = ProviderContainer(
      overrides: [locationPermissionGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    return container.read(stadiumVisitCheckerProvider);
  }

  Future<StadiumVisitResult> judge(StadiumVisitChecker checker) =>
      checker.check(candidates: [_jamsilTonight()], now: _duringPregame);

  group('권한은 조회로만 묻는다 — 이 폴더는 권한을 다시 묻지 않는다', () {
    // `lib/location/CLAUDE.md` 의 규칙을 재는 자리다. `readPermission` 이
    // `gateway.status` 에서 `gateway.request` 로 바뀌면 경기가 있는 날마다 앱을
    // 열 때 OS 다이얼로그가 뜬다 — 2.5 가 온보딩에서 한 번 묻고 끝내기로 한
    // 결정(decisions.md 2026-09-01 [M])이 코드에서 깨지는 변이인데, 이 시험이
    // 서기 전에는 저장소 전체 644개가 그대로 초록불이었다.

    test('허용된 사람에게도 status 만 부른다', () async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.granted,
      );

      await judge(checkerWith(gateway));

      expect(gateway.statusCalls, 1);
      expect(gateway.requestCalls, 0, reason: '판정은 OS 다이얼로그를 띄우지 않는다');
    });

    test('거절한 사람에게 다시 묻지 않는다 — 판정을 시도하지도 않는다', () async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.denied,
        afterRequest: LocationPermissionStatus.granted,
      );

      final result = await judge(checkerWith(gateway));

      expect(result.reason, StadiumVisitReason.permissionMissing);
      expect(gateway.requestCalls, 0, reason: '다시 묻는 진입점은 아직 저장소에 없다');
      expect(platform.fixCalls, 0, reason: '권한이 없으면 좌표를 읽지 않는다');
    });

    test('판정할 경기가 없으면 권한도 좌표도 묻지 않는다', () async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.granted,
      );

      final result = await checkerWith(
        gateway,
      ).check(candidates: const [], now: _duringPregame);

      expect(result.reason, StadiumVisitReason.noGameToday);
      expect(gateway.statusCalls, 0);
      expect(platform.fixCalls, 0);
    });
  });

  group('실 측위가 판정에 들어간다', () {
    late FakeLocationPermissionGateway gateway;

    setUp(() {
      gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.granted,
      );
    });

    test('플랫폼이 돌려준 지점이 구장 반경 안이면 방문이다', () async {
      platform.reply = _positionAt(_jamsilLat, _jamsilLng);

      final result = await judge(checkerWith(gateway));

      expect(result.reason, StadiumVisitReason.visited);
      expect(result.stadiumId, 'jamsil');
      expect(platform.fixCalls, 1);
    });

    test('플랫폼이 돌려준 지점이 반경 밖이면 방문이 아니다', () async {
      // 정북으로 약 5km — 위도·경도를 바꿔 싣는 변이도 여기서 갈린다.
      platform.reply = _positionAt(_jamsilLat + 0.045, _jamsilLng);

      final result = await judge(checkerWith(gateway));

      expect(result.reason, StadiumVisitReason.outsideRadius);
    });

    test('플러그인 자신의 상한도 함께 건넨다 — 두 겹 중 안쪽', () async {
      await judge(checkerWith(gateway));

      expect(platform.lastSettings, isNotNull);
      expect(
        platform.lastSettings!.timeLimit,
        kLocationFixTimeout,
        reason: '안쪽 상한이 빠지면 답하지 않는 채널을 바깥 상한 혼자 받는다',
      );
      expect(
        platform.lastSettings!.accuracy,
        LocationAccuracy.high,
        reason: '구장 반경 300m 판정에 쓰는 정밀도다',
      );
    });
  });

  group('실패 계약 — 던지지 않고, 상한 안에 답한다', () {
    late FakeLocationPermissionGateway gateway;

    setUp(() {
      gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.granted,
      );
    });

    // 무엇이 오든 null 하나로 접는다 — 판정은 그것을 locationUnavailable 로
    // 받는다. `catch (_)` 를 좁히면(예: TimeoutException 만 받게) SDK 예외가
    // 판정기 밖으로 새어 나가 트리거의 `unawaited` 안에서 아무도 받지 않는다.
    final failures = <String, Object>{
      '플랫폼 채널 오류': PlatformException(code: 'channel-error'),
      '위치 서비스 꺼짐': const LocationServiceDisabledException(),
      '권한 거부(플러그인 쪽)': const PermissionDeniedException('denied'),
      '플러그인의 상한 초과': TimeoutException('plugin timeLimit'),
    };

    for (final entry in failures.entries) {
      test('${entry.key} → 던지지 않고 locationUnavailable', () async {
        platform.error = entry.value;

        final result = await judge(checkerWith(gateway));

        expect(result.reason, StadiumVisitReason.locationUnavailable);
        expect(result.isVisit, isFalse);
      });
    }

    test('플랫폼이 답하지 않아도 상한에서 locationUnavailable 로 끝난다', () {
      // 플러그인 자신의 `timeLimit` 을 지키지 않는 구현을 흉내 낸다 — 바깥
      // `.timeout` 이 있는 까닭이 그것이다(구현이 계약을 지키는지 부르는 쪽은
      // 모른다). 그 한 줄을 지우면 이 케이스가 영영 답을 받지 못한다.
      platform.neverAnswers = true;

      fakeAsync((async) {
        StadiumVisitResult? answered;
        unawaited(judge(checkerWith(gateway)).then((value) => answered = value));

        async.elapse(_beforeAnyBound);
        async.flushMicrotasks();
        expect(answered, isNull, reason: '상한 전에는 측위를 기다린다');

        async.elapse(_generousFixBound);
        async.flushMicrotasks();
        expect(answered?.reason, StadiumVisitReason.locationUnavailable);
      });
    });

    test('측위 상한의 길이는 아무 화면도 붙잡지 않는 기다림의 길이다', () {
      // 바로 위 케이스는 상한이 **있는지**만 잰다. 길이 자체는 계약이라 여기서
      // 못 박는다 — 짧게 줄이면(다른 네 상한과 같은 5초로 맞추면) 콜드 스타트의
      // 첫 측위가 잘려 "구장에 있는데 도장이 없다"가 일상이 되고, 길게 늘리면
      // 판정이 도는 동안 위치 센서가 그만큼 오래 켜져 있다.
      expect(kLocationFixTimeout, greaterThan(kLocationPermissionTimeout));
      expect(kLocationFixTimeout, lessThanOrEqualTo(const Duration(seconds: 20)));
    });
  });
}
