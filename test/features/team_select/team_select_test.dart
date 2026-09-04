/// Step 2.2 boundary tests — 팀 선택 온보딩 위젯 테스트.
///
/// 팀 픽스처는 저장소의 `content-pipeline/data/teams.json` 실물을 그대로
/// 파싱해(계약 드리프트 방지) [teamsProvider] override 로 주입한다.
///
/// step 2.1 이후로는 로그인 게이트가 앞에 서므로 인증 상태도 함께 주입한다
/// ([FakeAuthService] 로 로그인한 실행) — 온보딩·홈 분기는 로그인 뒤의
/// 이야기이고, 그 분기 자체는 이 파일이 재던 그대로다.
///
/// step 2.4 부터 선택 팀의 원본은 사용자 문서다. 그래서 이 파일도 서버
/// 대역([FakeUserDataStore])을 함께 주입하고, shared_preferences mock 은
/// **첫 렌더용 캐시**를 제어하는 자리로 남는다 — 둘이 어긋날 때 화면이 무엇을
/// 그리는지가 이 단계의 계약이다.
///
/// 사람이 실제로 보는 것만 잴 수 있는 갈래가 둘 더 있다: 두 기다림(서버·기기
/// 저장) 중 **기기 저장 쪽이 끝나지 않는** 실행에서 대기 화면이 상한에서
/// 끝나는가, 그리고 서버에 남기지 못한 선택 뒤에 화면이 무엇으로 돌아오는가
/// (온보딩이면 팀 선택 화면, 변경 모드면 옛 팀의 테마).
library;

import 'dart:async';
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
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/features/team_select/team_select_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../location/fake_location_permission_gateway.dart';

/// 상한이 **있다면** 그 안에는 끝나야 하는 시간 — 상한이 있다는 사실을 재는
/// 케이스가 미는 시간이다. `kCachedTeamReadTimeout` 을 곱해 쓰지 않는 것은,
/// 그러면 상수를 키우는 변이가 미는 시간까지 함께 키워 그 케이스가 어떤 값도
/// 지키지 못하기 때문이다. 값 자체는 따로 잰다
/// ('기기 저장 읽기의 상한이 실제로 사람이 견딜 길이다').
const Duration _generousCacheBound = Duration(seconds: 10);

