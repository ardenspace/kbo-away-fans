/// phase 2 통합 탐침 — 한 사람이 **다섯 단계를 한 번에 지나는** 길.
///
/// 단계마다의 시험은 이미 촘촘하다. 여기서 재는 것은 그 시험들이 서로 만나지
/// 않는 자리다.
///
///  1) **세 제공자 각각의 첫 실행이 홈까지 이어지는가.** 로그인 화면(2.1) →
///     제공자 버튼(2.2·2.3) → 팀 선택(2.4) → 위치 설명(2.5) → 홈. 기존
///     시험들은 이 길을 조각으로 나눠 재고, 제공자를 가르는 시험은 게이트가
///     넘어가는 데까지만 본다 — 제공자에 따라 세션의 표시 이름이 달라지는데
///     그 값이 **사용자 문서의 닉네임 씨앗**이 되는 자리(2.2·2.3 → 2.4)는
///     어느 시험도 끝까지 걷지 않았다.
///
///  2) **두 번째 실행.** 온보딩을 마친 사람이 앱을 껐다 켜면 문서가 다시
///     만들어지지 않고 위치 설명도 다시 뜨지 않는다. 같은 세션 안에서 신호가
///     꺼지는지는 `location_consent_test.dart` 가 재지만, ProviderScope 를
///     통째로 새로 세운 **콜드 스타트**에서 그 신호가 다시 서지 않는지는
///     그 시험 밖이다 — 신호를 세우는 자리가 `createProfile` 의 성공이므로
///     "다시 만들어지지 않는다"(2.4)와 "다시 묻지 않는다"(2.5)는 같은 사실의
///     두 얼굴이다.
///
///  3) **같은 기기를 다른 계정이 쓰는 경우.** 앞사람의 팀이 새 계정의 첫
///     프레임에 붙지 않고(2.4 의 캐시 소유권), 새 계정은 자기 온보딩과 자기
///     위치 설명을 받는다(2.5). 캐시 소유권은 상태 계층에서만 재어졌고
///     위치 설명과 이어 붙인 자리는 없다.
///
///  4) **상한이 겹칠 때 사람이 실제로 얼마나 기다리는가.** 이 phase 에는
///     상한이 다섯이고(부팅·App Check·서버 확인·기기 캐시·위치 조회) 그중
///     셋은 한 사람의 한 실행에서 **차례로** 걸린다. 각 상한이 있는지는
///     각자의 시험이 재지만, 셋이 겹친 실행의 **총 시간**을 재는 자리는
///     없었다 — 하나하나가 사람이 견딜 길이여도 이어 붙이면 아닐 수 있다.
///     여기서 미는 예산은 상수에서 세지 않고 **문자 그대로** 적는다(그래야
///     어느 상수를 키우는 변이든 이 시험이 잡는다).
///
///  5) **부팅 상한의 길이.** 짝인 네 상한(`kAppCheckActivationTimeout`·
///     `kProfileServerConfirmGrace`·`kCachedTeamReadTimeout`·
///     `kLocationPermissionTimeout`)에는 "사람이 견딜 길이"를 못 박는 시험이
///     각각 서 있는데 `kBootInitTimeout` 에만 없었다. 그 하나가 재는 것이
///     **스플래시가 걷히지 않는 시간**이라 다섯 중 빠져나갈 길이 가장 없는
///     구간인데도, 그것을 재는 `boot_stall_probe_test.dart` 는 상수 자신을
///     밀어 보므로 5초를 300초로 바꿔도 전체가 초록불이었다.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/app_check.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/auth/sign_in_screen.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/onboarding/location_consent.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/features/team_select/team_select_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/main.dart' as entrypoint;
import 'package:kbo_away_fans/ui/shared/social_sign_in_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend/fake_backend.dart';
import 'location/fake_location_permission_gateway.dart';

/// 사람이 홈에 닿기까지 견딜 수 있는 시간 — **상수에서 세지 않는다.**
///
/// 상한을 곱하거나 더해 쓰면 상수를 키우는 변이가 예산까지 함께 키워 이
/// 시험이 아무것도 지키지 못한다(`team_select_test.dart` 의
/// `_generousCacheBound` 주석이 같은 함정을 적어 두었다). 겹치는 상한이 셋이고
/// 각각 10초를 넘지 않기로 못 박혀 있으므로, 셋을 다 무는 실행도 이 예산 안에
/// 끝나야 한다.
const Duration _journeyBudget = Duration(seconds: 20);

/// 상한 **앞**을 딛는 시간 — 이만큼은 아직 기다리는 것이 맞다.
const Duration _beforeAnyBound = Duration(milliseconds: 500);

