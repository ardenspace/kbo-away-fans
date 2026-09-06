/// phase 3 통합 검증 탐침 — 네 단계(3.1 탭 골격 · 3.2 좋아요 토글 ·
/// 3.3 좋아요 탭 · 3.4 마이페이지)가 **한 앱 안에서 서로 맞물리는 자리**만
/// 잰다. 단일 단계 안에서 닫히는 성질은 각 단계의 경계 시험이 이미 잰다.
///
/// 재는 이음매:
///  1) 계정 전환 — 앞사람의 좋아요가 뒷사람의 좋아요 탭에 남지 않는다
///     (3.4 로그아웃/재로그인 × 3.2 세션 캐시 × 3.3 탭이 그 캐시를 그대로
///     화면으로 삼는다).
///  2) 프로필 색 변경(3.4)이 다른 탭(3.1)의 응원 팀을 건드리지 않는다.
///  3) 좋아요 탭(3.3)에서 마지막 하나를 풀면 빈 상태가 되고, 살아 있는
///     추천 탭(3.1 IndexedStack)의 그 카드 하트도 함께 꺼진다.
///  4) 좋아요를 못 읽은 화면(3.3)의 재시도 버튼이 실제로 회복시킨다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/auth/sign_in_screen.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/likes/likes_tab_screen.dart';
import 'package:kbo_away_fans/features/places/stadium_places_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/ui/shared/content_fallback.dart';
import 'package:kbo_away_fans/ui/shared/like_button.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';
import 'package:kbo_away_fans/ui/shared/social_sign_in_button.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend/fake_backend.dart';
import 'location/fake_location_permission_gateway.dart';

final String _googleUid = fakeUidOf(AuthProviderId.google);
final String _kakaoUid = fakeUidOf(AuthProviderId.kakao);

const ContentIssue _issue = ContentIssue(ContentIssueKind.network, 'fixture');

final PlacesDocument _placesDoc = PlacesDocument(
  places: [
    Place(
      id: 'jamsil-gukbap',
      stadiumId: 'jamsil',
      name: '잠실 국밥집',
      category: PlaceCategory.food,
      indoor: true,
      source: 'curated',
      lat: 37.5,
      lng: 127.0,
    ),
  ],
);

/// 시험이 실패/성공을 직접 여닫는 저장소 — 재시도가 **실제로 회복시키는지**는
/// 늘 실패하는 대역으로는 알 수 없다.
class _ControlledLikesStore extends FakeUserDataStore {
  bool failing = true;

  @override
  Future<List<LikeRecord>> readLikes(String uid) async {
    if (failing) {
      likeReads++;
      throw const BackendNetworkError(code: 'unavailable');
    }
    return super.readLikes(uid);
  }
}

