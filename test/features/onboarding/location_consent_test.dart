/// Step 2.5 boundary tests — 온보딩 팀 선택 직후의 위치 권한 게이트.
///
/// 계약이 요구하는 세 분기(허용·거절·이미 결정됨)에 더해, 이 신호가 **서지
/// 말아야 하는** 세 자리(팀 변경 모드·저장 실패로 되돌아간 선택·이미 있는
/// 문서로 물러선 선택)를 함께 잰다 — 어느 쪽이든 사람이 실제로 고르지
/// 못했거나 이미 갖고 있던 팀에 대해 위치를 내주면 안 된다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
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

/// 상한이 **있다면** 그 안에는 끝나야 하는 시간 — 상한이 있다는 사실을 재는
/// 케이스들이 미는 시간이다. `kLocationPermissionTimeout` 을 더하거나 곱해 쓰지
/// 않는 것은, 그러면 상수를 키우는 변이가 미는 시간까지 함께 키워 그 케이스들이
/// 어떤 값도 지키지 못하기 때문이다(`team_select_test.dart` 의
/// `_generousCacheBound` 가 같은 함정에서 나왔다). 값 자체는
/// `test/location/device_permission_handler_gateway_test.dart` 가 따로 잰다.
const Duration _generousLocationBound = Duration(seconds: 10);

