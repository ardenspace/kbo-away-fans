import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/features/badges/stadium_visit.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';
import 'package:kbo_away_fans/ui/shared/journey_status_visual.dart';
import 'package:kbo_away_fans/ui/shared/journey_ticket.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';
import 'package:kbo_away_fans/weather/weather.dart';

import '../../location/fake_location_permission_gateway.dart';

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

class _FixedVisit extends StadiumVisitCheck {
  _FixedVisit(this.value);

  final StadiumVisitResult? value;

  void inject(StadiumVisitResult? next) => state = next;

  @override
  StadiumVisitResult? build() => value;

  @override
  Future<void> run() async {}
}

class _FixedVisitRun extends StadiumVisitRunLog {
  _FixedVisitRun(this.value);

  final StadiumVisitRun? value;

  @override
  StadiumVisitRun? build() => value;
}

void main() {
  late TeamsDocument teams;
  late StadiumsDocument stadiums;
  late PlacesDocument places;

  setUpAll(() {
    teams = TeamsDocument.fromJson(
      _readJson('content-pipeline/data/teams.json'),
    );
    stadiums = StadiumsDocument.fromJson(
      _readJson('content-pipeline/data/stadiums.json'),
    );
    places = PlacesDocument.fromJson(
      _readJson('content-pipeline/data/places.json'),
    );
  });

  Game game({required String date, GameStatus status = GameStatus.scheduled}) =>
      Game(
        id: '$date-jamsil-lotte-lg',
        date: date,
        startTime: '18:30',
        homeTeamId: 'lg',
        awayTeamId: 'lotte',
        stadiumId: 'jamsil',
        status: status,
        homeScore: status == GameStatus.finished ? 2 : null,
        awayScore: status == GameStatus.finished ? 3 : null,
        result: status == GameStatus.finished ? GameResult.awayWin : null,
      );

  Widget home({
    required DateTime now,
    required List<Game> games,
    StadiumVisitResult? visit,
    bool reduceMotion = false,
    DateTime Function()? clock,
    DateTime? visitJudgedAt,
    bool scheduleMissing = false,
    List<Game> Function()? scheduleGames,
  }) {
    final schedule = ScheduleDocument(
      generatedAt: DateTime.utc(2026),
      games: games,
    );
    return ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(clock ?? () => now),
        teamsProvider.overrideWith(
          (ref) async => ContentFresh<TeamsDocument>(teams),
        ),
        stadiumsProvider.overrideWith(
          (ref) async => ContentFresh<StadiumsDocument>(stadiums),
        ),
        placesProvider.overrideWith(
          (ref) async => ContentFresh<PlacesDocument>(places),
        ),
        scheduleProvider.overrideWith((ref) async {
          if (scheduleMissing) throw StateError('probe missing schedule');
          return ContentFresh<ScheduleDocument>(
            scheduleGames == null
                ? schedule
                : ScheduleDocument(
                    generatedAt: DateTime.utc(2026),
                    games: scheduleGames(),
                  ),
          );
        }),
        weatherEffectProvider.overrideWith(
          (ref, point) async => WeatherEffect.none,
        ),
        stadiumVisitProvider.overrideWith(() => _FixedVisit(visit)),
        stadiumVisitRunProvider.overrideWith(
          () => _FixedVisitRun(
            visit == null
                ? null
                : StadiumVisitRun(judged: true, judgedAt: visitJudgedAt ?? now),
          ),
        ),
        locationPermissionGatewayProvider.overrideWithValue(
          FakeLocationPermissionGateway(
            initial: LocationPermissionStatus.denied,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppVisualTheme.resolve(
          favoriteTeamId: 'lotte',
          defaultFamily: AppThemeFamily.a,
          brightness: Brightness.light,
        ).toThemeData(),
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const HomeScreen(teamId: 'lotte'),
      ),
    );
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    required DateTime now,
    required List<Game> games,
    StadiumVisitResult? visit,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      home(now: now, games: games, visit: visit, reduceMotion: reduceMotion),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'P1 cancellation preserves next away game and preview information',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHome(
        tester,
        now: DateTime.parse('2026-08-25T14:00:00+09:00'),
        games: [
          game(date: '2026-08-25', status: GameStatus.canceled),
          game(date: '2026-08-30'),
        ],
      );
      expect(find.text('오늘 경기가 취소됐어요'), findsOneWidget);
      expect(
        find.byType(DdayHeader),
        findsOneWidget,
        reason:
            'Existing home showed the next away game below cancellation banner',
      );
      expect(find.text('D-5'), findsOneWidget);
      expect(find.byType(PlaceCard), findsNWidgets(3));
    },
  );

  testWidgets('P2 open home crosses game start without external rebuild', (
    tester,
  ) async {
    var now = DateTime.parse('2026-08-25T18:29:59+09:00');
    await tester.pumpWidget(
      home(
        now: now,
        clock: () => now,
        games: [game(date: '2026-08-25')],
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<JourneyStatusVisual>(find.byType(JourneyStatusVisual))
          .status,
      JourneyStatus.moving,
    );
    now = DateTime.parse('2026-08-25T18:30:01+09:00');
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<JourneyStatusVisual>(find.byType(JourneyStatusVisual))
          .status,
      JourneyStatus.live,
      reason:
          'Crossing the resolver time boundary should update the same visible home',
    );
  });

  testWidgets(
    'P3 live home retains three existing recommended place previews',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpHome(
        tester,
        now: DateTime.parse('2026-08-25T19:00:00+09:00'),
        games: [game(date: '2026-08-25')],
      );
      expect(places.forStadium('jamsil').length, greaterThanOrEqualTo(3));
      expect(find.byType(PlaceCard), findsNWidgets(3));
    },
  );

  testWidgets('P4 empty schedule renders safe idle information', (
    tester,
  ) async {
    await pumpHome(
      tester,
      now: DateTime.parse('2026-08-25T19:00:00+09:00'),
      games: [],
    );
    expect(find.byType(JourneyStatusVisual), findsNothing);
    expect(find.byType(JourneyTicket), findsNothing);
    expect(find.byType(DdayHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'P5 same mounted home follows injected state changes with reduced motion',
    (tester) async {
      var now = DateTime.parse('2026-08-24T14:00:00+09:00');
      var games = [game(date: '2026-08-25')];
      await tester.pumpWidget(
        home(
          now: now,
          clock: () => now,
          games: games,
          scheduleGames: () => games,
          reduceMotion: true,
        ),
      );
      await tester.pumpAndSettle();
      final homeElement = tester.element(find.byType(HomeScreen));
      expect(find.byType(JourneyTicket), findsOneWidget);
      for (final sample
          in <(String, GameStatus, StadiumVisitResult?, JourneyStatus)>[
            (
              '2026-08-25T16:00:00+09:00',
              GameStatus.scheduled,
              null,
              JourneyStatus.moving,
            ),
            (
              '2026-08-25T16:01:00+09:00',
              GameStatus.scheduled,
              StadiumVisitResult.visited(
                stadiumId: 'jamsil',
                gameId: game(date: '2026-08-25').id,
              ),
              JourneyStatus.nearby,
            ),
            (
              '2026-08-25T19:00:00+09:00',
              GameStatus.scheduled,
              null,
              JourneyStatus.live,
            ),
            (
              '2026-08-25T22:30:00+09:00',
              GameStatus.finished,
              null,
              JourneyStatus.postgame,
            ),
            (
              '2026-08-25T22:31:00+09:00',
              GameStatus.rainCanceled,
              null,
              JourneyStatus.cancelled,
            ),
          ]) {
        now = DateTime.parse(sample.$1);
        games = [game(date: '2026-08-25', status: sample.$2)];
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        container.invalidate(scheduleProvider);
        await container.read(scheduleProvider.future);
        (container.read(stadiumVisitProvider.notifier) as _FixedVisit).inject(
          sample.$3,
        );
        await tester.pump();
        expect(tester.element(find.byType(HomeScreen)), same(homeElement));
        expect(
          tester
              .widget<JourneyStatusVisual>(find.byType(JourneyStatusVisual))
              .status,
          sample.$4,
        );
        expect(find.byType(AnimatedSwitcher), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'P6 missing schedule keeps retry fallback and no fabricated status',
    (tester) async {
      await tester.pumpWidget(
        home(
          now: DateTime.parse('2026-08-25T16:00:00+09:00'),
          games: [],
          scheduleMissing: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('경기 일정을 불러오지 못했어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.byType(JourneyStatusVisual), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('P7 stale visit does not assert arrival after five hours', (
    tester,
  ) async {
    final today = game(date: '2026-08-25');
    await tester.pumpWidget(
      home(
        now: DateTime.parse('2026-08-25T23:30:00+09:00'),
        games: [game(date: '2026-08-25', status: GameStatus.finished)],
        visit: StadiumVisitResult.visited(
          stadiumId: 'jamsil',
          gameId: today.id,
        ),
        visitJudgedAt: DateTime.parse('2026-08-25T18:00:00+09:00'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<JourneyStatusVisual>(find.byType(JourneyStatusVisual))
          .status,
      JourneyStatus.postgame,
    );
    expect(find.text('구장 근처에 도착했어요'), findsNothing);
  });
}