void main() {
  late StadiumsDocument stadiumsDoc;
  setUpAll(() {
    stadiumsDoc = StadiumsDocument.fromJson(
      jsonDecode(File('content-pipeline/data/stadiums.json').readAsStringSync())
          as Map<String, Object?>,
    );
  });

  Widget scoped(AuthService auth, UserDataStore store, Widget home) {
    return ProviderScope(
      overrides: [
    // 홈 상단 위치 자리(5.2)가 판정이 없는 실행에서 권한을 한 번 묻는다 —
    // 대역이 없으면 실 플랫폼 채널이 물려 위젯 트리 해제 뒤까지 타이머가
    // 남는다(`lib/features/home/current_location.dart` docstring 참조).
    locationPermissionGatewayProvider.overrideWithValue(
      FakeLocationPermissionGateway(),
    ),
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        weatherEffectProvider.overrideWith(
          (ref, point) async => WeatherEffect.none,
        ),
        stadiumsProvider.overrideWith(
          (ref) async => ContentFresh<StadiumsDocument>(stadiumsDoc),
        ),
        placesProvider.overrideWith(
          (ref) async => ContentFresh<PlacesDocument>(_placesDoc),
        ),
        teamsProvider.overrideWith(
          (ref) async => const ContentUnavailable<TeamsDocument>(_issue),
        ),
        scheduleProvider.overrideWith(
          (ref) async => const ContentUnavailable<ScheduleDocument>(_issue),
        ),
      ],
      child: MaterialApp(home: home),
    );
  }

  Widget gateApp(AuthService auth, UserDataStore store) =>
      scoped(auth, store, const RootGate());

  Widget tabsApp(AuthService auth, UserDataStore store) =>
      scoped(auth, store, const MainTabsRoot());

  testWidgets('계정을 바꿔 로그인하면 앞사람의 좋아요가 뒷사람의 좋아요 탭에 남지 않는다', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeUserDataStore();
    addTearDown(store.dispose);
    for (final uid in [_googleUid, _kakaoUid]) {
      await store.createProfile(
        uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'lg',
          profileThemeKey: 'lg',
        ),
      );
    }
    // 앞사람(구글)만 좋아요를 하나 갖고 있다.
    await store.addLike(
      _googleUid,
      const LikeWrite(
        placeId: 'jamsil-gukbap',
        stadiumId: 'jamsil',
        category: PlaceCategory.food,
      ),
    );

    final auth = FakeAuthService(
      signedIn: AuthUser(uid: _googleUid, email: 'a@b.c'),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(gateApp(auth, store));
    await tester.pumpAndSettle();
    expect(find.byType(MainTabsRoot), findsOneWidget);

    await tester.tap(find.text('좋아요'));
    await tester.pumpAndSettle();
    expect(find.text('잠실 국밥집'), findsOneWidget, reason: '앞사람의 좋아요가 보인다');

    // 마이페이지에서 로그아웃한다.
    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-sign-out')));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);

    // 다른 계정(카카오)으로 로그인한다.
    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.kakao)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MainTabsRoot), findsOneWidget);

    await tester.tap(find.text('좋아요'));
    await tester.pumpAndSettle();
    expect(
      find.text('잠실 국밥집'),
      findsNothing,
      reason: '뒷사람의 좋아요 탭에 앞사람이 누른 장소가 남으면 안 된다',
    );
    expect(find.text(LikesTabScreen.emptyTitle), findsOneWidget);
  });

  testWidgets('프로필 색을 바꿔도 홈 탭의 응원 팀은 그대로다 (색과 팀은 다른 값이다)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeUserDataStore();
    addTearDown(store.dispose);
    await store.createProfile(
      _googleUid,
      const NewUserProfile(
        nickname: '원정러',
        favoriteTeamId: 'lg',
        profileThemeKey: 'lg',
      ),
    );
    final auth = FakeAuthService(
      signedIn: AuthUser(uid: _googleUid, email: 'a@b.c'),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(gateApp(auth, store));
    await tester.pumpAndSettle();
    expect(
      tester.widget<HomeScreen>(find.byType(HomeScreen)).teamId,
      'lg',
    );

    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-color-doosan')));
    await tester.pumpAndSettle();
    expect(store.documents[_googleUid]?[UserFields.profileThemeKey], 'doosan');

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<HomeScreen>(find.byType(HomeScreen)).teamId,
      'lg',
      reason: '프로필 색만 바꿨는데 홈 탭의 응원 팀이 따라 바뀌면 안 된다',
    );
  });

  testWidgets('좋아요 탭에서 마지막 하나를 풀면 빈 상태가 되고 추천 탭의 하트도 꺼진다', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = FakeUserDataStore();
    addTearDown(store.dispose);
    await store.createProfile(
      _googleUid,
      const NewUserProfile(
        nickname: '원정러',
        favoriteTeamId: 'lg',
        profileThemeKey: 'lg',
      ),
    );
    final auth = FakeAuthService(
      signedIn: AuthUser(uid: _googleUid, email: 'a@b.c'),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(tabsApp(auth, store));
    await tester.pumpAndSettle();

    // 추천 탭 → 잠실 → 하트를 켠다.
    await tester.tap(find.text('추천'));
    await tester.pumpAndSettle();
    final jamsil = stadiumsDoc.stadiums.firstWhere((s) => s.id == 'jamsil');
    await tester.tap(find.text(jamsil.name));
    await tester.pumpAndSettle();
    expect(find.byType(StadiumPlacesScreen), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(PlaceCard, '잠실 국밥집'),
        matching: find.byType(LikeButton),
      ),
    );
    await tester.pumpAndSettle();

    // 좋아요 탭에서 그 하나를 푼다.
    await tester.tap(find.text('좋아요'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(LikesTabScreen),
        matching: find.byType(LikeButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(LikesTabScreen.emptyTitle),
      findsOneWidget,
      reason: '마지막 좋아요를 풀면 빈 상태로 넘어가야 한다',
    );
    expect(store.likes[_googleUid], isEmpty);

    // 살아 있던 추천 탭으로 돌아오면 그 카드의 하트도 꺼져 있어야 한다.
    await tester.tap(find.text('추천'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(PlaceCard, '잠실 국밥집'),
        matching: find.byIcon(LikeButton.unlikedIcon),
      ),
      findsOneWidget,
      reason: '같은 집합을 보는 화면이라 좋아요 탭에서 푼 하트가 추천 탭에서도 꺼져야 한다',
    );
  });

  testWidgets('좋아요를 못 읽은 화면의 재시도 버튼이 실제로 목록을 되살린다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = _ControlledLikesStore();
    addTearDown(store.dispose);
    await store.createProfile(
      _googleUid,
      const NewUserProfile(
        nickname: '원정러',
        favoriteTeamId: 'lg',
        profileThemeKey: 'lg',
      ),
    );
    await store.addLike(
      _googleUid,
      const LikeWrite(
        placeId: 'jamsil-gukbap',
        stadiumId: 'jamsil',
        category: PlaceCategory.food,
      ),
    );
    final auth = FakeAuthService(
      signedIn: AuthUser(uid: _googleUid, email: 'a@b.c'),
    );
    addTearDown(auth.dispose);

    await tester.pumpWidget(tabsApp(auth, store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('좋아요'));
    await tester.pumpAndSettle();
    expect(find.text(LikesTabScreen.loadFailureTitle), findsOneWidget);

    // `likedPlaceIdsProvider` 는 이제 `authStateProvider`·`userProfileProvider`
    // 와 마찬가지로 `retry: (_, __) => null` 을 두어 자동 재시도가 꺼져
    // 있다 — 그래서 이 실패 갈래에서도 readLikes 는 정확히 1회다. 그 정확한
    // 1회를 못 박는 자리는 `test/backend/liked_place_ids_test.dart` 이고,
    // 이 파일은 여러 계층을 함께 걷는 여정 시험이라 재시도 정책이 나중에
    // 바뀌더라도 참이어야 하는 것 하나 — 그 재시도에 **상한이 있다**는
    // 것만 여기서는 일부러 느슨하게 잰다 (riverpod 기본값 = 최초 1회 +
    // 재시도 최대 10회, 대기 200ms~6.4초).
    expect(
      store.likeReads,
      lessThanOrEqualTo(11),
      reason: '재시도 정책이 나중에 바뀌어 실패한 읽기가 상한 없이 다시 불리면 못 읽는 세션이 서버 요청을 끝없이 낸다',
    );

    // 서버가 다시 답하기 시작하면 사람이 누르는 재시도가 실제로 회복시킨다.
    store.failing = false;
    await tester.tap(find.text(ContentFallback.retryLabel));
    await tester.pumpAndSettle();

    expect(
      find.text(LikesTabScreen.loadFailureTitle),
      findsNothing,
      reason: '재시도가 회복시키지 못하면 그 버튼은 아무것도 아닌 자리다',
    );
    expect(find.text('잠실 국밥집'), findsOneWidget);
  });
}
