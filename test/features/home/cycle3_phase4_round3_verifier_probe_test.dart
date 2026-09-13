import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/badges/stadium_visit.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/features/places/stadium_places_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';
import 'package:kbo_away_fans/ui/shared/journey_status_visual.dart';
import 'package:kbo_away_fans/ui/shared/journey_ticket.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';
import 'package:kbo_away_fans/ui/shared/stadium_picker.dart';
import 'package:kbo_away_fans/weather/weather.dart';

import '../../location/fake_location_permission_gateway.dart';

class _Visits extends StadiumVisitCheck {
  @override
  StadiumVisitResult? build() => null;
  void replace(StadiumVisitResult? value) => state = value;
  @override
  Future<void> run() async {}
}

Game _game(String date, {GameStatus status = GameStatus.scheduled}) => Game(
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

class _Harness {
  _Harness(this.tester, String start, this.games, {this.plain = false})
    : origin = DateTime.parse(start),
      fakeOrigin = tester.binding.clock.now();
  final WidgetTester tester;
  final DateTime origin;
  final DateTime fakeOrigin;
  final bool plain;
  List<Game> games;
  bool unavailable = false;
  late ProviderContainer container;
  DateTime get now =>
      origin.add(tester.binding.clock.now().difference(fakeOrigin));

  Map<String, dynamic> json(String name) =>
      jsonDecode(File('content-pipeline/data/$name.json').readAsStringSync())
          as Map<String, dynamic>;

  Future<void> mount() async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final teams = TeamsDocument.fromJson(json('teams'));
    final stadiums = StadiumsDocument.fromJson(json('stadiums'));
    final places = PlacesDocument.fromJson(json('places'));
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        teamsProvider.overrideWith((ref) async => ContentFresh(teams)),
        stadiumsProvider.overrideWith((ref) async => ContentFresh(stadiums)),
        placesProvider.overrideWith((ref) async => ContentFresh(places)),
        scheduleProvider.overrideWith(
          (ref) async => unavailable
              ? const ContentUnavailable<ScheduleDocument>(
                  ContentIssue(
                    ContentIssueKind.network,
                    'independent missing input',
                  ),
                )
              : ContentFresh(
                  ScheduleDocument(generatedAt: origin, games: games),
                ),
        ),
        stadiumVisitProvider.overrideWith(_Visits.new),
        weatherEffectProvider.overrideWith(
          (ref, point) async => WeatherEffect.none,
        ),
        locationPermissionGatewayProvider.overrideWithValue(
          FakeLocationPermissionGateway(
            initial: LocationPermissionStatus.denied,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: plain
              ? null
              : AppVisualTheme.resolve(
                  favoriteTeamId: 'lotte',
                  defaultFamily: AppThemeFamily.a,
                  brightness: Brightness.light,
                ).toThemeData(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const HomeScreen(teamId: 'lotte'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> to(String timestamp) async {
    final delta = DateTime.parse(timestamp).difference(now);
    expect(delta.isNegative, isFalse);
    await tester.pump(delta);
    expect(tester.takeException(), isNull);
  }

  Future<void> schedule(List<Game> value) async {
    games = value;
    container.invalidate(scheduleProvider);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> visit(Game game, {DateTime? judgedAt}) async {
    (container.read(stadiumVisitProvider.notifier) as _Visits).replace(
      StadiumVisitResult.visited(stadiumId: game.stadiumId, gameId: game.id),
    );
    container
        .read(stadiumVisitRunProvider.notifier)
        .record(StadiumVisitRun(judged: true, judgedAt: judgedAt ?? now));
    await tester.pump();
  }

  void status(JourneyStatus value) {
    expect(
      tester
          .widget<JourneyStatusVisual>(find.byType(JourneyStatusVisual))
          .status,
      value,
    );
    expect(find.byType(AnimatedSwitcher), findsNothing);
  }

  void retained() {
    expect(find.byType(PlaceCard), findsNWidgets(3));
    expect(find.text('최근 5경기'), findsOneWidget);
    expect(find.text('3 : 2'), findsOneWidget);
    expect(find.byType(StadiumPicker), findsOneWidget);
  }

  Future<void> disposeAndAdvance() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(days: 2));
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  }
}

void main() {
  testWidgets(
    'R3 same mounted home crosses midnight, freshness, start, end and cancel',
    (tester) async {
      final today = _game('2026-08-25');
      final past = _game('2026-08-23', status: GameStatus.finished);
      final h = _Harness(tester, '2026-08-24T23:59:59+09:00', [today, past]);
      await h.mount();
      final identity = tester.state(find.byType(HomeScreen));
      expect(find.byType(JourneyTicket), findsOneWidget);
      expect(find.text('D-1'), findsOneWidget);
      h.retained();
      await h.to('2026-08-25T00:00:00+09:00');
      h.status(JourneyStatus.moving);
      expect(find.text('오늘'), findsOneWidget);
      h.retained();
      await h.visit(today);
      h.status(JourneyStatus.nearby);
      await h.to('2026-08-25T00:15:00+09:00');
      h.status(JourneyStatus.nearby);
      await h.to('2026-08-25T00:15:00.000001+09:00');
      h.status(JourneyStatus.moving);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await h.to('2026-08-25T18:29:59.999999+09:00');
      h.status(JourneyStatus.moving);
      await h.to('2026-08-25T18:30:00+09:00');
      h.status(JourneyStatus.live);
      h.retained();
      await h.to('2026-08-25T22:29:59.999999+09:00');
      h.status(JourneyStatus.live);
      await h.to('2026-08-25T22:30:00+09:00');
      h.status(JourneyStatus.postgame);
      h.retained();
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await h.schedule([
        _game('2026-08-25', status: GameStatus.rainCanceled),
        _game('2026-08-28'),
        past,
      ]);
      h.status(JourneyStatus.cancelled);
      expect(find.text('D-3'), findsOneWidget);
      h.retained();
      expect(tester.state(find.byType(HomeScreen)), same(identity));
      final buttonFinder = find.widgetWithText(FilledButton, '실내 놀거리 보러 가기');
      final button = tester.widget<FilledButton>(buttonFinder);
      final visual = Theme.of(
        tester.element(buttonFinder),
      ).extension<AppVisualTheme>()!;
      expect(button.style!.backgroundColor!.resolve({}), visual.danger);
      final cancelledTicket = find.byWidgetPredicate(
        (w) => w is JourneyTicket && w.cancelled,
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: cancelledTicket,
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect((decoration.border! as Border).top.color, visual.danger);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      final destination = tester.widget<StadiumPlacesScreen>(
        find.byType(StadiumPlacesScreen),
      );
      expect(destination.stadiumId, 'jamsil');
      expect(destination.initialIndoorOnly, isTrue);
      await h.disposeAndAdvance();
    },
  );

  testWidgets('R3 cancellations and finished faces expire at KST midnight', (
    tester,
  ) async {
    final h = _Harness(tester, '2026-08-24T23:59:59+09:00', [
      _game('2026-08-24', status: GameStatus.canceled),
    ]);
    await h.mount();
    h.status(JourneyStatus.cancelled);
    await h.to('2026-08-25T00:00:00+09:00');
    expect(find.byType(JourneyStatusVisual), findsNothing);
    expect(tester.widget<DdayHeader>(find.byType(DdayHeader)).dDay, isNull);
    await h.to('2026-08-25T23:59:59+09:00');
    await h.schedule([
      _game('2026-08-25', status: GameStatus.finished),
      _game('2026-08-28'),
    ]);
    h.status(JourneyStatus.postgame);
    await h.to('2026-08-26T00:00:00+09:00');
    expect(find.text('D-2'), findsOneWidget);
    await h.to('2026-08-27T00:00:00+09:00');
    expect(find.text('D-1'), findsOneWidget);
    await h.disposeAndAdvance();
  });

  testWidgets(
    'R3 fresh matching visit cannot override confirmed finished or live game',
    (tester) async {
      final today = _game('2026-08-25');
      final h = _Harness(tester, '2026-08-25T19:00:00+09:00', [today]);
      await h.mount();
      await h.visit(today);
      h.status(JourneyStatus.live);
      await h.schedule([_game('2026-08-25', status: GameStatus.finished)]);
      h.status(JourneyStatus.postgame);
      await h.disposeAndAdvance();
    },
  );

  testWidgets(
    'R3 missing schedule and empty schedule remove active faces on same home',
    (tester) async {
      final h = _Harness(tester, '2026-08-25T17:00:00+09:00', [
        _game('2026-08-25'),
      ]);
      await h.mount();
      final identity = tester.state(find.byType(HomeScreen));
      h.unavailable = true;
      await h.schedule([]);
      expect(find.text('경기 일정을 불러오지 못했어요'), findsOneWidget);
      expect(find.byType(JourneyStatusVisual), findsNothing);
      h.unavailable = false;
      await h.schedule([]);
      expect(tester.widget<DdayHeader>(find.byType(DdayHeader)).dDay, isNull);
      expect(find.byType(StadiumPicker), findsOneWidget);
      expect(tester.state(find.byType(HomeScreen)), same(identity));
      await h.disposeAndAdvance();
    },
  );

  testWidgets(
    'R3 stale, future-dated and different-game visits do not announce arrival',
    (tester) async {
      final today = _game('2026-08-25');
      final h = _Harness(tester, '2026-08-25T17:00:00+09:00', [today]);
      await h.mount();
      await h.visit(
        today,
        judgedAt: h.now.subtract(const Duration(minutes: 16)),
      );
      h.status(JourneyStatus.moving);
      await h.visit(today, judgedAt: h.now.add(const Duration(minutes: 1)));
      h.status(JourneyStatus.moving);
      await h.visit(_game('2026-08-24'));
      h.status(JourneyStatus.moving);
      await h.disposeAndAdvance();
    },
  );

  testWidgets('R3 standalone PlaceCard avoids overflow at legacy width', (
    tester,
  ) async {
    final h = _Harness(tester, '2026-08-25T19:00:00+09:00', [
      _game('2026-08-25'),
      _game('2026-08-23', status: GameStatus.finished),
    ]);
    await h.mount();
    final errors = <FlutterErrorDetails>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousHandler);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    FlutterError.onError = previousHandler;
    expect(errors, isEmpty);
    expect(find.byType(PlaceCard), findsNWidgets(3));
    final standalone = tester.widget<PlaceCard>(find.byType(PlaceCard).first);
    final third = find.byType(PlaceCard).at(2);
    await tester.ensureVisible(third);
    await tester.pumpAndSettle();
    expect(third.hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(StadiumPicker),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('최근 5경기'), findsOneWidget);
    expect(find.text('3 : 2'), findsOneWidget);
    final exploreTarget = find
        .descendant(
          of: find.byType(StadiumPicker),
          matching: find.byType(GestureDetector),
        )
        .first;
    await tester.ensureVisible(exploreTarget);
    await tester.pumpAndSettle();
    expect(exploreTarget.hitTestable(), findsOneWidget);
    errors.clear();
    FlutterError.onError = errors.add;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppVisualTheme.resolve(
          favoriteTeamId: 'lotte',
          defaultFamily: AppThemeFamily.a,
          brightness: Brightness.light,
        ).toThemeData(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.lg),
            child: standalone,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    FlutterError.onError = previousHandler;
    expect(errors, isEmpty);
    FlutterError.onError = previousHandler;
    await h.disposeAndAdvance();
  });

  testWidgets(
    'R3 plain MaterialApp keeps content across schedule and timer transitions',
    (tester) async {
      final h = _Harness(tester, '2026-08-24T23:59:59+09:00', [
        _game('2026-08-25'),
        _game('2026-08-23', status: GameStatus.finished),
      ], plain: true);
      await h.mount();
      h.retained();
      await h.to('2026-08-25T00:00:00+09:00');
      h.retained();
      await h.visit(_game('2026-08-25'));
      await h.to('2026-08-25T18:30:00+09:00');
      h.retained();
      await h.to('2026-08-25T22:30:00+09:00');
      h.retained();
      await h.schedule([
        _game('2026-08-25', status: GameStatus.canceled),
        _game('2026-08-28'),
      ]);
      expect(find.text('D-3'), findsOneWidget);
      final finder = find.widgetWithText(FilledButton, '실내 놀거리 보러 가기');
      final button = tester.widget<FilledButton>(finder);
      expect(
        button.style!.backgroundColor!.resolve({}),
        Theme.of(tester.element(finder)).colorScheme.error,
      );
      await h.disposeAndAdvance();
    },
  );
}