/// 서버에 이미 남아 있는 사용자 문서.
Map<String, Object?> serverDocument(String teamId) => <String, Object?>{
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

  setUp(() {
    store = FakeUserDataStore();
    addTearDown(store.dispose);
  });

  Widget app({
    SelectedTeamStore? cache,
    FakeUserDataStore? backend,
    LocationPermissionGateway? location,
  }) {
    // 홈이 소비하는 콘텐츠 provider 4종을 모두 override 한다 — 실제
    // 파일/네트워크 IO 는 widget test 의 fake async 안에서 완료되지 않아
    // pumpAndSettle 이 멈춘다. schedule 은 빈 일정(시즌 종료 빈 상태)으로
    // 고정해 이 테스트를 "현재 시각"과 무관하게 만든다.
    final emptySchedule =
        ScheduleDocument(generatedAt: DateTime.utc(2026), games: const []);
    // 로그인 게이트를 지나야 온보딩·홈이 나온다 — 로그인한 실행을 주입한다.
    final auth = FakeAuthService(
      signedIn: const AuthUser(uid: uid, displayName: '원정러'),
    );
    addTearDown(auth.dispose);
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(backend ?? store),
        if (cache != null) selectedTeamStoreProvider.overrideWithValue(cache),
        // step 2.5 — 기본값은 "이미 허용됨"이라, 이 파일의 기존 시험(위치
        // 권한과 무관한 온보딩·팀 변경 분기)은 위치 동의 화면을 아예 보지
        // 않고 곧장 홈으로 간다. 위치 권한 자체를 재는 시험은
        // `test/features/onboarding/location_consent_test.dart` 에 따로 있다.
        locationPermissionGatewayProvider.overrideWithValue(
          location ??
              FakeLocationPermissionGateway(
                initial: LocationPermissionStatus.granted,
              ),
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

  testWidgets('팀 선택 → 사용자 문서가 만들어지고 홈으로 넘어간다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    await tester.pumpAndSettle();

    // 원본은 사용자 문서다 — 다섯 필수 필드를 갖춰 한 번에 만들어진다.
    expect(store.profileCreates, 1);
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'hanwha');
    expect(store.documents[uid]![UserFields.profileThemeKey], 'hanwha');
    // 캐시도 따라간다 — 다음 콜드 스타트의 첫 프레임용.
    expect(await const SelectedTeamStore().read(uid), 'hanwha');
    // 선택 즉시 온보딩을 떠나 홈이 뜬다.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TeamSelectScreen), findsNothing);
  });

  testWidgets('서버에 문서가 있으면 온보딩을 건너뛰고 홈으로 간다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = serverDocument('lg');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(TeamSelectScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    // 서버가 든 팀의 테마가 걸려 있다 (themeKey 경유).
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    final expectedKey = teamsDoc.byId('lg')!.themeKey;
    expect(scope.theme.primary, TeamThemes.byId[expectedKey]!.primary);
  });

  testWidgets('첫 프레임은 캐시 값으로 그리고 서버 값이 오면 수렴한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // 캐시는 계정에 매여 있다 — 이 계정의 것으로 심어야 첫 프레임이 그려진다.
    await const SelectedTeamStore().write(uid, 'lg');
    store.documents[uid] = serverDocument('samsung');
    // 서버 스냅샷을 붙잡아 둔다 — 콜드 스타트의 "아직 모르는" 구간.
    store.holdProfiles = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    var scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    expect(
      scope.theme.primary,
      TeamThemes.byId[teamsDoc.byId('lg')!.themeKey]!.primary,
    );

    store.releaseProfiles();
    await tester.pumpAndSettle();

    scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    expect(
      scope.theme.primary,
      TeamThemes.byId[teamsDoc.byId('samsung')!.themeKey]!.primary,
    );
    expect(await const SelectedTeamStore().read(uid), 'samsung');
  });

  testWidgets('서버를 읽지 못해도 캐시 값으로 홈에 머무른다', (tester) async {
    // 이미 팀을 고른 사람을 통신 문제로 온보딩에 되돌려 세우지 않는다 —
    // 캐시를 남긴 이유가 그것이다. 캐시가 계정에 매여 있어서 이 갈래에 남의
    // 팀이 뜰 위험은 없다 (`selected_team_test.dart` 의 앞사람 캐시 시험).
    SharedPreferences.setMockInitialValues({});
    await const SelectedTeamStore().write(uid, 'lg');
    store.holdProfiles = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TeamSelectScreen), findsNothing);
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    expect(
      scope.theme.primary,
      TeamThemes.byId[teamsDoc.byId('lg')!.themeKey]!.primary,
    );
  });

  testWidgets('기기를 바꿔 로그인한 첫 왕복 구간에는 온보딩이 뜨지 않는다', (tester) async {
    // 캐시가 비어 있고 서버 문서는 있는데 첫 스냅샷이 아직 오지 않은 구간이다.
    // 캐시의 부재를 "팀 없음"으로 읽으면 이미 팀을 고른 사람이 그 구간 내내
    // 온보딩을 본다 — 그리고 거기서 팀을 누르면 자기 팀을 바꾸게 된다.
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = serverDocument('lotte');
    store.holdProfiles = true;
    await tester.pumpWidget(app());
    // 이 구간의 화면은 도는 스피너라 `pumpAndSettle` 이 멈추지 않는다 —
    // 스플래시 연출을 지나갈 만큼만 시간을 밀고 프레임을 본다.
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    // **여기서 한 프레임을 더 민다.** 앞 프레임의 위젯 트리는 아직
    // `authStateProvider` 가 로딩이던 것이라 루트 게이트가 대기 화면을 그렸고,
    // 세션이 확인되는 자리(`_SignedInGate`)는 그 프레임에 지어지지 않았다 —
    // 그 트리에 대고 단언하면 이 시험이 재려는 갈래를 아예 지나치지 않는다
    // (그 갈래를 온보딩으로 바꿔도 초록불이었다).
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(TeamSelectScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);

    store.releaseProfiles();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('서버가 상한 안에 아무 답도 주지 않으면 대기 화면이 끝난다', (tester) async {
    // 위 시험이 재는 구간의 **바닥**이다. 온라인에서 문서 리스너는 로컬 캐시에
    // 문서가 없으면 초기 스냅샷을 아예 올리지 않으므로(SDK 의
    // `shouldRaiseInitialEvent`), 기기를 바꿔 처음 로그인한 사람은 값이 하나도
    // 오지 않는 실행에 든다 — 그 구간이 상한에서 끝나지 않으면 앱을 다시
    // 띄우는 것 말고 나갈 길이 없다.
    const grace = Duration(seconds: 5);
    SharedPreferences.setMockInitialValues({});
    final graced = FakeUserDataStore(profileConfirmGrace: grace);
    addTearDown(graced.dispose);
    graced.documents[uid] = serverDocument('lotte');
    graced.holdProfiles = true;
    await tester.pumpWidget(app(backend: graced));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));

    // 상한 안에서는 아직 대기 화면이다.
    expect(find.byType(TeamSelectScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.pump(grace * 2);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byType(TeamSelectScreen),
      findsOneWidget,
      reason: '상한이 지났는데 대기 화면이 그대로다 — 사람이 스피너에 갇혔다',
    );

    // 상한이 지난 뒤에 진짜 답이 오면 그 답으로 수렴한다 — 상한은 갈래를
    // 정하는 바닥이지 사람을 옛 판단에 가두는 자물쇠가 아니다.
    graced.releaseProfiles();
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    expect(
      scope.theme.primary,
      TeamThemes.byId[teamsDoc.byId('lotte')!.themeKey]!.primary,
    );
  });

  testWidgets('기기 저장 읽기가 끝나지 않아도 대기 화면이 상한에서 끝난다', (tester) async {
    // 서버 쪽 기다림에는 상한이 있는데 기기 저장 쪽에는 없던 자리다. 캐시
    // 읽기가 끝나지 않으면 서버 상한이 지나 오류가 흐른 **뒤에도** 게이트가
    // 로딩을 그린다 — 앱을 다시 켜는 것 말고 나갈 길이 없는 상태이고, 그것이
    // App Check 활성화에 상한을 둔 까닭(`kAppCheckActivationTimeout`)과 같다.
    const grace = Duration(seconds: 5);
    SharedPreferences.setMockInitialValues({});
    final graced = FakeUserDataStore(profileConfirmGrace: grace);
    addTearDown(graced.dispose);
    graced.documents[uid] = serverDocument('lotte');
    graced.holdProfiles = true;
    await tester.pumpWidget(
      app(cache: _UnendingCacheStore(), backend: graced),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));

    // 두 기다림이 함께 시작한 자리다 — 아직은 대기 화면이 맞다.
    expect(find.byType(TeamSelectScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.pump(_generousCacheBound);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byType(TeamSelectScreen),
      findsOneWidget,
      reason: '기기 저장 읽기가 끝나지 않아 대기 화면이 그대로다 — 나갈 길이 없다',
    );
  });

  test('기기 저장 읽기의 상한이 실제로 사람이 견딜 길이다', () {
    // 바로 위 케이스는 상한이 **있는지**만 잰다. 그 시간을 상수로 세지 않는
    // 것은(예전에는 `kCachedTeamReadTimeout * 2` 였다) 상수를 키우는 변이가
    // 미는 시간까지 함께 키워 아무것도 지키지 못하기 때문이다 — 5초를 600초로
    // 바꿔도 전체가 초록불이었다. 이 값은 곧 기기를 바꿔 처음 로그인한 사람이
    // 대기 화면 앞에 앉아 있는 최대 시간이라, 길이 자체를 여기서 못 박는다.
    // 짝인 `kProfileServerConfirmGrace`·`kAppCheckActivationTimeout` 에 같은
    // 모양의 시험이 서 있다.
    expect(kCachedTeamReadTimeout, greaterThan(Duration.zero));
    expect(
      kCachedTeamReadTimeout,
      lessThanOrEqualTo(const Duration(seconds: 10)),
      reason: '늘리면 그만큼 대기 화면이 길어진다 — 서버 쪽이 이미 답한 실행에서도 '
          '갈래가 정해지지 않는다',
    );
  });

  testWidgets('물러선 선택은 그 자리에서 서버 값으로 수렴한다', (tester) async {
    // 온보딩이 뜬 채 서버에 문서가 이미 있는 상태에 이르는 주된 길이다:
    // 캐시가 비어 있고 스냅샷이 오류로 끝난 실행. 여기서 고른 팀은 이미 있는
    // 원본을 덮지 않는데(`selected_team.dart`), 그 갈래에는 **뒤이어 오는
    // 스냅샷이 없다** — 물러서기만 하고 아무 일도 하지 않으면 사람은 그 세션
    // 내내 고른 팀의 홈을 보다가 다음 콜드 스타트에서 설명 없이 옛 팀으로
    // 돌아온다.
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = serverDocument('lg');
    store.holdProfiles = true;
    await tester.pumpWidget(app());
    // 스냅샷을 기다리는 구간의 화면은 도는 스피너라 `pumpAndSettle` 이 멈추지
    // 않는다 — 스플래시와 그 뒤 전환을 지나갈 만큼만 시간을 민다. 게이트가
    // 실제로 서기 전에 오류를 흘리면 스냅샷을 구독한 자리가 아직 없어 그
    // 오류가 아무 데도 닿지 않는다.
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

    // 원본은 그대로고, 화면이 그 원본으로 수렴했다.
    expect(store.profileCreates, 0);
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'lg');
    expect(find.byType(HomeScreen), findsOneWidget);
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    expect(
      scope.theme.primary,
      TeamThemes.byId[teamsDoc.byId('lg')!.themeKey]!.primary,
      reason: '고른 팀의 테마가 그대로 남았다 — 물러선 자리에서 아무 일도 일어나지 않았다',
    );
    expect(await const SelectedTeamStore().read(uid), 'lg');
  });

  testWidgets('기기 저장을 읽지 못한 실행은 온보딩으로 간다', (tester) async {
    // 아는 값이 하나도 없는 실행이다 — 서버도 모르고 캐시도 읽지 못했다.
    // 이 갈래에 실제로 들어가는 것은 `SharedPreferences` 읽기가 던지는
    // 경우뿐이라, 그 대역이 없으면 게이트의 `AsyncError` 갈래를 대기 화면으로
    // 바꿔도 전 시험이 초록불이다.
    SharedPreferences.setMockInitialValues({});
    store.holdProfiles = true;
    await tester.pumpWidget(app(cache: const _UnreadableCacheStore()));
    await tester.pumpAndSettle();

    expect(find.byType(TeamSelectScreen), findsOneWidget);
  });

  testWidgets('팀 변경(설정 진입점) → primary 색이 새 팀 토큰과 일치한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = serverDocument('lg');
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
    // 서버 문서가 갱신되고(새로 만들지 않는다) 캐시도 따라갔다.
    expect(store.profileCreates, 0);
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'samsung');
    expect(store.documents[uid]![UserFields.profileThemeKey], 'samsung');
    expect(store.documents[uid]![UserFields.joinedAt], DateTime.utc(2026, 3, 1));
    expect(await const SelectedTeamStore().read(uid), 'samsung');
  });

  testWidgets('스냅샷이 오류로 끝난 세션에서도 팀 바꾸기가 원본을 갱신한다', (tester) async {
    // 사람은 "응원 팀 바꾸기"에서 팀을 골랐다. 그 선택까지 물러서면 화면이
    // 잠깐 새 팀으로 바뀌었다가 옛 팀으로 되돌아오고, 안내도 뜨지 않아 왜
    // 그런지 알 방법이 없다 — 물러서기는 **온보딩** 갈래의 장치다.
    SharedPreferences.setMockInitialValues({});
    await const SelectedTeamStore().write(uid, 'lg');
    store.documents[uid] = serverDocument('lg');
    store.holdProfiles = true;
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    // 이 세션은 사용자 문서를 끝내 보지 못한다 — 캐시가 홈을 그린다.
    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    final kt = find.text('kt wiz', skipOffstage: false);
    await tester.ensureVisible(kt);
    await tester.pumpAndSettle();
    await tester.tap(kt);
    await tester.pumpAndSettle();

    expect(
      store.documents[uid]![UserFields.favoriteTeamId],
      'kt',
      reason: '변경 모드의 선택이 물러서서 원본이 그대로다',
    );
    expect(store.documents[uid]![UserFields.profileThemeKey], 'kt');
    expect(store.profileCreates, 0);
    expect(await const SelectedTeamStore().read(uid), 'kt');
    expect(find.text(TeamSelectScreen.saveFailureNotice), findsNothing);
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    expect(
      scope.theme.primary,
      TeamThemes.byId[teamsDoc.byId('kt')!.themeKey]!.primary,
      reason: '화면이 옛 팀으로 되돌아왔다',
    );
  });

  testWidgets('서버에 남기지 못한 선택은 저장 실패 안내로 드러난다', (tester) async {
    // 사람이 보는 유일한 실패 안내다. 이 안내가 통째로 빠져도 다른 시험은
    // 전부 초록불이었다 — 그러면 선택이 서버에 닿지 못한 실행이 아무 말 없이
    // 지나가고, 다음 콜드 스타트에서 옛 팀이 돌아온다.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    await tester.pumpAndSettle();

    expect(find.text(TeamSelectScreen.saveFailureNotice), findsOneWidget);
    expect(store.documents, isEmpty);
  });

  testWidgets('서버에 남기지 못한 첫 선택은 온보딩으로 되돌아온다', (tester) async {
    // 안내는 뜨지만 화면이 고른 팀의 홈에 남으면, 사람은 자기 선택이 남았다고
    // 믿은 채 그 세션을 보내고 다음 콜드 스타트에서 온보딩을 다시 만난다.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
    final hanwha = find.text('한화 이글스', skipOffstage: false);
    await tester.ensureVisible(hanwha);
    await tester.pumpAndSettle();
    await tester.tap(hanwha);
    await tester.pumpAndSettle();

    expect(find.text(TeamSelectScreen.saveFailureNotice), findsOneWidget);
    expect(
      find.byType(TeamSelectScreen),
      findsOneWidget,
      reason: '서버에 남지 않은 팀의 홈이 그대로 떠 있다',
    );
    expect(find.byType(HomeScreen), findsNothing);
    expect(store.documents, isEmpty);
    expect(await const SelectedTeamStore().read(uid), isNull);
  });

  testWidgets('서버에 남기지 못한 변경은 홈의 테마도 옛 팀으로 되돌린다', (tester) async {
    // 되돌릴 값을 아는 갈래다 — 서버와 캐시가 모두 lg 를 들고 있다.
    SharedPreferences.setMockInitialValues({});
    await const SelectedTeamStore().write(uid, 'lg');
    store.documents[uid] = serverDocument('lg');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    final samsung = find.text('삼성 라이온즈', skipOffstage: false);
    await tester.ensureVisible(samsung);
    await tester.pumpAndSettle();
    await tester.tap(samsung);
    await tester.pumpAndSettle();

    expect(find.text(TeamSelectScreen.saveFailureNotice), findsOneWidget);
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'lg');
    expect(await const SelectedTeamStore().read(uid), 'lg');
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    expect(
      scope.theme.primary,
      TeamThemes.byId[teamsDoc.byId('lg')!.themeKey]!.primary,
      reason: '저장하지 못한 팀의 색이 홈에 남았다',
    );
  });

  testWidgets('팀 변경은 서버 왕복을 기다리지 않고 화면을 닫는다', (tester) async {
    // Firestore 쓰기의 Future 는 서버에 닿아야 끝난다. 그것을 기다렸다가 화면을
    // 닫으면 통신이 나쁜 자리에서 팀을 눌러도 변경 화면이 그대로 남아 선택이
    // 먹히지 않은 것처럼 보인다 — 그래서 `select` 을 부르고 **곧바로** 닫는다.
    SharedPreferences.setMockInitialValues({});
    final slow = _GatedPatchStore();
    addTearDown(slow.dispose);
    slow.documents[uid] = serverDocument('lg');
    await tester.pumpWidget(app(backend: slow));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    final samsung = find.text('삼성 라이온즈', skipOffstage: false);
    await tester.ensureVisible(samsung);
    await tester.pumpAndSettle();
    await tester.tap(samsung);
    await tester.pumpAndSettle();

    expect(
      slow.gate.isCompleted,
      isFalse,
      reason: '서버 쓰기가 아직 끝나지 않은 채로 재야 순서가 드러난다',
    );
    expect(
      find.byType(TeamSelectScreen),
      findsNothing,
      reason: '서버 왕복을 기다리느라 변경 화면이 남았다',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    final scope = tester.widget<TeamThemeScope>(find.byType(TeamThemeScope));
    expect(
      scope.theme.primary,
      TeamThemes.byId[teamsDoc.byId('samsung')!.themeKey]!.primary,
    );

    slow.gate.complete();
    await tester.pumpAndSettle();
    expect(slow.documents[uid]![UserFields.favoriteTeamId], 'samsung');
  });

  testWidgets('늦게 실패한 팀 바꾸기의 안내는 화면이 닫힌 뒤에도 닿는다', (tester) async {
    // 바로 위 케이스가 만든 순서의 뒷면이다: 변경 화면은 서버 왕복을 **기다리지
    // 않고** 닫히므로, 실패는 언제나 그 화면이 사라진 뒤에 온다. 그래서
    // `TeamSelectScreen._select` 는 `ScaffoldMessenger` 를 첫 await **앞에서**
    // 잡아 둔다 — 그 줄을 await 뒤로 옮기면 조회하는 context 가 이미 트리에서
    // 빠진 뒤라 안내가 아무 데도 닿지 못한다.
    //
    // 대역의 쓰기가 즉시 실패하는 다른 케이스들에는 이 구간이 아예 없어서(화면이
    // 닫히기 전에 실패가 이미 와 있다) 그 줄을 옮겨도 전부 초록불이었다. 여기서
    // 서버 왕복을 문으로 붙잡아 그 구간을 만든다.
    SharedPreferences.setMockInitialValues({});
    final slow = _GatedPatchStore(
      failure: const BackendNetworkError(code: 'unavailable'),
    );
    addTearDown(slow.dispose);
    slow.documents[uid] = serverDocument('lg');
    await tester.pumpWidget(app(backend: slow));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    final samsung = find.text('삼성 라이온즈', skipOffstage: false);
    await tester.ensureVisible(samsung);
    await tester.pumpAndSettle();
    await tester.tap(samsung);
    await tester.pumpAndSettle();

    expect(
      find.byType(TeamSelectScreen),
      findsNothing,
      reason: '이 케이스의 전제다 — 안내가 올 때 그 화면은 이미 없어야 한다',
    );
    expect(find.text(TeamSelectScreen.saveFailureNotice), findsNothing);

    // 서버가 이제야 답한다 — 실패로.
    slow.gate.complete();
    await tester.pumpAndSettle();

    expect(
      find.text(TeamSelectScreen.saveFailureNotice),
      findsOneWidget,
      reason: '화면이 닫힌 뒤에 온 실패가 조용히 지나가면, 사람은 팀이 바뀌었다고 '
          '믿은 채 다음 콜드 스타트에서 옛 팀을 만난다',
    );
  });
}

