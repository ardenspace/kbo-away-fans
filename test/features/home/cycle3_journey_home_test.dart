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
import 'package:kbo_away_fans/ui/shared/stadium_picker.dart';
import 'package:kbo_away_fans/weather/weather.dart';

import '../../location/fake_location_permission_gateway.dart';

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

class _FixedVisit extends StadiumVisitCheck {
  _FixedVisit(this.value);

  final StadiumVisitResult? value;

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
  }) {
    final schedule = ScheduleDocument(
      generatedAt: DateTime.utc(2026),
      games: games,
    );
    return ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        teamsProvider.overrideWith(
          (ref) async => ContentFresh<TeamsDocument>(teams),
        ),
        stadiumsProvider.overrideWith(
          (ref) async => ContentFresh<StadiumsDocument>(stadiums),
        ),
        placesProvider.overrideWith(
          (ref) async => ContentFresh<PlacesDocument>(places),
        ),
        scheduleProvider.overrideWith(
          (ref) async => ContentFresh<ScheduleDocument>(schedule),
        ),
        weatherEffectProvider.overrideWith(
          (ref, point) async => WeatherEffect.none,
        ),
        stadiumVisitProvider.overrideWith(() => _FixedVisit(visit)),
        stadiumVisitRunProvider.overrideWith(
          () => _FixedVisitRun(
            visit == null ? null : StadiumVisitRun(judged: true, judgedAt: now),
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

  testWidgets('미래 원정은 기존 정보를 담은 티켓 얼굴이다', (tester) async {
    await pumpHome(
      tester,
      now: DateTime.parse('2026-08-25T14:00:00+09:00'),
      games: [game(date: '2026-08-30')],
    );

    expect(find.byType(JourneyTicket), findsOneWidget);
    expect(find.byType(DdayHeader), findsOneWidget);
    expect(find.text('D-5'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(StadiumPicker),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(StadiumPicker, skipOffstage: false), findsOneWidget);
  });

  testWidgets('경기 당일 출발 전은 이동 얼굴이다', (tester) async {
    await pumpHome(
      tester,
      now: DateTime.parse('2026-08-25T16:00:00+09:00'),
      games: [game(date: '2026-08-25')],
    );

    final visual = tester.widget<JourneyStatusVisual>(
      find.byType(JourneyStatusVisual),
    );
    expect(visual.status, JourneyStatus.moving);
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('해당 경기 구장 방문 신호는 도착 얼굴이다', (tester) async {
    final today = game(date: '2026-08-25');
    await pumpHome(
      tester,
      now: DateTime.parse('2026-08-25T16:00:00+09:00'),
      games: [today],
      visit: StadiumVisitResult.visited(
        stadiumId: today.stadiumId,
        gameId: today.id,
      ),
    );

    expect(
      tester
          .widget<JourneyStatusVisual>(find.byType(JourneyStatusVisual))
          .status,
      JourneyStatus.nearby,
    );
  });

  testWidgets('시작 후 표시 창 안은 라이브 얼굴이다', (tester) async {
    await pumpHome(
      tester,
      now: DateTime.parse('2026-08-25T19:00:00+09:00'),
      games: [game(date: '2026-08-25')],
    );

    expect(
      tester
          .widget<JourneyStatusVisual>(find.byType(JourneyStatusVisual))
          .status,
      JourneyStatus.live,
    );
    expect(find.text('최근 5경기'), findsOneWidget);
  });

  testWidgets('종료된 당일 경기는 경기 후 얼굴이다', (tester) async {
    await pumpHome(
      tester,
      now: DateTime.parse('2026-08-25T22:30:00+09:00'),
      games: [game(date: '2026-08-25', status: GameStatus.finished)],
    );

    expect(
      tester
          .widget<JourneyStatusVisual>(find.byType(JourneyStatusVisual))
          .status,
      JourneyStatus.postgame,
    );
  });

  testWidgets('취소 얼굴의 티켓과 CTA는 danger 의미색을 우선한다', (tester) async {
    await pumpHome(
      tester,
      now: DateTime.parse('2026-08-25T14:00:00+09:00'),
      games: [game(date: '2026-08-25', status: GameStatus.rainCanceled)],
    );

    final ticket = tester.widget<JourneyTicket>(find.byType(JourneyTicket));
    final status = tester.widget<JourneyStatusVisual>(
      find.byType(JourneyStatusVisual),
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '실내 놀거리 보러 가기'),
    );
    final context = tester.element(find.byType(HomeScreen));
    final visual = Theme.of(context).extension<AppVisualTheme>()!;

    expect(ticket.cancelled, isTrue);
    expect(status.status, JourneyStatus.cancelled);
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      visual.danger,
    );
    expect(find.text('오늘 경기가 우천으로 취소됐어요'), findsOneWidget);
  });

  testWidgets('reduced motion은 전환 없이 현재 얼굴을 즉시 보인다', (tester) async {
    await pumpHome(
      tester,
      now: DateTime.parse('2026-08-25T19:00:00+09:00'),
      games: [game(date: '2026-08-25')],
      reduceMotion: true,
    );

    expect(find.byType(JourneyStatusVisual), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.text('경기가 진행 중이에요'), findsOneWidget);
  });
}
