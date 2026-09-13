/// 통합 검증 탐침 — phase 3 의 머리 여정을 탭 골격 위에서 통째로 걷는다.
///
/// 3.1(5탭 골격) · 3.2(추천 목록의 좋아요 토글) · 3.3(좋아요 탭)이 각각이
/// 아니라 **함께** 성립하는지를 잰다:
///  1) 추천 탭에서 구장을 골라 들어가 하트를 누른다.
///  2) 좋아요 탭으로 옮기면 그 장소가 거기 있다(카테고리 묶음 포함).
///  3) 추천 탭으로 돌아오면 밀어 올린 구장 화면이 그대로고, 그 카드의
///     하트도 켜진 채다(탭 스택 보존 + 좋아요 상태 공유).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/likes/likes_tab_screen.dart';
import 'package:kbo_away_fans/features/places/stadium_places_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/ui/shared/like_button.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../location/fake_location_permission_gateway.dart';

const _uid = 'google-uid';

void main() {
  late StadiumsDocument stadiumsDoc;
  late FakeUserDataStore store;
  late FakeAuthService auth;

  setUpAll(() {
    stadiumsDoc = StadiumsDocument.fromJson(
      jsonDecode(File('content-pipeline/data/stadiums.json').readAsStringSync())
          as Map<String, Object?>,
    );
  });

  final placesDoc = PlacesDocument(
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = FakeUserDataStore();
    auth = FakeAuthService(
      signedIn: const AuthUser(uid: _uid, email: 'a@b.c'),
    );
    await store.createProfile(
      _uid,
      const NewUserProfile(nickname: '원정러', favoriteTeamId: 'lg'),
    );
  });

  tearDown(() async {
    await auth.dispose();
    await store.dispose();
  });

  Widget app() {
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
          (ref) async => ContentFresh<PlacesDocument>(placesDoc),
        ),
        teamsProvider.overrideWith(
          (ref) async => const ContentUnavailable<TeamsDocument>(
            ContentIssue(ContentIssueKind.network, 'fixture'),
          ),
        ),
        scheduleProvider.overrideWith(
          (ref) async => const ContentUnavailable<ScheduleDocument>(
            ContentIssue(ContentIssueKind.network, 'fixture'),
          ),
        ),
      ],
      child: const MaterialApp(home: MainTabsRoot()),
    );
  }

  testWidgets('추천 탭에서 누른 좋아요가 좋아요 탭에 뜨고, 돌아오면 추천 스택도 하트도 그대로다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // 다섯 탭이 다 서 있다 (3.1 acceptance).
    for (final label in ['홈', '배지', '추천', '좋아요', '마이페이지']) {
      expect(find.text(label), findsWidgets, reason: '$label 탭이 하단에 있어야 한다');
    }

    // 추천 탭 → 잠실 → 카드.
    await tester.tap(find.text('추천'));
    await tester.pumpAndSettle();
    final jamsil = stadiumsDoc.stadiums.firstWhere((s) => s.id == 'jamsil');
    await tester.tap(find.text(jamsil.name));
    await tester.pumpAndSettle();
    expect(find.byType(StadiumPlacesScreen), findsOneWidget);

    final card = find.widgetWithText(PlaceCard, '잠실 국밥집');
    await tester.tap(
      find.descendant(of: card, matching: find.byType(LikeButton)),
    );
    await tester.pumpAndSettle();
    expect((await store.readLikes(_uid)).single.placeId, 'jamsil-gukbap');

    // 좋아요 탭 — 방금 누른 장소가 있다.
    await tester.tap(find.text('좋아요'));
    await tester.pumpAndSettle();
    expect(find.byType(LikesTabScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LikesTabScreen),
        matching: find.text('잠실 국밥집'),
      ),
      findsOneWidget,
      reason: '추천 탭에서 누른 좋아요는 좋아요 탭에 곧바로 나타나야 한다',
    );
    expect(find.text(LikesTabScreen.emptyTitle), findsNothing);

    // 추천 탭으로 돌아오면 밀어 올린 화면이 그대로다 (3.1 acceptance).
    await tester.tap(find.text('추천'));
    await tester.pumpAndSettle();
    expect(
      find.byType(StadiumPlacesScreen).hitTestable(),
      findsOneWidget,
      reason: '탭을 옮겼다 돌아와도 그 탭의 스택은 그대로여야 한다',
    );
    expect(
      find.descendant(
        of: find.widgetWithText(PlaceCard, '잠실 국밥집'),
        matching: find.byIcon(LikeButton.likedIcon),
      ),
      findsOneWidget,
      reason: '같은 좋아요 집합을 보는 화면이라 하트가 켜진 채 남아야 한다',
    );
  });
}
