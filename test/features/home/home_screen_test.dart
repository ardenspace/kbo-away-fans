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
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/badges/stadium_visit.dart';
import 'package:kbo_away_fans/features/home/current_location.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/features/places/stadium_places_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/ui/shared/category_chip.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';
import 'package:kbo_away_fans/ui/shared/stadium_picker.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';
import 'package:kbo_away_fans/ui/shared/weather_backdrop.dart';
import 'package:kbo_away_fans/weather/weather.dart';

import '../../location/fake_location_permission_gateway.dart';

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// [stadiumVisitProvider] 를 고정 값으로 갈아 끼우는 대역 (step 5.2) — 실
/// 판정을 돌리지 않고 홈 상단 위치 문구만 재는 시험에 쓴다.
/// `test/features/badges/visit_status_notice_test.dart` 의
/// `_FixedStadiumVisitCheck` 와 같은 모양이다(각 시험 파일이 재는 화면이
/// 달라 그대로 공유하지 않고 이 파일에도 짧게 둔다).
class _FixedStadiumVisitCheck extends StadiumVisitCheck {
  _FixedStadiumVisitCheck(this._fixed);

  final StadiumVisitResult? _fixed;

  @override
  StadiumVisitResult? build() => _fixed;

  @override
  Future<void> run() async {}
}

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
    GameStatus status = GameStatus.scheduled,
  }) {
    return Game(
      id: '$date-$stadium-$away-$home',
      date: date,
      startTime: '18:30',
      homeTeamId: home,
      awayTeamId: away,
      stadiumId: stadium,
      status: status,
    );
  }

  /// 종료 경기 픽스처 — [game] 과 같은 모양이되 점수·승패까지 채운다
  /// (step 5.1 최근 5경기 요약을 화면에서 재는 시험 전용).
  Game finishedGame({
    required String date,
    required String home,
    required String away,
    required String stadium,
    required int homeScore,
    required int awayScore,
  }) {
    final result = homeScore > awayScore
        ? GameResult.homeWin
        : homeScore < awayScore
            ? GameResult.awayWin
            : GameResult.draw;
    return Game(
      id: '$date-$stadium-$away-$home-finished',
      date: date,
      startTime: '18:30',
      homeTeamId: home,
      awayTeamId: away,
      stadiumId: stadium,
      status: GameStatus.finished,
      homeScore: homeScore,
      awayScore: awayScore,
      result: result,
    );
  }

  Widget home({
    required String teamId,
    required List<Game> games,
    required DateTime now,
    WeatherEffect weather = WeatherEffect.none,
    // step 5.2 — 기본값 null 이라 이 인자를 주지 않는 기존 시나리오는 전부
    // 홈 상단 위치 자리가 접힌 채로 그대로 지나간다.
    StadiumVisitResult? stadiumVisit,
    // noGameToday 갈래에서만 홈이 다시 묻는 권한 상태(계약 위반 시정) — 대역이
    // 없으면 실 플랫폼 채널(DevicePermissionHandlerGateway)이 물려 위젯 트리
    // 해제 뒤까지 남는 타이머로 부팅 시험이 깨진다(`current_location.dart`
    // docstring 참조). 기본값 denied 는 이 인자를 주지 않는 기존 시나리오의
    // 결과를 바꾸지 않는다 — noGameToday 가 아닌 갈래에서는 이 게이트웨이가
    // 아예 구독되지 않는다.
    LocationPermissionGateway? locationGateway,
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
        stadiumVisitProvider.overrideWith(
          () => _FixedStadiumVisitCheck(stadiumVisit),
        ),
        locationPermissionGatewayProvider.overrideWithValue(
          locationGateway ??
              FakeLocationPermissionGateway(
                initial: LocationPermissionStatus.denied,
              ),
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
    // 목적지(잠실) 장소 미리보기 — 실데이터 places.json 의 잠실 장소가 뜬다.
    expect(
      find.text('부농정육식당', skipOffstage: false),
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

  testWidgets('rain_canceled 픽스처 → 플랜B 배너 + 목록 진입 시 실내 필터 활성',
      (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.rainCanceled,
        ),
      ],
      now: now,
    ));
    await tester.pumpAndSettle();

    // 플랜B 배너 렌더 (우천 문구).
    expect(find.text('오늘 경기가 우천으로 취소됐어요'), findsOneWidget);
    expect(find.text('실내 놀거리 보러 가기'), findsOneWidget);

    // 유도 버튼 → 추천 목록이 실내 필터 켜진 상태로 열린다.
    await tester.tap(find.text('실내 놀거리 보러 가기'));
    await tester.pumpAndSettle();
    expect(find.byType(StadiumPlacesScreen), findsOneWidget);
    final indoorChip = tester.widget<CategoryChip>(
      find.widgetWithText(CategoryChip, '실내만'),
    );
    expect(indoorChip.selected, isTrue);
  });

  testWidgets('canceled(일반 취소) 픽스처도 플랜B 배너가 뜬다', (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.canceled,
        ),
      ],
      now: now,
    ));
    await tester.pumpAndSettle();

    expect(find.text('오늘 경기가 취소됐어요'), findsOneWidget);
    expect(find.text('실내 놀거리 보러 가기'), findsOneWidget);
  });

  testWidgets('정상(scheduled) 경기에서는 플랜B 배너가 없다 (홈 무변화)', (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(date: '2026-08-25', home: 'lg', away: 'lotte', stadium: 'jamsil'),
      ],
      now: now,
    ));
    await tester.pumpAndSettle();

    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('실내 놀거리 보러 가기'), findsNothing);
    expect(find.text('오늘 경기가 우천으로 취소됐어요'), findsNothing);
    expect(find.text('오늘 경기가 취소됐어요'), findsNothing);
  });

  testWidgets('우천 취소 + 비 오는 날 — 비 연출(4.1)과 플랜B 배너가 함께 뜬다',
      (tester) async {
    await tester.pumpWidget(home(
      teamId: 'lotte',
      games: [
        game(
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.rainCanceled,
        ),
      ],
      now: now,
      weather: WeatherEffect.rain,
    ));
    // RainLayer 는 repeat 애니메이션이라 pumpAndSettle 대신 고정 pump.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(RainLayer), findsOneWidget);
    expect(find.text('오늘 경기가 우천으로 취소됐어요'), findsOneWidget);
    expect(find.text('실내 놀거리 보러 가기'), findsOneWidget);
  });

  group('구장 골라 구경하기 (step 4.3)', () {
    /// 하단 섹션까지 스크롤해 [finder] 를 화면에 노출시킨다.
    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('홈 하단에 9개 구장이 모두 렌더된다 (경기 없는 날 포함)', (tester) async {
      await tester.pumpWidget(home(teamId: 'lotte', games: const [], now: now));
      await tester.pumpAndSettle();

      expect(
        find.byType(StadiumPicker, skipOffstage: false),
        findsOneWidget,
      );
      final picker = tester.widget<StadiumPicker>(
        find.byType(StadiumPicker, skipOffstage: false),
      );
      expect(picker.stadiums, hasLength(9));
      for (final stadium in stadiumsDoc.stadiums) {
        expect(
          find.text(stadium.name, skipOffstage: false),
          findsOneWidget,
          reason: '${stadium.id} 구장이 렌더되어야 한다',
        );
      }
    });

    testWidgets('구장 선택 → 그 구장 id 의 추천 목록이 홈팀 테마로 뜬다', (tester) async {
      await tester.pumpWidget(home(teamId: 'lotte', games: const [], now: now));
      await tester.pumpAndSettle();

      final daegu = find.text('대구 삼성라이온즈파크', skipOffstage: false);
      await reveal(tester, daegu);
      await tester.tap(daegu);
      await tester.pumpAndSettle();

      final screen = tester.widget<StadiumPlacesScreen>(
        find.byType(StadiumPlacesScreen),
      );
      expect(screen.stadiumId, 'daegu');
      expect(screen.themeKey, teamsDoc.byId('samsung')!.themeKey);
      // 테마 색 전환 — 추천 목록이 삼성 테마 스코프 아래 렌더된다.
      final scope = tester.widget<TeamThemeScope>(
        find.descendant(
          of: find.byType(StadiumPlacesScreen),
          matching: find.byType(TeamThemeScope),
        ),
      );
      expect(scope.theme.primary, TeamThemes.byId['samsung']!.primary);
    });

    testWidgets('잠실 선택 — 당일 경기가 없으면 중립(팀 스코프 없음)', (tester) async {
      await tester.pumpWidget(home(
        teamId: 'lotte',
        games: [
          // 내일 잠실 경기 — "당일"이 아니므로 중립이어야 한다.
          game(
            date: '2026-08-26',
            home: 'lg',
            away: 'lotte',
            stadium: 'jamsil',
          ),
        ],
        now: now,
      ));
      await tester.pumpAndSettle();

      final jamsil = find.text('잠실야구장', skipOffstage: false);
      await reveal(tester, jamsil);
      await tester.tap(jamsil);
      await tester.pumpAndSettle();

      final screen = tester.widget<StadiumPlacesScreen>(
        find.byType(StadiumPlacesScreen),
      );
      expect(screen.stadiumId, 'jamsil');
      expect(screen.themeKey, isNull);
      expect(
        find.descendant(
          of: find.byType(StadiumPlacesScreen),
          matching: find.byType(TeamThemeScope),
        ),
        findsNothing,
      );
    });

    testWidgets('잠실 선택 — 당일 잠실 경기가 있으면 그 경기 홈팀 테마', (tester) async {
      await tester.pumpWidget(home(
        teamId: 'lotte',
        games: [
          game(date: '2026-08-25', home: 'doosan', away: 'kia', stadium: 'jamsil'),
        ],
        now: now,
      ));
      await tester.pumpAndSettle();

      final jamsil = find.text('잠실야구장', skipOffstage: false);
      await reveal(tester, jamsil);
      await tester.tap(jamsil);
      await tester.pumpAndSettle();

      final screen = tester.widget<StadiumPlacesScreen>(
        find.byType(StadiumPlacesScreen),
      );
      expect(screen.stadiumId, 'jamsil');
      expect(screen.themeKey, teamsDoc.byId('doosan')!.themeKey);
    });

    testWidgets('뒤로 가면 내 팀 테마의 홈으로 돌아온다', (tester) async {
      await tester.pumpWidget(home(teamId: 'lotte', games: const [], now: now));
      await tester.pumpAndSettle();

      final daegu = find.text('대구 삼성라이온즈파크', skipOffstage: false);
      await reveal(tester, daegu);
      await tester.tap(daegu);
      await tester.pumpAndSettle();
      expect(find.byType(StadiumPlacesScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(StadiumPlacesScreen), findsNothing);
      final scope = tester.widget<TeamThemeScope>(
        find.byType(TeamThemeScope).first,
      );
      expect(scope.theme.primary, TeamThemes.byId['lotte']!.primary);
    });
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

  group('최근 5경기 요약 (step 5.1) — 화면에 실제로 보이는지', () {
    // 순수 로직(recentGamesFor·outcomeFor)은 recent_games_test.dart 가 이미
    // 촘촘히 잰다. 여기서는 그 결과가 화면에 실제로 "보인다"는 acceptance
    // criteria 네 문장을 렌더 레벨로 확인한다 — 자리가 아예 빠지거나
    // 상한·빈 상태·카드 필드가 조용히 사라져도 로직 시험만으로는 못 잡는다.
    final laterNow = DateTime.parse('2026-08-26T09:00:00+09:00');

    testWidgets('종료 경기가 5개 초과면 화면에도 최근 5개까지만 보인다', (tester) async {
      // 8/20~8/25 (내 팀 lotte 가 매번 홈), 상대·점수를 서로 다르게 두어
      // 어느 경기가 화면에 남았는지를 점수 문자열로 식별한다.
      const opponents = ['kt', 'samsung', 'doosan', 'hanwha', 'kiwoom', 'ssg'];
      final games = [
        for (var i = 0; i < opponents.length; i++)
          finishedGame(
            date: '2026-08-${20 + i}',
            home: 'lotte',
            away: opponents[i],
            stadium: 'sajik',
            homeScore: i + 1,
            awayScore: 0,
          ),
      ];

      await tester.pumpWidget(
        home(teamId: 'lotte', games: games, now: laterNow),
      );
      await tester.pumpAndSettle();

      expect(find.text('최근 5경기'), findsOneWidget);
      // 최신 5개(8/21~8/25 → 점수 2:0~6:0)는 보이고,
      for (final score in ['2 : 0', '3 : 0', '4 : 0', '5 : 0', '6 : 0']) {
        expect(
          find.text(score, skipOffstage: false),
          findsOneWidget,
          reason: '$score 경기는 최신 5개 안에 들어야 한다',
        );
      }
      // 가장 오래된 8/20(점수 1:0)은 상한에 걸려 빠져야 한다.
      expect(find.text('1 : 0', skipOffstage: false), findsNothing);
    });

    testWidgets('종료 경기가 5개보다 적으면 화면에도 있는 만큼만 보인다', (tester) async {
      final games = [
        finishedGame(
          date: '2026-08-20',
          home: 'lotte',
          away: 'kt',
          stadium: 'sajik',
          homeScore: 3,
          awayScore: 1,
        ),
        finishedGame(
          date: '2026-08-21',
          home: 'samsung',
          away: 'lotte',
          stadium: 'daegu',
          homeScore: 2,
          awayScore: 5,
        ),
      ];

      await tester.pumpWidget(
        home(teamId: 'lotte', games: games, now: laterNow),
      );
      await tester.pumpAndSettle();

      expect(find.text('최근 5경기'), findsOneWidget);
      expect(find.text('3 : 1', skipOffstage: false), findsOneWidget);
      // lotte 가 원정이라 내 팀 관점 점수는 뒤집혀 5 : 2 로 보인다.
      expect(find.text('5 : 2', skipOffstage: false), findsOneWidget);
      // 있는 2개 말고 빈 상태 문구가 함께 뜨지는 않는다.
      expect(find.text('아직 경기 결과가 없어요', skipOffstage: false), findsNothing);
    });

    testWidgets('종료 경기가 하나도 없으면 빈 상태가 뜬다', (tester) async {
      await tester.pumpWidget(
        home(
          teamId: 'lotte',
          games: [
            // 예정 경기만 있고 종료된 결과는 없다.
            game(
              date: '2026-08-30',
              home: 'lg',
              away: 'lotte',
              stadium: 'jamsil',
            ),
          ],
          now: laterNow,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('최근 5경기'), findsOneWidget);
      expect(
        find.text('아직 경기 결과가 없어요', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('경기가 끝나면 이 자리에 최근 결과가 쌓여요.', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('카드 한 줄에 날짜·구장·점수·승패가 모두 보인다', (tester) async {
      await tester.pumpWidget(
        home(
          teamId: 'lotte',
          games: [
            finishedGame(
              date: '2026-08-20',
              home: 'lg',
              away: 'lotte',
              stadium: 'jamsil',
              homeScore: 2,
              awayScore: 7,
            ),
          ],
          now: laterNow,
        ),
      );
      await tester.pumpAndSettle();

      // 날짜: 8/20(목). 구장: 잠실야구장 — 같은 이름이 하단 "구장 골라
      // 구경하기" 목록(step 4.3, 상시 노출)에도 뜨므로 카드 고유 스타일
      // (TextTokens.caption)로 좁혀 찾는다.
      expect(find.text('8/20(목)', skipOffstage: false), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == '잠실야구장' &&
              widget.style == TextTokens.caption,
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: '요약 카드 안의 구장 이름(캡션 스타일)이 보여야 한다',
      );
      // 점수: lotte 가 원정이라 내 팀 관점으로 뒤집혀 7 : 2.
      expect(find.text('7 : 2', skipOffstage: false), findsOneWidget);
      // 승패: 원정 승리 → 승.
      expect(find.text('승', skipOffstage: false), findsOneWidget);
    });
  });

  group('홈 상단 현재 위치 (step 5.2) — 화면에 실제로 뜨는지', () {
    // acceptance criteria 세 문장을 렌더 레벨로 확인한다: 5.1 이 REJECT 된
    // 자리와 같은 종류의 구멍(섹션을 통째로 없애는 변이가 로직 시험만으로는
    // 안 잡힌다)을 여기서 막는다. [stadiumVisit] 을 직접 주입하는 것은
    // 4.1 이 이미 돌리는 [stadiumVisitProvider] 를 이 화면이 그대로 읽을
    // 뿐(새 권한 조회를 만들지 않는다)이기 때문이다 — `current_location.dart`
    // docstring 참조.
    Finder locationRow() => find.byWidgetPredicate(
      (widget) =>
          widget is Icon && widget.icon == Icons.location_on_rounded,
      skipOffstage: false,
    );

    testWidgets('판정이 없으면(아직 안 돌았거나 오늘 경기가 없어 후보가 없음) 위치 자리가 없다',
        (tester) async {
      await tester.pumpWidget(home(
        teamId: 'lotte',
        games: const [],
        now: now,
        // stadiumVisit 기본값 null — 아직 판정이 없는 실행.
      ));
      await tester.pumpAndSettle();

      expect(locationRow(), findsNothing);
      expect(
        find.text(kCurrentLocationGenericLabel, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('권한이 없으면(permissionMissing) 위치 자리가 없다', (tester) async {
      await tester.pumpWidget(home(
        teamId: 'lotte',
        games: const [],
        now: now,
        stadiumVisit: const StadiumVisitResult.rejected(
          StadiumVisitReason.permissionMissing,
        ),
      ));
      await tester.pumpAndSettle();

      expect(locationRow(), findsNothing);
    });

    group('오늘 경기가 없으면(noGameToday) — 계약 위반 시정: 권한을 다시 물어 가른다', () {
      // judgeStadiumVisit 이 이 갈래에서는 권한 자체를 묻지 않으므로, 홈이
      // noGameTodayPermissionProvider 로 딱 이 갈래에서만 다시 묻는다
      // (`current_location.dart` docstring 참조). 권한이 없는 사람과
      // 구분되지 않던 acceptance 위반(월요일·비시즌에 권한을 허용한 사람도
      // 자리가 통째로 사라짐)을 닫는 자리다.
      const rejected = StadiumVisitResult.rejected(
        StadiumVisitReason.noGameToday,
      );

      testWidgets('권한이 없으면(denied) 위치 자리가 없다', (tester) async {
        await tester.pumpWidget(home(
          teamId: 'lotte',
          games: const [],
          now: now,
          stadiumVisit: rejected,
          locationGateway: FakeLocationPermissionGateway(
            initial: LocationPermissionStatus.denied,
          ),
        ));
        await tester.pumpAndSettle();

        expect(locationRow(), findsNothing);
      });

      testWidgets('권한이 있으면(granted) 위치 자리가 뜬다 — 경기 없는 날에도', (tester) async {
        final gateway = FakeLocationPermissionGateway(
          initial: LocationPermissionStatus.granted,
        );
        await tester.pumpWidget(home(
          teamId: 'lotte',
          games: const [],
          now: now,
          stadiumVisit: rejected,
          locationGateway: gateway,
        ));
        await tester.pumpAndSettle();

        expect(locationRow(), findsOneWidget);
        // 구장을 특정할 수 없으므로 일반 문구 — outsideRadius 등과 같은 표기.
        expect(
          find.text(kCurrentLocationGenericLabel, skipOffstage: false),
          findsOneWidget,
        );
        // OS 다이얼로그를 새로 띄우는 request() 는 절대 불리지 않는다 —
        // status() 만으로 답을 얻는다(begin.md [XL] 결정 · plan.md 5.2 계약).
        expect(gateway.requestCalls, 0);
        expect(gateway.statusCalls, greaterThanOrEqualTo(1));
      });
    });

    testWidgets('위치 자리가 없어도 홈의 나머지(D-day·최근 5경기·탐색)는 그대로다',
        (tester) async {
      await tester.pumpWidget(home(
        teamId: 'lotte',
        games: [
          game(date: '2026-08-25', home: 'lg', away: 'lotte', stadium: 'jamsil'),
        ],
        now: now,
        stadiumVisit: const StadiumVisitResult.rejected(
          StadiumVisitReason.permissionMissing,
        ),
      ));
      await tester.pumpAndSettle();

      expect(locationRow(), findsNothing);
      // D-day 얼굴 — 오늘 원정 경기가 있는 픽스처라 "오늘"이 뜬다.
      expect(find.text('오늘'), findsOneWidget);
      // 최근 5경기 섹션 자체는 상시 렌더(내용이 비어도 안내가 뜬다).
      expect(find.text('최근 5경기'), findsOneWidget);
      // 구장 골라 구경하기(탐색) — 경기 유무와 무관한 상시 섹션.
      expect(
        find.byType(StadiumPicker, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('권한은 있는데 지금 구장이 아니면(outsideRadius) 일반 문구가 뜬다',
        (tester) async {
      await tester.pumpWidget(home(
        teamId: 'lotte',
        games: const [],
        now: now,
        stadiumVisit: const StadiumVisitResult.rejected(
          StadiumVisitReason.outsideRadius,
        ),
      ));
      await tester.pumpAndSettle();

      expect(locationRow(), findsOneWidget);
      expect(
        find.text(kCurrentLocationGenericLabel, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('방문이 확정되면 그 구장 이름이 뜬다 (구장 근접 표시)', (tester) async {
      await tester.pumpWidget(home(
        teamId: 'lotte',
        games: const [],
        now: now,
        stadiumVisit: const StadiumVisitResult.visited(
          stadiumId: 'sajik',
          gameId: '2026-08-25-sajik-lotte-kt',
        ),
      ));
      await tester.pumpAndSettle();

      expect(locationRow(), findsOneWidget);
      expect(find.text('사직야구장 근처예요', skipOffstage: false), findsOneWidget);
      // 일반 문구로 겹쳐 뜨지 않는다 — 한 자리에 문구 하나만.
      expect(
        find.text(kCurrentLocationGenericLabel, skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets('위치 자리가 있어도 홈의 나머지(D-day·최근 5경기·탐색)는 그대로다',
        (tester) async {
      await tester.pumpWidget(home(
        teamId: 'lotte',
        games: [
          game(date: '2026-08-25', home: 'lg', away: 'lotte', stadium: 'jamsil'),
        ],
        now: now,
        stadiumVisit: const StadiumVisitResult.visited(
          stadiumId: 'jamsil',
          gameId: '2026-08-25-jamsil-lotte-lg',
        ),
      ));
      await tester.pumpAndSettle();

      expect(locationRow(), findsOneWidget);
      expect(find.text('오늘'), findsOneWidget);
      expect(find.text('최근 5경기'), findsOneWidget);
      expect(
        find.byType(StadiumPicker, skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
