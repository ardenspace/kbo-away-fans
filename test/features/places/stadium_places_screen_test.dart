/// Step 3.1 추천 목록 위젯 테스트 — PlaceCard 뱃지 렌더,
/// 칩 탭 → 목록 즉시 갱신, 빈 카테고리의 명시적 빈 상태.
/// Step 3.2 — 목록 마지막의 ScratchCard: 긁으면 현재 필터 풀 안의
/// 장소가 드러나고, 풀이 비면 카드가 아예 렌더되지 않는다.
/// Step 3.3 — 카드 탭 → PlaceDetailSheet 노출 → '지도에서 보기' →
/// 지도 화면(테스트 환경은 SDK 미초기화라 mock 자리 표시 래퍼)에
/// 구장·장소 마커가 뜬다.
/// Step 3.4 — mock 분석 래퍼로 성공 지표 계측 검증: 카드 탭 → place_tap
/// 정확히 1회, 지도 진입 → map_open 정확히 1회, 파라미터는
/// 구장 id·카테고리뿐.
///
/// Step 3.2 — 카드·상세 시트의 좋아요 버튼: 눌러서 즉시 반영, 카드가 여러
/// 장이어도 좋아요 목록은 한 번만 읽는다, 쓰기 실패는 되돌리고 안내한다.
///
/// stadiums 픽스처는 `content-pipeline/data/stadiums.json` 실물을 파싱해
/// 주입하고(계약 드리프트 방지), places 는 필터 시나리오가 결정적이도록
/// 직접 구성한다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/analytics/analytics.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/places/place_map_screen.dart';
import 'package:kbo_away_fans/features/places/stadium_places_screen.dart';
import 'package:kbo_away_fans/ui/shared/category_chip.dart';
import 'package:kbo_away_fans/ui/shared/like_button.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';
import 'package:kbo_away_fans/ui/shared/place_detail_sheet.dart';
import 'package:kbo_away_fans/ui/shared/scratch_card.dart';
import 'package:kbo_away_fans/ui/shared/stadium_map_view.dart';
import 'package:kbo_away_fans/ui/shared/weather_backdrop.dart';
import 'package:kbo_away_fans/weather/weather.dart';

import '../../analytics/recording_analytics.dart';
import '../../backend/fake_backend.dart';

Place place({
  required String id,
  required String name,
  required String stadium,
  required PlaceCategory category,
  bool indoor = true,
  String? shoutout,
}) {
  return Place(
    id: id,
    stadiumId: stadium,
    name: name,
    category: category,
    indoor: indoor,
    source: 'curated',
    lat: 37.5,
    lng: 127.0,
    shoutout: shoutout,
  );
}