/// 문서 고치기를 붙잡아 두는 대역 — 서버 왕복이 끝나지 않은 구간이다.
/// [failure] 를 들려 보내면 그 왕복이 **늦게 실패하는** 실행이 된다.
class _GatedPatchStore extends FakeUserDataStore {
  _GatedPatchStore({this.failure});

  final BackendError? failure;

  final Completer<void> gate = Completer<void>();

  @override
  Future<void> patchProfile(String uid, UserProfilePatch patch) async {
    await gate.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    return super.patchProfile(uid, patch);
  }
}

/// 기기 저장 읽기가 **끝나지 않는** 캐시 — 플랫폼 채널이 멎은 실행의 대역.
/// 던지지도 답하지도 않는 자리라, 상한이 없으면 게이트가 영영 대기 화면이다.
class _UnendingCacheStore extends SelectedTeamStore {
  _UnendingCacheStore();

  @override
  Future<String?> read(String uid) => Completer<String?>().future;
}

/// 기기 저장을 **읽지 못하는** 캐시 — 저장 공간이 망가졌거나 플랫폼 채널이
/// 죽은 실행의 대역. 이 실패는 "선택 없음"과 같이 다룬다(아는 값이 하나도
/// 없으므로 게이트가 온보딩으로 읽는다).
class _UnreadableCacheStore extends SelectedTeamStore {
  const _UnreadableCacheStore();

  @override
  Future<String?> read(String uid) async {
    throw StateError('기기 저장을 읽을 수 없다');
  }
}
