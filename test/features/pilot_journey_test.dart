/// Step 5.2 시범 구장(잠실) 실데이터 통합 테스트 —
/// `content-pipeline/data/*.json` 실물 픽스처로 앱의 전체 여정
/// (홈 → 추천 목록 → 상세 → 지도)이 걸어지는지 확인한다.
///
/// schedule 만 시나리오용 합성(다음 원정 = 잠실)이고, teams/stadiums/places 는
/// 저장소 실데이터를 그대로 파싱해 주입한다 (계약·큐레이션 드리프트 방지).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/analytics/analytics.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/features/places/place_map_screen.dart';
import 'package:kbo_away_fans/features/places/stadium_places_screen.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';
import 'package:kbo_away_fans/ui/shared/place_detail_sheet.dart';
import 'package:kbo_away_fans/ui/shared/stadium_map_view.dart';
import 'package:kbo_away_fans/weather/weather.dart';

import '../analytics/recording_analytics.dart';

/// 시범 구장 — content-pipeline/CURATION.md 의 잠실.
const String pilotStadiumId = 'jamsil';

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  late TeamsDocument teamsDoc;
  late StadiumsDocument stadiumsDoc;
  late PlacesDocument placesDoc;

  setUpAll(() {
    teamsDoc = TeamsDocument.fromJson(
      _readJson('content-pipeline/data/teams.json'),
    );
    stadiumsDoc = StadiumsDocument.fromJson(
      _readJson('content-pipeline/data/stadiums.json'),
    );
    placesDoc = PlacesDocument.fromJson(
      _readJson('content-pipeline/data/places.json'),
    );
  });

  group('시범 구장 실데이터 커버리지 (플랜B 성립 조건)', () {
    test('장소 10건 이상, 카테고리 3종 이상, 실내 3건 이상', () {
      final pilot = placesDoc.forStadium(pilotStadiumId);
      expect(pilot.length, greaterThanOrEqualTo(10));
      expect(
        pilot.map((p) => p.category).toSet().length,
        greaterThanOrEqualTo(3),
      );
      expect(
        pilot.where((p) => p.indoor).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('전 장소 좌표가 유효 범위(한반도 bounding box) 안이다', () {
      // 파서(_latitude/_longitude)가 이미 강제하지만, 시범 구장 데이터에
      // 대한 경계 조건을 명시적으로 남긴다.
      for (final place in placesDoc.places) {
        expect(place.lat, inInclusiveRange(33, 39), reason: place.id);
        expect(place.lng, inInclusiveRange(124, 132), reason: place.id);
      }
    });
  });

  testWidgets('실데이터 여정: 홈 → 전체 보기 → 추천 목록 → 상세 시트 → 지도',
      (tester) async {
    // 다음 원정 = 잠실 (LG 홈) — 홈이 잠실 미리보기를 보여주는 시나리오.
    final scheduleDoc = ScheduleDocument(
      generatedAt: DateTime.utc(2026),
      games: [
        const Game(
          id: '2026-08-30-jamsil-lotte-lg',
          date: '2026-08-30',
          startTime: '17:00',
          homeTeamId: 'lg',
          awayTeamId: 'lotte',
          stadiumId: pilotStadiumId,
          status: GameStatus.scheduled,
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          () => DateTime.parse('2026-08-25T14:00:00+09:00'),
        ),
        weatherEffectProvider.overrideWith(
          (ref, point) async => WeatherEffect.none,
        ),
        teamsProvider.overrideWith(
          (ref) async => ContentFresh<TeamsDocument>(teamsDoc),
        ),
        stadiumsProvider.overrideWith(
          (ref) async => ContentFresh<StadiumsDocument>(stadiumsDoc),
        ),
        placesProvider.overrideWith(
          (ref) async => ContentFresh<PlacesDocument>(placesDoc),
        ),
        scheduleProvider.overrideWith(
          (ref) async => ContentFresh<ScheduleDocument>(scheduleDoc),
        ),
        analyticsProvider.overrideWithValue(RecordingAnalytics()),
      ],
      child: const MaterialApp(home: HomeScreen(teamId: 'lotte')),
    ));
    await tester.pumpAndSettle();

    // 홈 — 잠실 원정 미리보기에 실데이터 장소가 뜬다.
    expect(find.text('D-5'), findsOneWidget);
    expect(find.text('부농정육식당', skipOffstage: false), findsOneWidget);

    // 전체 보기 → 추천 목록 (실데이터 장소 카드).
    await tester.ensureVisible(find.text('전체 보기', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(StadiumPlacesScreen), findsOneWidget);
    expect(find.byType(PlaceCard), findsWidgets);
    // 샤라웃 뱃지 — 큐레이션의 실제 출처 문구가 그대로 렌더된다.
    expect(
      find.descendant(
        of: find.widgetWithText(PlaceCard, '부농정육식당'),
        matching: find.textContaining('에스콰이어'),
      ),
      findsOneWidget,
    );

    // 카드 탭 → 상세 시트.
    await tester.tap(find.widgetWithText(PlaceCard, '부농정육식당'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailSheet), findsOneWidget);
    expect(find.text('지도에서 보기'), findsOneWidget);

    // 지도 진입 — 구장·장소 마커(테스트 환경은 mock 자리 표시 래퍼).
    await tester.tap(find.text('지도에서 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceMapScreen), findsOneWidget);
    final mapView = find.byType(StadiumMapView);
    expect(
      find.descendant(of: mapView, matching: find.text('부농정육식당')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mapView, matching: find.text('잠실야구장')),
      findsOneWidget,
    );
  });
}