void main() {
  late StadiumsDocument stadiumsDoc;

  setUpAll(() {
    stadiumsDoc = StadiumsDocument.fromJson(
      jsonDecode(File('content-pipeline/data/stadiums.json').readAsStringSync())
          as Map<String, Object?>,
    );
  });

  final placesDoc = PlacesDocument(
    places: [
      place(
        id: 'jamsil-gukbap',
        name: '잠실 국밥집',
        stadium: 'jamsil',
        category: PlaceCategory.food,
        shoutout: '@jamsil_foodie',
      ),
      place(
        id: 'jamsil-cafe',
        name: '잠실 카페',
        stadium: 'jamsil',
        category: PlaceCategory.cafe,
      ),
      place(
        id: 'jamsil-hangang',
        name: '한강 나들이',
        stadium: 'jamsil',
        category: PlaceCategory.activity,
        indoor: false,
      ),
      place(
        id: 'sajik-gukbap',
        name: '사직 국밥집',
        stadium: 'sajik',
        category: PlaceCategory.food,
      ),
    ],
  );

  Widget screen({
    RecordingAnalytics? analytics,
    String? themeKey,
    WeatherEffect weather = WeatherEffect.none,
    bool initialIndoorOnly = false,
    AuthService? auth,
    UserDataStore? backend,
  }) {
    return ProviderScope(
      overrides: [
        // 날씨는 실 네트워크 대신 시나리오 주입 (기본은 연출 없음).
        weatherEffectProvider.overrideWith((ref, point) async => weather),
        stadiumsProvider.overrideWith(
          (ref) async => ContentFresh<StadiumsDocument>(stadiumsDoc),
        ),
        placesProvider.overrideWith(
          (ref) async => ContentFresh<PlacesDocument>(placesDoc),
        ),
        // 계측이 실 백엔드로 새지 않게 항상 기록용 mock 래퍼로 갈아끼운다.
        analyticsProvider.overrideWithValue(analytics ?? RecordingAnalytics()),
        // 좋아요(3.2) 시나리오만 인증·백엔드 대역을 준다 — 나머지 시험은
        // 로그인 안 된 실행 그대로(좋아요 버튼은 뜨되 전부 꺼진 모습)다.
        if (auth != null) authServiceProvider.overrideWithValue(auth),
        if (backend != null) userDataStoreProvider.overrideWithValue(backend),
      ],
      child: MaterialApp(
        home: StadiumPlacesScreen(
          stadiumId: 'jamsil',
          themeKey: themeKey,
          initialIndoorOnly: initialIndoorOnly,
        ),
      ),
    );
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(CategoryChip, label));
    await tester.pumpAndSettle();
  }

  /// 카드 위·아래 두 줄을 가로로 끝까지 긁는다 (커버리지 임계를 확실히 넘김).
  Future<void> scratchAcross(WidgetTester tester, Finder finder) async {
    final rect = tester.getRect(finder);
    for (final fraction in [0.25, 0.75]) {
      final start = Offset(rect.left + 1, rect.top + rect.height * fraction);
      final gesture = await tester.startGesture(start);
      var traveled = 0.0;
      while (traveled < rect.width - 2) {
        await gesture.moveBy(const Offset(20, 0));
        traveled += 20;
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('구장 장소만 뜨고, 샤라웃 장소의 PlaceCard 에 출처 뱃지가 렌더된다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // 잠실 장소 3곳만 — 다른 구장(사직) 장소는 없다.
    expect(find.byType(PlaceCard), findsNWidgets(3));
    expect(find.text('잠실 국밥집'), findsOneWidget);
    expect(find.text('사직 국밥집'), findsNothing);

    // 샤라웃 출처 뱃지 — 그 카드 안에 출처 문구가 렌더된다.
    expect(
      find.descendant(
        of: find.widgetWithText(PlaceCard, '잠실 국밥집'),
        matching: find.text('@jamsil_foodie'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('카테고리 칩 탭이 목록에 즉시 반영된다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tapChip(tester, '카페');

    expect(find.byType(PlaceCard), findsOneWidget);
    expect(find.text('잠실 카페'), findsOneWidget);
    expect(find.text('잠실 국밥집'), findsNothing);

    // '전체'로 돌아오면 다시 3곳.
    await tapChip(tester, '전체');
    expect(find.byType(PlaceCard), findsNWidgets(3));
  });

  testWidgets('실내 필터 토글이 실외 장소를 즉시 걸러낸다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tapChip(tester, '실내만');

    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(find.text('한강 나들이'), findsNothing);

    // 토글 해제 시 복귀.
    await tapChip(tester, '실내만');
    expect(find.byType(PlaceCard), findsNWidgets(3));
  });

  testWidgets('initialIndoorOnly 진입 → 실내 필터가 켜진 채 열린다 (플랜B 경로)', (
    tester,
  ) async {
    await tester.pumpWidget(screen(initialIndoorOnly: true));
    await tester.pumpAndSettle();

    // '실내만' 칩이 켜진 상태로 시작한다.
    final indoorChip = tester.widget<CategoryChip>(
      find.widgetWithText(CategoryChip, '실내만'),
    );
    expect(indoorChip.selected, isTrue);

    // 실외 장소는 처음부터 걸러져 있다.
    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(find.text('한강 나들이'), findsNothing);

    // 토글을 풀면 전체가 돌아온다 (필터 조작은 그대로 가능).
    await tapChip(tester, '실내만');
    expect(find.byType(PlaceCard), findsNWidgets(3));
  });

  testWidgets('장소 0건 카테고리는 명시적 빈 상태가 뜬다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tapChip(tester, '방탈출');

    expect(find.byType(PlaceCard), findsNothing);
    expect(find.text('이 조건에 맞는 장소가 아직 없어요'), findsOneWidget);

    // 다른 칩을 고르면 빈 상태가 걷힌다.
    await tapChip(tester, '맛집');
    expect(find.text('이 조건에 맞는 장소가 아직 없어요'), findsNothing);
    expect(find.byType(PlaceCard), findsOneWidget);
  });

  testWidgets('목록 마지막 ScratchCard 를 긁으면 현재 필터 풀 안의 장소가 드러난다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // '카페' 필터 → 풀이 [잠실 카페] 하나뿐이라 랜덤 결과가 결정적이다.
    await tapChip(tester, '카페');
    expect(find.byType(ScratchCard), findsOneWidget);

    // 긁기 전에는 카드 안에 장소 정보가 없다 (목록의 PlaceCard 와 별개).
    Finder inScratchCard(String text) => find.descendant(
      of: find.byType(ScratchCard),
      matching: find.text(text),
    );
    expect(inScratchCard('잠실 카페'), findsNothing);
    expect(inScratchCard('오늘 뭐하지? 긁어 보기'), findsOneWidget);

    await scratchAcross(tester, find.byType(ScratchCard));

    expect(inScratchCard('잠실 카페'), findsOneWidget);
    expect(inScratchCard('카페'), findsOneWidget);
  });

  testWidgets('카드 탭 → 상세 시트 노출 → 지도 진입 시 구장·장소 마커(mock 래퍼)', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // 카드 탭 → PlaceDetailSheet 노출 (세 액션 포함).
    await tester.tap(find.widgetWithText(PlaceCard, '잠실 국밥집'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailSheet), findsOneWidget);
    expect(find.text('지도에서 보기'), findsOneWidget);
    expect(find.text('길안내'), findsOneWidget);
    expect(find.text('공유'), findsOneWidget);

    // '지도에서 보기' → 시트가 닫히고 지도 화면으로 진입.
    await tester.tap(find.text('지도에서 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceDetailSheet), findsNothing);
    expect(find.byType(PlaceMapScreen), findsOneWidget);

    // 테스트 환경은 SDK 미초기화 → mock(자리 표시) 래퍼 위에
    // 구장·장소 마커 라벨이 뜬다.
    final mapView = find.byType(StadiumMapView);
    expect(mapView, findsOneWidget);
    expect(
      find.descendant(of: mapView, matching: find.text('잠실 국밥집')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: mapView, matching: find.text('잠실야구장')),
      findsOneWidget,
    );
  });

  testWidgets('카드 탭 → place_tap 1회, 지도 진입 → map_open 1회 (mock 래퍼)', (
    tester,
  ) async {
    final analytics = RecordingAnalytics();
    await tester.pumpWidget(screen(analytics: analytics));
    await tester.pumpAndSettle();
    expect(analytics.events, isEmpty);

    // 카드 탭 → place_tap 정확히 1회 (map_open 은 아직 0회).
    await tester.tap(find.widgetWithText(PlaceCard, '잠실 국밥집'));
    await tester.pumpAndSettle();
    expect(analytics.countOf('place_tap'), 1);
    expect(analytics.countOf('map_open'), 0);
    expect(analytics.events.single.params, {
      'stadium_id': 'jamsil',
      'category': 'food',
    });

    // 지도 진입 → map_open 정확히 1회 (place_tap 은 그대로 1회).
    await tester.tap(find.text('지도에서 보기'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceMapScreen), findsOneWidget);
    expect(analytics.countOf('place_tap'), 1);
    expect(analytics.countOf('map_open'), 1);
    expect(analytics.events.last.params, {
      'stadium_id': 'jamsil',
      'category': 'food',
    });
    expect(analytics.events, hasLength(2));
  });

  testWidgets('themeKey 전달 시 앱바가 그 팀 primary 로 렌더된다', (tester) async {
    await tester.pumpWidget(screen(themeKey: 'lotte'));
    await tester.pumpAndSettle();

    final theme = TeamThemes.byId['lotte']!;
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, theme.primary);
    expect(appBar.foregroundColor, theme.onPrimary);
  });

  testWidgets('themeKey 가 없으면 앱바는 기본 토큰(surface)으로 렌더된다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, ColorTokens.surface);
    expect(appBar.foregroundColor, ColorTokens.textPrimary);
  });

  testWidgets('구장이 비 오는 날이면 추천 목록 배경에 비 레이어가 뜬다', (tester) async {
    await tester.pumpWidget(screen(weather: WeatherEffect.rain));
    // RainLayer 는 repeat 애니메이션이라 pumpAndSettle 대신 고정 pump.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(WeatherBackdrop), findsOneWidget);
    expect(find.byType(RainLayer), findsOneWidget);
    // 여정(추천 목록)은 그대로 정상 렌더된다.
    expect(find.byType(PlaceCard), findsNWidgets(3));
  });

  testWidgets('날씨가 비가 아니면(실패 포함 기본값) 비 레이어가 없다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.byType(WeatherBackdrop), findsOneWidget);
    expect(find.byType(RainLayer), findsNothing);
  });

  testWidgets('필터 풀이 비면 ScratchCard 도 렌더되지 않는다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // 잠실 풀이 있으면 카드가 있다.
    expect(find.byType(ScratchCard), findsOneWidget);

    // 장소 0건 카테고리 → 빈 상태 + 카드 비노출.
    await tapChip(tester, '방탈출');
    expect(find.byType(PlaceCard), findsNothing);
    expect(find.byType(ScratchCard), findsNothing);

    // 풀이 돌아오면 카드도 돌아온다.
    await tapChip(tester, '전체');
    expect(find.byType(ScratchCard), findsOneWidget);
  });

  group('좋아요 토글 (step 3.2)', () {
    const uid = 'kakao:1234567890';

    late FakeUserDataStore store;
    late FakeAuthService auth;

    setUp(() {
      store = FakeUserDataStore();
      auth = FakeAuthService(signedIn: const AuthUser(uid: uid));
    });

    tearDown(() async {
      await auth.dispose();
      await store.dispose();
    });

    /// 카드 안의 좋아요 버튼 (카드 탭 자체와 겹치지 않게 카드 안에서 찾는다).
    Finder likeButtonIn(Finder ancestor) =>
        find.descendant(of: ancestor, matching: find.byType(LikeButton));

    testWidgets('카드마다 좋아요 버튼이 뜨고, 눌러서 즉시 반영되며 서버 문서로 남는다', (tester) async {
      await tester.pumpWidget(screen(auth: auth, backend: store));
      await tester.pumpAndSettle();

      final card = find.widgetWithText(PlaceCard, '잠실 국밥집');
      expect(likeButtonIn(card), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byIcon(LikeButton.likedIcon)),
        findsNothing,
        reason: '처음엔 아무도 안 눌렀다',
      );

      await tester.tap(likeButtonIn(card));
      await tester.pump(); // 응답 전 — 낙관적 반영만 보인다.
      expect(
        find.descendant(of: card, matching: find.byIcon(LikeButton.likedIcon)),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(await store.readLikes(uid), hasLength(1));
      expect((await store.readLikes(uid)).single.placeId, 'jamsil-gukbap');
    });

    testWidgets('카드가 여러 장이어도 좋아요 목록은 한 번만 읽는다', (tester) async {
      await tester.pumpWidget(screen(auth: auth, backend: store));
      await tester.pumpAndSettle();

      expect(find.byType(PlaceCard), findsNWidgets(3), reason: '카드 세 장의 전제');
      expect(store.likeReads, 1);
    });

    testWidgets('상세 시트에도 좋아요 버튼이 뜨고 그 자리에서 눌러도 반영된다', (tester) async {
      await tester.pumpWidget(screen(auth: auth, backend: store));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PlaceCard, '잠실 국밥집'));
      await tester.pumpAndSettle();
      final sheet = find.byType(PlaceDetailSheet);
      expect(likeButtonIn(sheet), findsOneWidget);

      await tester.tap(likeButtonIn(sheet));
      await tester.pumpAndSettle();

      expect(await store.readLikes(uid), hasLength(1));
    });

    testWidgets('좋아요 쓰기가 실패하면 되돌리고 안내를 띄운다', (tester) async {
      store.likeWriteFailure = const BackendNetworkError(code: 'unavailable');
      await tester.pumpWidget(screen(auth: auth, backend: store));
      await tester.pumpAndSettle();

      final card = find.widgetWithText(PlaceCard, '잠실 국밥집');
      await tester.tap(likeButtonIn(card));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: card, matching: find.byIcon(LikeButton.likedIcon)),
        findsNothing,
        reason: '실패했으므로 눌리기 전 모습으로 되돌아간다',
      );
      expect(find.text(StadiumPlacesScreen.likeFailureNotice), findsOneWidget);
      expect(await store.readLikes(uid), isEmpty);
    });
  });
}
