/// task 2.5 — 지도 view-state 위젯/단위 테스트 (R9·R10).
///
/// 네이티브 SDK 미로딩: 실제 NaverMap 은 절대 생성하지 않는다. map_view surface seam 을
/// fake builder 로 대체 pump 하고, 데이터/위치는 provider override 로 주입한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/map/map_controller.dart';
import 'package:kbo_away_fans/features/map/map_domain.dart';
import 'package:kbo_away_fans/features/map/map_screen.dart';
import 'package:kbo_away_fans/features/map/map_view.dart';
import 'package:kbo_away_fans/features/stamp/location_provider.dart';
import 'package:kbo_away_fans/features/stamp/stamp_models.dart';
import 'package:kbo_away_fans/features/stamp/stamp_repository.dart';
import 'package:kbo_away_fans/features/stamp/stadium_repository.dart';

import '../stamp/fakes.dart';

const _surfaceKey = Key('fake-map-surface');

/// map_view surface 대체 구현 — 전달받은 surface 데이터를 노출하는 fake. 네이티브 미접촉.
class _RecordingSurface {
  MapSurfaceData? received;

  Widget build(BuildContext context, MapSurfaceData data) {
    received = data;
    return Container(key: _surfaceKey);
  }
}

List<StampStadium> _stadiums() => [
      for (var i = 0; i < 3; i++)
        StampStadium(
          id: 's$i',
          name: 's$i',
          lat: 37.0 + i,
          lng: 127.0 + i,
          stampRadiusM: 500,
          teamId: 't$i',
          teamAbbr: 'A$i',
        ),
    ];

Stamp _stamp(String stadiumId, DateTime at) => Stamp(
      id: 'st-$stadiumId',
      userId: 'u',
      stadiumId: stadiumId,
      lat: 37,
      lng: 127,
      stampedAt: at,
    );

/// 방문 2칸 (s0 먼저, s1 나중) → 경로 길이 2.
List<Stamp> _twoVisited() => [
      _stamp('s0', DateTime(2026, 7, 1)),
      _stamp('s1', DateTime(2026, 7, 2)),
    ];

Widget _app({
  required StadiumRepository stadiumRepo,
  required StampRepository stampRepo,
  LocationResult location = const LocationServiceDisabled(),
  MapSurfaceBuilder? surfaceBuilder,
  MapRouteAnimationObserver? observer,
}) {
  return ProviderScope(
    overrides: [
      stadiumRepositoryProvider.overrideWithValue(stadiumRepo),
      stampRepositoryProvider.overrideWithValue(stampRepo),
      currentLocationProvider.overrideWith((ref) async => location),
      if (observer != null)
        mapRouteAnimationObserverProvider.overrideWithValue(observer),
    ],
    child: MaterialApp(
      home: MapView(
        clientId: 'real-client-id',
        surfaceBuilder:
            surfaceBuilder ?? (context, data) => Container(key: _surfaceKey),
      ),
    ),
  );
}

void main() {
  testWidgets(
      '위치 권한 거부 → 내위치=off + 안내 메시지≠null, 마커·경로는 정상 (R9)',
      (tester) async {
    final surface = _RecordingSurface();
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _stadiums()),
      stampRepo: FakeStampRepository(initial: _twoVisited()),
      location: const LocationPermissionDenied(permanently: false),
      surfaceBuilder: surface.build,
    ));
    await tester.pumpAndSettle();

    expect(surface.received, isNotNull);
    expect(surface.received!.myLocation.enabled, isFalse);
    expect(surface.received!.myLocation.message, isNotNull);
    // 마커·경로는 정상 표시.
    expect(surface.received!.markers, isNotEmpty);
    expect(surface.received!.route, hasLength(2));
  });

  testWidgets('위치 획득 → 내위치=on + 좌표, 안내 메시지 없음 (R9)', (tester) async {
    final surface = _RecordingSurface();
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _stadiums()),
      stampRepo: FakeStampRepository(initial: _twoVisited()),
      location: const LocationAcquired(lat: 37.5, lng: 127.5),
      surfaceBuilder: surface.build,
    ));
    await tester.pumpAndSettle();

    expect(surface.received!.myLocation.enabled, isTrue);
    expect(surface.received!.myLocation.lat, 37.5);
    expect(surface.received!.myLocation.lng, 127.5);
    expect(surface.received!.myLocation.message, isNull);
  });

  testWidgets('방문 ≥2 로 진입 → 경로 애니 트리거 1회 발화 (R10)', (tester) async {
    final calls = <List<(double, double)>>[];
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _stadiums()),
      stampRepo: FakeStampRepository(initial: _twoVisited()),
      location: const LocationAcquired(lat: 37.5, lng: 127.5),
      observer: calls.add,
    ));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(
      calls.first,
      buildStadiumRouteSequence(stadiums: _stadiums(), stamps: _twoVisited()),
    );
  });

  testWidgets('방문 ≤1 로 진입 → 경로 애니 트리거 미발화 (R10)', (tester) async {
    final calls = <List<(double, double)>>[];
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _stadiums()),
      stampRepo: FakeStampRepository(initial: [_stamp('s0', DateTime(2026, 7, 1))]),
      location: const LocationAcquired(lat: 37.5, lng: 127.5),
      observer: calls.add,
    ));
    await tester.pumpAndSettle();

    expect(calls, isEmpty);
  });

  testWidgets('화면을 떠났다 재진입하면 트리거가 다시 발화한다 (R10)', (tester) async {
    final calls = <List<(double, double)>>[];

    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _stadiums()),
      stampRepo: FakeStampRepository(initial: _twoVisited()),
      location: const LocationAcquired(lat: 37.5, lng: 127.5),
      observer: calls.add,
    ));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));

    // 화면을 떠난다 (대체 위젯).
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    // 재진입.
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _stadiums()),
      stampRepo: FakeStampRepository(initial: _twoVisited()),
      location: const LocationAcquired(lat: 37.5, lng: 127.5),
      observer: calls.add,
    ));
    await tester.pumpAndSettle();

    expect(calls, hasLength(2)); // 재발화.
  });

  testWidgets('경로 좌표는 Task 2.2 시퀀스 로직 결과를 map_view 로 전달한다 (R10)',
      (tester) async {
    final surface = _RecordingSurface();
    final stadiums = _stadiums();
    final stamps = _twoVisited();
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: stadiums),
      stampRepo: FakeStampRepository(initial: stamps),
      location: const LocationAcquired(lat: 37.5, lng: 127.5),
      surfaceBuilder: surface.build,
    ));
    await tester.pumpAndSettle();

    expect(
      surface.received!.route,
      buildStadiumRouteSequence(stadiums: stadiums, stamps: stamps),
    );
  });

  testWidgets('마커·경로 조회 실패 → 빈 지도가 아니라 오류+재시도, 해제 후 재시도로 렌더 (R9)',
      (tester) async {
    final surface = _RecordingSurface();
    final stampFake = FakeStampRepository()
      ..listError = const StampNetworkException();
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _stadiums()),
      stampRepo: stampFake,
      location: const LocationAcquired(lat: 37.5, lng: 127.5),
      surfaceBuilder: surface.build,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(MapErrorView), findsOneWidget);
    expect(find.byKey(_surfaceKey), findsNothing); // 빈 지도(surface) 아님.
    expect(surface.received, isNull);

    // 재시도: 에러 해제 후 탭하면 지도 표면이 렌더된다.
    stampFake.listError = null;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(surface.received, isNotNull);
  });
}