/// 예산을 재는 걸음 — 이 간격으로 밀면서 화면이 바뀐 시점을 센다.
const Duration _step = Duration(milliseconds: 250);

final Finder _homeFinder = find.byType(HomeScreen, skipOffstage: false);

Finder _buttonOf(AuthProviderId provider) => find.byWidgetPredicate(
  (widget) => widget is SocialSignInButton && widget.provider == provider,
);

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

  Widget app({
    required AuthService auth,
    required UserDataStore backend,
    required LocationPermissionGateway location,
    SelectedTeamStore? cache,
  }) {
    final emptySchedule = ScheduleDocument(
      generatedAt: DateTime.utc(2026),
      games: const [],
    );
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(backend),
        locationPermissionGatewayProvider.overrideWithValue(location),
        if (cache != null) selectedTeamStoreProvider.overrideWithValue(cache),
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

  group('세 제공자 각각의 첫 실행이 로그인 화면에서 홈까지 이어진다', () {
    for (final provider in AuthProviderId.values) {
      testWidgets('${provider.name}: 로그인 → 팀 선택 → 위치 설명 → 홈', (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final store = FakeUserDataStore();
        addTearDown(store.dispose);
        final auth = FakeAuthService();
        addTearDown(auth.dispose);
        final location = FakeLocationPermissionGateway(
          afterRequest: LocationPermissionStatus.granted,
        );

        await tester.pumpWidget(
          app(auth: auth, backend: store, location: location),
        );
        await tester.pumpAndSettle();

        // 1) 계정 없이 쓰는 경로가 없다 — 첫 화면은 로그인이다.
        expect(find.byType(SignInScreen), findsOneWidget);
        expect(_homeFinder, findsNothing);

        // 2) 그 제공자로 로그인한다.
        await tester.tap(_buttonOf(provider));
        await tester.pumpAndSettle();

        // 3) 문서가 없는 계정이라 온보딩이 선다.
        expect(
          find.byType(TeamSelectScreen),
          findsOneWidget,
          reason: '문서가 없는 계정은 팀 선택으로 간다',
        );

        final hanwha = find.text('한화 이글스', skipOffstage: false);
        await tester.ensureVisible(hanwha);
        await tester.pumpAndSettle();
        await tester.tap(hanwha);
        await tester.pumpAndSettle();

        // 4) 팀을 고른 직후 위치 설명이 한 번 뜬다.
        expect(
          find.byType(LocationConsentScreen),
          findsOneWidget,
          reason: '온보딩에서 문서가 방금 만들어졌으므로 위치를 한 번 묻는다',
        );
        await tester.tap(find.text('위치 권한 허용하기'));
        await tester.pumpAndSettle();

        // 5) 홈에 닿는다.
        expect(_homeFinder, findsOneWidget);
        expect(location.requestCalls, 1);

        // 6) 그 사이에 서 있어야 할 사용자 문서 — 닉네임 씨앗이 **그 제공자가
        //    준 표시 이름**에서 왔는지가 2.2·2.3 과 2.4 의 이음매다.
        final uid = fakeUidOf(provider);
        expect(store.profileCreates, 1);
        final document = store.documents[uid];
        expect(document, isNotNull);
        expect(
          document![UserFields.nickname],
          seedNickname(uid: uid, displayName: auth.currentUser!.displayName),
        );
        expect(document[UserFields.favoriteTeamId], 'hanwha');
        expect(document[UserFields.board], isEmpty);
      });
    }
  });

  testWidgets('두 번째 실행: 문서도 위치 설명도 다시 서지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = FakeUserDataStore();
    addTearDown(store.dispose);
    final location = FakeLocationPermissionGateway(
      afterRequest: LocationPermissionStatus.granted,
    );

    final first = FakeAuthService();
    addTearDown(first.dispose);
    await tester.pumpWidget(
      app(auth: first, backend: store, location: location),
    );
    await tester.pumpAndSettle();
    await tester.tap(_buttonOf(AuthProviderId.google));
    await tester.pumpAndSettle();
    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();
    expect(_homeFinder, findsOneWidget);
    expect(store.profileCreates, 1);
    expect(location.requestCalls, 0, reason: '"나중에"는 OS 에 묻지 않는다');

    // --- 앱을 껐다 켠다: ProviderScope 를 통째로 새로 세우고, 기기 저장과
    //     서버 문서만 그대로 이어받는다 (그것이 콜드 스타트가 이어받는 전부다).
    final second = FakeAuthService(signedIn: first.currentUser);
    addTearDown(second.dispose);
    final secondLocation = FakeLocationPermissionGateway(
      afterRequest: LocationPermissionStatus.granted,
    );
    await tester.pumpWidget(
      app(auth: second, backend: store, location: secondLocation),
    );
    await tester.pumpAndSettle();

    expect(_homeFinder, findsOneWidget, reason: '팀이 정해진 계정의 두 번째 실행은 곧장 홈이다');
    expect(find.byType(TeamSelectScreen), findsNothing);
    expect(
      find.byType(LocationConsentScreen),
      findsNothing,
      reason: '온보딩 신호가 서는 자리는 문서를 실제로 만든 그 한 번뿐이다',
    );
    // step 5.2 — 온보딩 신호(LocationConsentScreen) 자신은 다시 묻지 않지만,
    // 이 파일의 schedule 이 항상 비어 있어 홈이 noGameToday 갈래에서 권한을
    // 한 번 다시 묻는다(`current_location.dart` docstring 참조). "온보딩이
    // 다시 서지 않는다"는 위 findsNothing 이 그대로 지킨다.
    expect(
      secondLocation.statusCalls,
      1,
      reason: '온보딩 재요청은 없다 — 홈의 noGameToday 재조회 하나뿐',
    );
    expect(store.profileCreates, 1, reason: '재로그인이 문서를 다시 만들지 않는다');
  });

  testWidgets('같은 기기를 다른 계정이 쓰면 앞사람의 팀도 앞사람의 신호도 넘어오지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = FakeUserDataStore();
    addTearDown(store.dispose);
    final location = FakeLocationPermissionGateway(
      afterRequest: LocationPermissionStatus.granted,
    );
    final auth = FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      app(auth: auth, backend: store, location: location),
    );
    await tester.pumpAndSettle();
    await tester.tap(_buttonOf(AuthProviderId.google));
    await tester.pumpAndSettle();
    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();
    expect(_homeFinder, findsOneWidget);

    // 로그아웃 → 다른 계정으로 로그인.
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);

    await tester.tap(_buttonOf(AuthProviderId.kakao));
    await tester.pumpAndSettle();

    expect(
      find.byType(TeamSelectScreen),
      findsOneWidget,
      reason: '새 계정에는 문서가 없다 — 앞사람의 기기 캐시가 그 사실을 덮으면 안 된다',
    );
    expect(
      _homeFinder,
      findsNothing,
      reason: '앞사람의 팀으로 홈에 들어가면 캐시의 소유권이 새는 것이다',
    );

    final lotte = find.text('롯데 자이언츠', skipOffstage: false);
    await tester.ensureVisible(lotte);
    await tester.pumpAndSettle();
    await tester.tap(lotte);
    await tester.pumpAndSettle();

    expect(
      find.byType(LocationConsentScreen),
      findsOneWidget,
      reason: '새 계정도 자기 위치 설명을 한 번 받는다',
    );
    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();

    expect(store.profileCreates, 2);
    expect(
      store.documents[fakeUidOf(
        AuthProviderId.google,
      )]![UserFields.favoriteTeamId],
      'hanwha',
      reason: '앞사람의 문서는 그대로다',
    );
    expect(
      store.documents[fakeUidOf(
        AuthProviderId.kakao,
      )]![UserFields.favoriteTeamId],
      'lotte',
    );
  });

  testWidgets('상한 셋이 한 실행에서 겹쳐도 사람은 예산 안에 홈에 닿는다', (tester) async {
    // 기기 캐시 읽기 · 서버 확인 · 위치 조회가 **동시에** 멎은 실행. 셋 다
    // 사람이 보는 화면을 붙잡고 있고, 셋의 상한이 차례로 걸린다.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = FakeUserDataStore(
      profileConfirmGrace: kProfileServerConfirmGrace,
    )..holdProfiles = true;
    addTearDown(store.dispose);
    final auth = FakeAuthService(
      signedIn: const AuthUser(uid: 'uid-stall', displayName: '원정러'),
    );
    addTearDown(auth.dispose);
    final location = FakeLocationPermissionGateway(statusNeverAnswers: true);

    await tester.pumpWidget(
      app(
        auth: auth,
        backend: store,
        location: location,
        cache: _UnendingCacheStore(),
      ),
    );
    await tester.pump();
    await tester.pump(SplashTokensProbe.splashSettle);

    expect(
      find.byType(TeamSelectScreen),
      findsNothing,
      reason: '아직 두 기다림이 다 살아 있다 — 여기서 갈래를 정하면 아는 값 없이 정하는 것이다',
    );
    await tester.pump(_beforeAnyBound);
    expect(find.byType(TeamSelectScreen), findsNothing);

    var elapsed = Duration.zero;
    while (elapsed < _journeyBudget &&
        find.byType(TeamSelectScreen).evaluate().isEmpty) {
      await tester.pump(_step);
      elapsed += _step;
    }
    expect(
      find.byType(TeamSelectScreen),
      findsOneWidget,
      reason: '기기 캐시와 서버 확인이 둘 다 멎어도 대기 화면은 예산 안에 끝난다',
    );
    // 팀 목록이 그려지기까지 한 프레임 — 여기서 재는 것은 목록이 오는 속도가
    // 아니라 갈래가 정해지기까지의 대기이므로 예산에 넣지 않는다.
    await tester.pump();
    await tester.pump();

    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pump();
    await tester.tap(hanwha);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // 위치 조회까지 멎은 실행 — 여기서 갇히면 앱을 다시 켜는 것 말고 길이 없다.
    var afterPick = Duration.zero;
    while (afterPick < _journeyBudget &&
        find.byType(LocationConsentScreen).evaluate().isEmpty) {
      await tester.pump(_step);
      afterPick += _step;
    }
    expect(
      find.byType(LocationConsentScreen),
      findsOneWidget,
      reason: '위치 조회가 멎어도 사람은 설명 화면에서 두 버튼 중 하나로 나간다',
    );
    expect(
      elapsed + afterPick,
      lessThanOrEqualTo(_journeyBudget),
      reason:
          '상한 셋이 겹친 실행의 총 대기 시간 — 하나하나가 견딜 길이여도 '
          '이어 붙이면 아닐 수 있다',
    );

    await tester.tap(find.text('나중에 할게요'));
    await tester.pump();
    expect(_homeFinder, findsOneWidget);
    // step 5.2 — 홈이 noGameToday 갈래(이 파일의 schedule 이 항상 비어
    // 있다)에서 권한을 다시 묻는데, 이 게이트웨이는 status() 가 끝나지
    // 않는 대역이라 그 재조회도 상한에서 빠져나와야 한다. 안 그러면 그
    // 타이머가 위젯 트리 해제 뒤까지 남아 "A Timer is still pending" 로
    // 시험이 깨진다(`current_location.dart` docstring 참조).
    await tester.pump(const Duration(seconds: 10));
    expect(store.documents['uid-stall'], isNotNull);
  });

  test('부팅 상한도 사람이 견딜 길이다 — 짝인 네 상한과 같은 못', () {
    // `boot_stall_probe_test.dart` 는 상한이 **있는지**만 잰다. 그 시험이 미는
    // 시간이 `kBootInitTimeout` 자신이라, 5초를 300초로 바꿔도 저 파일을 포함한
    // 전체가 초록불이었다(검증에서 실제로 주입해 확인했다). 짝인 네 상한
    // (`kAppCheckActivationTimeout`·`kProfileServerConfirmGrace`·
    // `kCachedTeamReadTimeout`·`kLocationPermissionTimeout`)에는 같은 모양의
    // 못이 각각 서 있는데 이 하나에만 없었다 — 다섯 중 빠져나갈 길이 가장 없는
    // 구간인데도(스플래시에는 문구도 버튼도 없다).
    expect(entrypoint.kBootInitTimeout, greaterThan(Duration.zero));
    expect(
      entrypoint.kBootInitTimeout,
      lessThanOrEqualTo(const Duration(seconds: 10)),
      reason:
          '이 값이 곧 사람이 스플래시 앞에 앉아 있는 최대 시간이다 — 그 화면에는 '
          '문구도 되돌아갈 길도 없고, 나갈 길은 앱을 다시 켜는 것뿐이다',
    );
    // 부팅 안에서 App Check 이 자기 상한을 다 무는 실행이 있으므로, 부팅의
    // 상한이 그보다 짧으면 App Check 쪽 상한은 영영 걸리지 않는다 — 두 상수가
    // 같은 실행에서 겹쳐 서는 관계를 여기 적어 둔다.
    expect(
      entrypoint.kBootInitTimeout,
      greaterThanOrEqualTo(kAppCheckActivationTimeout),
      reason:
          '부팅이 App Check 보다 먼저 잘리면 그 상한은 부팅 경로에서 아무 일도 '
          '하지 않는다 — 두 상수가 같은 뜻을 말하지 않게 된다',
    );
  });
}

/// 기기 저장을 **영영 돌려주지 않는** 캐시 — 멎은 플랫폼 채널의 대역.
class _UnendingCacheStore extends SelectedTeamStore {
  _UnendingCacheStore();

  @override
  Future<String?> read(String uid) => Completer<String?>().future;
}

/// 스플래시 연출이 끝나 루트 게이트가 서기까지 미는 시간.
///
/// 이 시험이 재는 것은 **게이트 뒤의** 상한들이라, 연출의 길이는 예산에서
/// 빼고 잰다.
abstract final class SplashTokensProbe {
  static const Duration splashSettle = Duration(seconds: 3);
}
