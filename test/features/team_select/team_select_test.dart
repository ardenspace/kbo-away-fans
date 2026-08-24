/// Step 2.2 boundary tests — 팀 선택 온보딩 위젯 테스트.
///
/// 팀 픽스처는 저장소의 `content-pipeline/data/teams.json` 실물을 그대로
/// 파싱해(계약 드리프트 방지) [teamsProvider] override 로 주입한다.
/// 저장은 shared_preferences mock 초기값으로 제어한다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/features/team_select/team_select_screen.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late TeamsDocument teamsDoc;
  late StadiumsDocument stadiumsDoc;
  late PlacesDocument placesDoc;

  setUpAll(() {
    Map<String, Object?> readJson(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    teamsDoc = TeamsDocument.fromJson(
      readJson('content-pipeline/data/teams.json'),
    );
    stadiumsDoc = StadiumsDocument.fromJson(
      readJson('content-pipeline/data/stadiums.json'),
    );
    placesDoc = PlacesDocument.fromJson(
      readJson('content-pipeline/data/places.json'),
    );
  });

  Widget app() {
    // 홈이 소비하는 콘텐츠 provider 4종을 모두 override 한다 — 실제
    // 파일/네트워크 IO 는 widget test 의 fake async 안에서 완료되지 않아
    // pumpAndSettle 이 멈춘다. schedule 은 빈 일정(시즌 종료 빈 상태)으로
    // 고정해 이 테스트를 "현재 시각"과 무관하게 만든다.
    final emptySchedule =
        ScheduleDocument(generatedAt: DateTime.utc(2026), games: const []);
    return ProviderScope(
      overrides: [
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
          (ref) async => ContentFresh<ScheduleDocument>(emptySchedule),
        ),
      ],
      child: const KboAwayFansApp(),
    );
  }

  testWidgets('첫 실행: 온보딩에 10팀이 모두 렌더된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(TeamSelectScreen), findsOneWidget);
    expect(teamsDoc.teams, hasLength(10));
    for (final team in teamsDoc.teams) {
      expect(
        find.text(team.name, skipOffstage: false),
        findsOneWidget,
        reason: team.id,
      );
    }
  });

  testWidgets('팀 선택 → 기기에 저장되고 홈으로 넘어간다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSelectedTeamPrefsKey), 'hanwha');
    // 선택 즉시 온보딩을 떠나 홈이 뜬다.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TeamSelectScreen), findsNothing);
  });

  testWidgets('저장이 있으면 온보딩을 건너뛰고 홈으로 간다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(TeamSelectScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    // 저장된 팀의 테마가 걸려 있다 (themeKey 경유).
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    final expectedKey = teamsDoc.byId('lg')!.themeKey;
    expect(scope.theme.primary, TeamThemes.byId[expectedKey]!.primary);
  });

  testWidgets('팀 변경(설정 진입점) → primary 색이 새 팀 토큰과 일치한다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // 홈 앱바의 팀 변경 진입점으로 변경 화면을 연다.
    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    expect(find.byType(TeamSelectScreen), findsOneWidget);

    final samsung = find.text('삼성 라이온즈', skipOffstage: false);
    await tester.ensureVisible(samsung);
    await tester.pumpAndSettle();
    await tester.tap(samsung);
    await tester.pumpAndSettle();

    // 변경 화면이 닫히고 홈의 테마가 즉시 전환됐다.
    expect(find.byType(HomeScreen), findsOneWidget);
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    final expectedKey = teamsDoc.byId('samsung')!.themeKey;
    expect(scope.theme.primary, TeamThemes.byId[expectedKey]!.primary);
    // 저장 값도 바뀌었다.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kSelectedTeamPrefsKey), 'samsung');
  });
}
