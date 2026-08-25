/// Step 2.3 홈 화면 위젯 테스트 — acceptance criteria 를 위젯 레벨로 확인.
///
/// teams/stadiums/places 픽스처는 저장소의 `content-pipeline/data/*.json`
/// 실물을 그대로 파싱해(계약 드리프트 방지) provider override 로 주입하고,
/// schedule 과 "현재 시각"([clockProvider])만 시나리오별로 구성한다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';
import 'package:kbo_away_fans/ui/shared/weather_backdrop.dart';
import 'package:kbo_away_fans/weather/weather.dart';

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

  Game game({
    required String date,
    required String home,
    required String away,
    required String stadium,
  }) {
    return Game(
      id: '$date-$stadium-$away-$home',
      date: date,
      startTime: '18:30',
      homeTeamId: home,
      awayTeamId: away,
      stadiumId: stadium,
      status: GameStatus.scheduled,
    );
  }

  Widget home({
    required String teamId,
    required List<Game> games,
    required DateTime now,
    WeatherEffect weather = WeatherEffect.none,
  }) {
    final scheduleDoc =
        ScheduleDocument(generatedAt: DateTime.utc(2026), games: games);
    return ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => now),
        // 날씨는 실 네트워크 대신 시나리오 주입 (기본은 연출 없음).
        weatherEffectProvider.overrideWith((ref, point) async => weather),
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
      ],
      child: MaterialApp(home: HomeScreen(teamId: teamId)),
    );
  }

  // 기준 시각: 2026-08-25 (화) 낮, KST.
  final now = DateTime.parse('2026-08-25T14:00:00+09:00');

  testWidgets('오늘 원정 경기가 있으면 "오늘" 상태가 뜬다', (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(date: '2026-08-25', home: 'lg', away: 'lotte', stadium: 'jamsil'),
      ],
      now: now,
    ));
    await tester.pumpAndSettle();

    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets('오늘 경기가 없으면 다음 원정 D-day와 미리보기가 뜬다', (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(date: '2026-08-30', home: 'lg', away: 'lotte', stadium: 'jamsil'),
      ],
      now: now,
    ));
    await tester.pumpAndSettle();

    expect(find.text('D-5'), findsOneWidget);
    // 목적지(잠실) 장소 미리보기 — 픽스처 places.json 의 잠실 장소가 뜬다.
    expect(
      find.text('샘플 국밥집 (샘플 데이터)', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('남은 일정이 없으면(시즌 종료) 명시적 빈 상태가 뜬다', (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        // 과거 경기만 남은 일정 소진 픽스처.
        game(date: '2026-08-10', home: 'lg', away: 'lotte', stadium: 'jamsil'),
      ],
      now: now,
    ));
    await tester.pumpAndSettle();

    expect(find.text('남은 원정 경기가 없어요'), findsOneWidget);
    expect(find.byType(DdayHeader), findsOneWidget);
  });

  testWidgets('목적지 구장이 비 오는 날이면 홈 배경에 비 레이어가 뜬다', (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(date: '2026-08-30', home: 'lg', away: 'lotte', stadium: 'jamsil'),
      ],
      now: now,
      weather: WeatherEffect.rain,
    ));
    // RainLayer 는 repeat 애니메이션이라 pumpAndSettle 대신 고정 pump.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(WeatherBackdrop), findsOneWidget);
    expect(find.byType(RainLayer), findsOneWidget);
    // 여정(D-day 얼굴)은 그대로 정상 렌더된다.
    expect(find.text('D-5'), findsOneWidget);
  });

  testWidgets('날씨가 비가 아니면(실패 포함 기본값) 비 레이어가 없다', (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(date: '2026-08-30', home: 'lg', away: 'lotte', stadium: 'jamsil'),
      ],
      now: now,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(WeatherBackdrop), findsOneWidget);
    expect(find.byType(RainLayer), findsNothing);
    expect(find.text('D-5'), findsOneWidget);
  });

  testWidgets('잠실 경기: D-day 영역 테마가 홈팀(LG) 기준으로 적용된다', (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(date: '2026-08-30', home: 'lg', away: 'lotte', stadium: 'jamsil'),
      ],
      now: now,
    ));
    await tester.pumpAndSettle();

    // 바깥 스코프는 응원 팀(lotte), 헤더를 감싼 안쪽 스코프는 홈팀(lg).
    final scopes =
        tester.widgetList<TeamThemeScope>(find.byType(TeamThemeScope)).toList();
    expect(scopes, hasLength(2));
    expect(scopes.first.theme.primary, TeamThemes.byId['lotte']!.primary);
    expect(scopes.last.theme.primary, TeamThemes.byId['lg']!.primary);

    final headerScope = tester.widget<TeamThemeScope>(
      find.ancestor(
        of: find.byType(DdayHeader),
        matching: find.byType(TeamThemeScope),
      ).first,
    );
    expect(headerScope.theme.primary, TeamThemes.byId['lg']!.primary);
  });
}
