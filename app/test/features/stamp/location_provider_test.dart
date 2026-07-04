import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/stamp/location_provider.dart';

/// 테스트용 fake — 플러그인 없이 각 분기를 재현한다 (R11).
class FakeLocationClient implements LocationClient {
  FakeLocationClient({
    this.serviceEnabled = true,
    this.permission = LocationPermissionStatus.granted,
    this.position = (lat: 37.4967, lng: 126.8673),
    this.positionDelay,
    this.neverCompletes = false,
  });

  final bool serviceEnabled;
  final LocationPermissionStatus permission;
  final ({double lat, double lng}) position;
  final Duration? positionDelay;
  final bool neverCompletes;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermissionStatus> checkAndRequestPermission() async =>
      permission;

  @override
  Future<({double lat, double lng})> getPosition() {
    if (neverCompletes) return Completer<({double lat, double lng})>().future;
    if (positionDelay != null) {
      return Future.delayed(positionDelay!, () => position);
    }
    return Future.value(position);
  }
}

ProviderContainer containerWith(LocationClient client) {
  final container = ProviderContainer(
    overrides: [locationClientProvider.overrideWithValue(client)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('좌표 획득 — mock 좌표가 LocationAcquired 로 반환된다', () async {
    final container = containerWith(
      FakeLocationClient(position: (lat: 35.1, lng: 129.06)),
    );
    final result = await container.read(currentLocationProvider.future);
    expect(result, isA<LocationAcquired>());
    final acquired = result as LocationAcquired;
    expect(acquired.lat, 35.1);
    expect(acquired.lng, 129.06);
  });

  test('권한 거부 — LocationPermissionDenied(permanently: false)', () async {
    final container = containerWith(
      FakeLocationClient(permission: LocationPermissionStatus.denied),
    );
    final result = await container.read(currentLocationProvider.future);
    expect(result, isA<LocationPermissionDenied>());
    expect((result as LocationPermissionDenied).permanently, isFalse);
  });

  test('권한 영구 거부 — LocationPermissionDenied(permanently: true)', () async {
    final container = containerWith(
      FakeLocationClient(permission: LocationPermissionStatus.deniedForever),
    );
    final result = await container.read(currentLocationProvider.future);
    expect(result, isA<LocationPermissionDenied>());
    expect((result as LocationPermissionDenied).permanently, isTrue);
  });

  test('위치 서비스 꺼짐 — LocationServiceDisabled', () async {
    final container = containerWith(
      FakeLocationClient(serviceEnabled: false),
    );
    final result = await container.read(currentLocationProvider.future);
    expect(result, isA<LocationServiceDisabled>());
  });

  test('타임아웃 상수가 유한한 수 초 수준이다', () {
    expect(kLocationFixTimeout, greaterThan(Duration.zero));
    expect(kLocationFixTimeout, lessThanOrEqualTo(const Duration(seconds: 15)));
  });

  test('fix 미획득(무한 지연) — kLocationFixTimeout 후 LocationTimeout', () {
    fakeAsync((async) {
      final container = containerWith(FakeLocationClient(neverCompletes: true));
      LocationResult? result;
      container
          .read(currentLocationProvider.future)
          .then((r) => result = r);
      async.flushMicrotasks();
      // 타임아웃 직전까지는 결과가 없다 (무한 로딩 아님을 시계로 확인).
      async.elapse(kLocationFixTimeout - const Duration(milliseconds: 1));
      expect(result, isNull);
      async.elapse(const Duration(milliseconds: 2));
      async.flushMicrotasks();
      expect(result, isA<LocationTimeout>());
    });
  });

  test('타임아웃 이내 지연 fix 는 정상 획득된다', () {
    fakeAsync((async) {
      final container = containerWith(
        FakeLocationClient(positionDelay: const Duration(seconds: 2)),
      );
      LocationResult? result;
      container
          .read(currentLocationProvider.future)
          .then((r) => result = r);
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(result, isA<LocationAcquired>());
    });
  });
}
