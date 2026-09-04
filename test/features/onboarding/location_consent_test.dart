/// Step 2.5 boundary tests — 온보딩 팀 선택 직후의 위치 권한 게이트.
///
/// 계약이 요구하는 세 분기(허용·거절·이미 결정됨)에 더해, 이 신호가 **서지
/// 말아야 하는** 세 자리(팀 변경 모드·저장 실패로 되돌아간 선택·이미 있는
/// 문서로 물러선 선택)를 함께 잰다 — 어느 쪽이든 사람이 실제로 고르지
/// 못했거나 이미 갖고 있던 팀에 대해 위치를 내주면 안 된다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/onboarding/location_consent.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/features/team_select/team_select_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../location/fake_location_permission_gateway.dart';

/// 서버에 이미 남아 있는 사용자 문서 — `team_select_test.dart` 의 것과 같은
/// 모양이다.
Map<String, Object?> _serverDocument(String teamId) => <String, Object?>{
  UserFields.nickname: '먼저있던닉',
  UserFields.favoriteTeamId: teamId,
  UserFields.profileThemeKey: teamId,
  UserFields.joinedAt: DateTime.utc(2026, 3, 1),
  UserFields.board: const <String, Object?>{},
};

void main() {
  const uid = 'uid-1';
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

  late FakeUserDataStore store;
  late FakeLocationPermissionGateway location;

  setUp(() {
    store = FakeUserDataStore();
    addTearDown(store.dispose);
    location = FakeLocationPermissionGateway();
  });

  Widget app() {
    final emptySchedule = ScheduleDocument(
      generatedAt: DateTime.utc(2026),
      games: const [],
    );
    final auth = FakeAuthService(
      signedIn: const AuthUser(uid: uid, displayName: '원정러'),
    );
    addTearDown(auth.dispose);
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        locationPermissionGatewayProvider.overrideWithValue(location),
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

  /// 온보딩에서 한화를 골라 새 문서를 만드는 자리까지 공통으로 민다.
  Future<void> pickHanwhaOnboarding(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    await tester.pumpAndSettle();
  }

  testWidgets('허용: 상태가 미결정이면 설명이 뜨고, 허용하면 홈으로 넘어간다', (
    tester,
  ) async {
    location = FakeLocationPermissionGateway(
      initial: LocationPermissionStatus.denied,
      afterRequest: LocationPermissionStatus.granted,
    );
    await pickHanwhaOnboarding(tester);

    expect(find.byType(LocationConsentScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(location.requestCalls, 0, reason: '아직 아무 버튼도 누르지 않았다');

    await tester.tap(find.text('위치 권한 허용하기'));
    await tester.pumpAndSettle();

    expect(location.requestCalls, 1);
    expect(find.byType(LocationConsentScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('거절: OS 가 거절로 답해도 홈은 그대로 동작한다', (tester) async {
    location = FakeLocationPermissionGateway(
      initial: LocationPermissionStatus.denied,
      afterRequest: LocationPermissionStatus.denied,
    );
    await pickHanwhaOnboarding(tester);
    expect(find.byType(LocationConsentScreen), findsOneWidget);

    await tester.tap(find.text('위치 권한 허용하기'));
    await tester.pumpAndSettle();

    expect(location.requestCalls, 1);
    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: '거절해도 홈이 뜨고 앱이 멈추지 않는다',
    );
    // 홈이 뜬 이상 나머지(추천·좋아요 등)는 홈이 이미 보장하는 여느 렌더와
    // 같다 — 이 시험이 재는 것은 위치 권한이 그 렌더를 막지 않는다는 것이다.
  });

  testWidgets('나중에 할게요: OS 에 묻지 않고도 홈으로 넘어간다', (tester) async {
    await pickHanwhaOnboarding(tester);
    expect(find.byType(LocationConsentScreen), findsOneWidget);

    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();

    expect(location.requestCalls, 0, reason: 'OS 다이얼로그를 아예 띄우지 않았다');
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('이미 결정됨: 이미 허용된 상태에서는 설명을 다시 띄우지 않는다', (
    tester,
  ) async {
    location = FakeLocationPermissionGateway(
      initial: LocationPermissionStatus.granted,
    );
    await pickHanwhaOnboarding(tester);

    expect(find.byType(LocationConsentScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(location.statusCalls, greaterThanOrEqualTo(1));
    expect(location.requestCalls, 0, reason: '이미 결정된 상태를 다시 묻지 않는다');
  });

  testWidgets('이미 결정됨(영구 거절): 이 상태에서도 설명을 다시 띄우지 않는다', (
    tester,
  ) async {
    location = FakeLocationPermissionGateway(
      initial: LocationPermissionStatus.permanentlyDenied,
    );
    await pickHanwhaOnboarding(tester);

    expect(find.byType(LocationConsentScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(location.requestCalls, 0);
  });

  testWidgets('팀 변경 모드에서는 위치 설명이 뜨지 않는다', (tester) async {
    location = FakeLocationPermissionGateway(
      initial: LocationPermissionStatus.denied,
    );
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = _serverDocument('lg');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    final samsung = find.text('삼성 라이온즈', skipOffstage: false);
    await tester.ensureVisible(samsung);
    await tester.pumpAndSettle();
    await tester.tap(samsung);
    await tester.pumpAndSettle();

    expect(store.documents[uid]![UserFields.favoriteTeamId], 'samsung');
    expect(
      find.byType(LocationConsentScreen),
      findsNothing,
      reason: '팀 변경은 계약이 다루는 온보딩이 아니다',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(location.statusCalls, 0, reason: '위치 게이트웨이에 물어보지도 않았다');
    expect(location.requestCalls, 0);
  });

  testWidgets('서버에 남기지 못한 선택 뒤에는 위치 설명이 뜨지 않는다', (tester) async {
    location = FakeLocationPermissionGateway(
      initial: LocationPermissionStatus.denied,
    );
    SharedPreferences.setMockInitialValues({});
    store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    await tester.pumpAndSettle();

    expect(find.text(TeamSelectScreen.saveFailureNotice), findsOneWidget);
    expect(
      find.byType(LocationConsentScreen),
      findsNothing,
      reason: '고르지도 못한 팀에 대해 위치를 물으면 안 된다',
    );
    expect(find.byType(HomeScreen), findsNothing);
    expect(location.statusCalls, 0);
    expect(location.requestCalls, 0);
  });

  testWidgets('이미 있는 문서로 물러선 선택 뒤에는 위치 설명이 뜨지 않는다', (
    tester,
  ) async {
    location = FakeLocationPermissionGateway(
      initial: LocationPermissionStatus.denied,
    );
    SharedPreferences.setMockInitialValues({});
    // "물러선 선택" 시나리오(team_select_test.dart 와 같은 배선) — 캐시가
    // 비어 있고 서버 문서는 이미 있는데 스냅샷이 오류로 끝난 실행에서
    // 온보딩이 뜬 채로 새 팀을 고르면, 그 선택은 원본을 덮지 않고 물러선다.
    store.documents[uid] = _serverDocument('lg');
    store.holdProfiles = true;
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(TeamSelectScreen), findsOneWidget);

    final kt = find.text('kt wiz', skipOffstage: false);
    await tester.ensureVisible(kt);
    await tester.pumpAndSettle();
    await tester.tap(kt);
    await tester.pumpAndSettle();

    expect(store.profileCreates, 0, reason: '물러섰으니 새 문서를 만들지 않았다');
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'lg');
    expect(
      find.byType(LocationConsentScreen),
      findsNothing,
      reason: '이 사람은 처음 고르는 중이 아니라 이미 lg 를 응원하던 사람이다',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(location.statusCalls, 0);
    expect(location.requestCalls, 0);
  });
  testWidgets('팀 변경 모드에서 문서가 실제로 만들어지는 드문 경로에서도 위치 설명이 뜨지 않는다', (
    tester,
  ) async {
    // 지휘자가 변이 주입으로 잡은 자리 — `_writeProfile` 의 create 성공 갈래는
    // `isChange` 와 무관하게 지나갈 수 있다(서버에 문서가 아예 없으면 변경
    // 모드에서도 `createProfile` 이 새로 만든다). 앞의 "팀 변경 모드" 시험은
    // 서버에 문서가 **이미 있어** 수정 경로(patch)만 지나므로 이 갈래를 재지
    // 못한다 — 이 시험은 서버에 문서가 없고 캐시만 있는(스냅샷을 못 본) 세션이
    // "응원 팀 바꾸기"를 눌러 `createProfile` 이 실제로 문서를 만드는 자리를
    // 딛는다.
    location = FakeLocationPermissionGateway(
      initial: LocationPermissionStatus.denied,
    );
    SharedPreferences.setMockInitialValues({});
    // 캐시에만 팀이 있고 서버 문서는 아예 없다 — 이 계정은 이미 lg 를
    // 응원하던 사람으로 홈에 머무르지만, 이 세션은 그 문서를 본 적이 없다.
    await const SelectedTeamStore().write(uid, 'lg');
    store.holdProfiles = true;
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await tester.pumpAndSettle();
    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: '서버를 읽지 못해도 캐시 값(lg)으로 홈에 머무른다',
    );

    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    final kt = find.text('kt wiz', skipOffstage: false);
    await tester.ensureVisible(kt);
    await tester.pumpAndSettle();
    await tester.tap(kt);
    await tester.pumpAndSettle();

    expect(
      store.profileCreates,
      1,
      reason: '서버에 문서가 없었으니 이 선택이 실제로 새로 만든다',
    );
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'kt');
    expect(
      find.byType(LocationConsentScreen),
      findsNothing,
      reason: '변경 모드에서 고른 선택이므로 문서를 새로 만들어도 위치를 묻지 않는다',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(location.statusCalls, 0);
    expect(location.requestCalls, 0);
  });
}