/// 상한 **앞**을 딛는 시간 — 이만큼 밀어도 아직 답이 없어야 "기다린다"가 참이다.
const Duration _beforeAnyBound = Duration(seconds: 1);

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
  ///
  /// [settle] 을 끄면 선택 뒤에 프레임 몇 장만 밀고 멈춘다 — 게이트웨이가
  /// 끝나지 않는 실행을 재는 시험은 `pumpAndSettle` 로 시간을 통째로 밀어
  /// 버리면 "상한 전에는 기다리고 상한에서 빠져나온다"를 가를 수 없다.
  Future<void> pickHanwhaOnboarding(
    WidgetTester tester, {
    bool settle = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    if (settle) {
      await tester.pumpAndSettle();
      return;
    }
    // 낙관적 반영 → 홈 → (프레임 끝) 신호 소비 → 검사 시작까지 밀어 준다.
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
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
    // step 5.2 — 팀 변경 흐름(LocationConsentScreen) 자신은 게이트웨이에
    // 묻지 않지만, 이 파일의 schedule 이 항상 비어 있어 홈이 noGameToday
    // 갈래에서 권한을 딱 한 번 다시 묻는다(`current_location.dart` docstring
    // 참조) — 그 재조회가 이 값을 0 에서 1 로 올린다. "온보딩 흐름 자체가
    // 묻지 않는다"는 위 `LocationConsentScreen findsNothing` 이 그대로 지킨다.
    expect(location.statusCalls, 1, reason: '홈의 noGameToday 재조회 하나뿐 — 팀 변경 흐름은 묻지 않았다');
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
    // step 5.2 — 위 test 의 같은 까닭: 이 파일의 schedule 이 항상 비어 있어
    // 홈이 noGameToday 갈래에서 권한을 한 번 다시 묻는다.
    expect(location.statusCalls, 1);
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
    // step 5.2 — 위 두 test 와 같은 까닭: schedule 이 항상 비어 있어 홈이
    // noGameToday 갈래에서 권한을 한 번 다시 묻는다.
    expect(location.statusCalls, 1);
    expect(location.requestCalls, 0);
  });

  group('위치 권한을 알아내지 못하는 실행 — 사람이 빠져나갈 길', () {
    // 이 세 갈래(던짐·멎음·요청이 던짐)에서 앞 라운드의 화면은 사람을
    // 붙잡았다: `status()` 가 던지면 그 예외를 아무도 받지 않은 채 전면
    // 스피너가 남았고(60초를 밀어도 그대로), 끝나지 않으면 120초를 밀어도
    // 스피너였으며, `request()` 가 던지면 허용 버튼이 영영 아무 일도 하지
    // 않았다. 상한과 실패 계약(`lib/location/location.dart`)이 그 자리를
    // 닫는다 — 알아내지 못한 실행은 `denied` 와 같이 다루므로 설명 화면이
    // 뜨고, 어느 버튼을 눌러도 홈으로 나간다.

    testWidgets('status() 가 던져도 스피너에 갇히지 않는다', (tester) async {
      location = FakeLocationPermissionGateway(
        statusError: PlatformException(code: 'channel-error'),
      );
      await pickHanwhaOnboarding(tester);

      expect(
        tester.takeException(),
        isNull,
        reason: '아무도 받지 않는 예외가 남지 않는다',
      );
      expect(
        find.byType(LocationConsentScreen),
        findsOneWidget,
        reason: '알아내지 못한 상태는 아직 물어볼 수 있는 상태와 같이 다룬다',
      );

      await tester.tap(find.text('나중에 할게요'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('status() 가 끝나지 않아도 상한에서 빠져나온다', (tester) async {
      location = FakeLocationPermissionGateway(statusNeverAnswers: true);
      await pickHanwhaOnboarding(tester, settle: false);

      expect(location.statusCalls, 1, reason: '검사는 시작됐다');
      expect(
        find.byType(LocationConsentScreen),
        findsNothing,
        reason: '상한 전에는 답을 기다린다',
      );

      await tester.pump(_beforeAnyBound);
      expect(find.byType(LocationConsentScreen), findsNothing);

      await tester.pump(_generousLocationBound);
      expect(
        find.byType(LocationConsentScreen),
        findsOneWidget,
        reason: '상한을 넘기면 답을 못 받은 채로 갈래를 정한다',
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('나중에 할게요'));
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
      // step 5.2 — 홈이 noGameToday 갈래(이 파일의 schedule 이 항상 비어
      // 있다)에서 권한을 다시 묻는데, 이 게이트웨이는 status() 가 끝나지
      // 않는 대역이라 그 재조회도 상한에서 빠져나와야 한다. 안 그러면 그
      // 타이머가 위젯 트리 해제 뒤까지 남아 "A Timer is still pending" 로
      // 시험이 깨진다(`current_location.dart` docstring 참조).
      await tester.pump(_generousLocationBound);
    });

    testWidgets('request() 가 던져도 허용 버튼이 침묵하지 않는다', (tester) async {
      location = FakeLocationPermissionGateway(
        requestError: PlatformException(
          code: 'ERROR_ALREADY_REQUESTING_PERMISSIONS',
        ),
      );
      await pickHanwhaOnboarding(tester);
      expect(find.byType(LocationConsentScreen), findsOneWidget);

      await tester.tap(find.text('위치 권한 허용하기'));
      await tester.pumpAndSettle();

      expect(location.requestCalls, 1);
      expect(tester.takeException(), isNull);
      expect(
        find.byType(HomeScreen),
        findsOneWidget,
        reason: '요청이 실패해도 거절과 같은 자리로 끝난다',
      );
    });

    testWidgets('request() 가 끝나지 않아도 상한에서 홈으로 나간다', (tester) async {
      location = FakeLocationPermissionGateway(requestNeverAnswers: true);
      await pickHanwhaOnboarding(tester);
      expect(find.byType(LocationConsentScreen), findsOneWidget);

      await tester.tap(find.text('위치 권한 허용하기'));
      await tester.pump();
      expect(
        find.byType(LocationConsentScreen),
        findsOneWidget,
        reason: '상한 전에는 OS 의 답을 기다린다',
      );

      await tester.pump(_generousLocationBound);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('위치 게이트를 지나면 온보딩 신호가 꺼져 있다', (tester) async {
    // 신호를 끄는 자리가 사라져도 이 세션의 게이트는 안쪽 표시(`_handling`)로
    // 두 번 뜨지 않아 화면만 봐서는 드러나지 않는다. 드러나는 자리는 게이트가
    // **새로 만들어지는** 실행(로그아웃 뒤 다른 계정의 로그인처럼)이고, 그때
    // 남은 신호는 온보딩하지 않은 사람에게 위치를 묻는다. 그래서 화면이 아니라
    // 신호 자체를 잰다.
    await pickHanwhaOnboarding(tester);
    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );
    expect(
      container.read(onboardingJustOnboardedProvider),
      isFalse,
      reason: '본 신호는 그 자리에서 꺼진다',
    );
  });
}
