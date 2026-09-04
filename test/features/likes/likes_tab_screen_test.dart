/// Step 3.3 boundary tests — 좋아요 내역 탭.
///
/// 재는 갈래:
///  1) 빈 상태 — 좋아요가 하나도 없으면 명시적 빈 상태를 보여준다.
///  2) 카테고리 묶음 — 추천 탭과 같은 카테고리 순서([PlaceCategory.values])로
///     묶이고, 카테고리 안에서는 콘텐츠 순서를 보존한다.
///  3) 해제 시 즉시 제거 — 목록 안에서 좋아요를 풀면 그 카드가 바로 빠진다.
///  4) 항목을 탭하면 기존 [PlaceDetailSheet] 로 이어진다.
///  5) 시트 안에서 좋아요를 풀고 닫으면 목록이 즉시 갱신된다(3.2 의 스냅샷
///     시트가 남긴 이음매).
///  6) 콘텐츠에서 사라진 좋아요 장소는 조용히 걸러지고 화면이 깨지지 않는다.
///  7) "못 읽었다"(오류)와 "하나도 없다"(빈 데이터)는 다른 화면이다.
///  8) 이 탭이 있어도 `readLikes` 는 세션당 정확히 한 번뿐이다(토글을
///     반복해도 늘지 않는다).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/likes/likes_tab_screen.dart';
import 'package:kbo_away_fans/ui/shared/content_fallback.dart';
import 'package:kbo_away_fans/ui/shared/like_button.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';
import 'package:kbo_away_fans/ui/shared/place_detail_sheet.dart';

import '../../backend/fake_backend.dart';

const _uid = 'kakao:1234567890';

Place _place({
  required String id,
  required String name,
  required PlaceCategory category,
  String stadiumId = 'jamsil',
}) {
  return Place(
    id: id,
    stadiumId: stadiumId,
    name: name,
    category: category,
    indoor: true,
    source: 'curated',
    lat: 37.5,
    lng: 127.0,
  );
}

/// 좋아요 목록 읽기가 언제나 실패하는 대역 — "서버를 못 읽었다"의 대역
/// (`test/backend/liked_place_ids_test.dart` 의 `_FailingLikesStore` 와 같은
/// 모양).
class _FailingLikesStore extends FakeUserDataStore {
  @override
  Future<List<LikeRecord>> readLikes(String uid) async {
    likeReads++;
    throw const BackendNetworkError(code: 'unavailable');
  }
}

void main() {
  // 콘텐츠 등장 순서(activity → cafe → food)를 [PlaceCategory.values] 순서
  // (food → cafe → …→ activity)와 **일부러 어긋나게** 둔다 — 그렇지 않으면
  // "카테고리 순서는 enum 순서" 시험이 콘텐츠 등장 순서를 그대로 따라가는
  // 잘못된 구현에서도 우연히 통과해 버려, 실제로는 아무것도 재지 못한다.
  final placesDoc = PlacesDocument(
    places: [
      _place(id: 'jamsil-hangang', name: '한강 나들이', category: PlaceCategory.activity),
      _place(id: 'jamsil-cafe', name: '잠실 카페', category: PlaceCategory.cafe),
      _place(id: 'sajik-gukbap', name: '사직 국밥집', category: PlaceCategory.food, stadiumId: 'sajik'),
      _place(id: 'jamsil-gukbap', name: '잠실 국밥집', category: PlaceCategory.food),
    ],
  );

  late FakeUserDataStore store;
  late FakeAuthService auth;

  setUp(() {
    store = FakeUserDataStore();
    auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
  });

  tearDown(() async {
    await auth.dispose();
    await store.dispose();
  });

  Widget screen({UserDataStore? backend}) {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(backend ?? store),
        stadiumsProvider.overrideWith(
          (ref) async =>
              const ContentFresh<StadiumsDocument>(StadiumsDocument(stadiums: [])),
        ),
        placesProvider.overrideWith(
          (ref) async => ContentFresh<PlacesDocument>(placesDoc),
        ),
      ],
      child: const MaterialApp(home: LikesTabScreen()),
    );
  }

  testWidgets('좋아요가 하나도 없으면 명시적 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text(LikesTabScreen.emptyTitle), findsOneWidget);
    expect(find.text(LikesTabScreen.emptyMessage), findsOneWidget);
    expect(find.byType(PlaceCard), findsNothing);
    expect(find.text(LikesTabScreen.loadFailureTitle), findsNothing);
  });

  testWidgets('추천과 같은 카테고리 순서로 묶이고, 카테고리 안에서는 콘텐츠 순서를 보존한다', (tester) async {
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-hangang',
        stadiumId: 'jamsil',
        category: PlaceCategory.activity,
      ),
    );
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-cafe',
        stadiumId: 'jamsil',
        category: PlaceCategory.cafe,
      ),
    );
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'sajik-gukbap',
        stadiumId: 'sajik',
        category: PlaceCategory.food,
      ),
    );
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-gukbap',
        stadiumId: 'jamsil',
        category: PlaceCategory.food,
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsNWidgets(4));

    // 카테고리 순서는 PlaceCategory.values 순서(food → cafe → activity) —
    // 좋아요를 누른 순서(activity → cafe → food)와는 다르다. 카테고리 헤더는
    // 자기 키로 찾는다 — 같은 문구가 카드 안의 카테고리 라벨로도 뜬다.
    final foodHeaderY = tester
        .getTopLeft(find.byKey(const ValueKey('likes-category-food')))
        .dy;
    final cafeHeaderY = tester
        .getTopLeft(find.byKey(const ValueKey('likes-category-cafe')))
        .dy;
    final activityHeaderY = tester
        .getTopLeft(find.byKey(const ValueKey('likes-category-activity')))
        .dy;
    expect(foodHeaderY, lessThan(cafeHeaderY));
    expect(cafeHeaderY, lessThan(activityHeaderY));

    // '맛집' 안에서는 콘텐츠 등장 순서(사직 국밥집 → 잠실 국밥집)를
    // 보존한다 — 좋아요를 누른 순서(잠실 → 사직)와는 반대다.
    final jamsilY = tester.getTopLeft(find.text('잠실 국밥집')).dy;
    final sajikY = tester.getTopLeft(find.text('사직 국밥집')).dy;
    expect(sajikY, lessThan(jamsilY));
  });

  testWidgets('콘텐츠에서 사라진 좋아요 장소는 조용히 걸러지고 화면이 깨지지 않는다', (tester) async {
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'ghost-place',
        stadiumId: 'jamsil',
        category: PlaceCategory.food,
      ),
    );
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-cafe',
        stadiumId: 'jamsil',
        category: PlaceCategory.cafe,
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.byType(PlaceCard), findsOneWidget, reason: '사라진 장소 하나는 그릴 수 없어 빠진다');
    expect(find.text('잠실 카페'), findsOneWidget);
  });

  testWidgets('항목을 탭하면 기존 PlaceDetailSheet 로 이어진다', (tester) async {
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-cafe',
        stadiumId: 'jamsil',
        category: PlaceCategory.cafe,
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(PlaceCard, '잠실 카페'));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceDetailSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PlaceDetailSheet),
        matching: find.text('잠실 카페'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('목록에서 좋아요를 풀면 그 카드가 즉시 사라진다', (tester) async {
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-cafe',
        stadiumId: 'jamsil',
        category: PlaceCategory.cafe,
      ),
    );
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-gukbap',
        stadiumId: 'jamsil',
        category: PlaceCategory.food,
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));

    final card = find.widgetWithText(PlaceCard, '잠실 카페');
    await tester.tap(
      find.descendant(of: card, matching: find.byType(LikeButton)),
    );
    await tester.pumpAndSettle();

    expect(find.text('잠실 카페'), findsNothing);
    expect(find.byType(PlaceCard), findsOneWidget);
    expect(find.text('잠실 국밥집'), findsOneWidget, reason: '다른 카드는 그대로 남는다');
  });

  testWidgets('상세 시트에서 좋아요를 풀고 닫으면 목록이 즉시 갱신된다', (tester) async {
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-cafe',
        stadiumId: 'jamsil',
        category: PlaceCategory.cafe,
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(PlaceCard, '잠실 카페'));
    await tester.pumpAndSettle();

    final sheet = find.byType(PlaceDetailSheet);
    await tester.tap(
      find.descendant(of: sheet, matching: find.byType(LikeButton)),
    );
    await tester.pumpAndSettle();

    // 시트를 닫는다(시스템 뒤로가기와 같은 경로 — 바텀시트 바깥 탭).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(PlaceDetailSheet), findsNothing);
    expect(find.byType(PlaceCard), findsNothing, reason: '시트 안에서 이미 풀렸다');
    expect(find.text(LikesTabScreen.emptyTitle), findsOneWidget);
  });

  testWidgets('좋아요 목록을 못 읽으면 "못 읽었다" 안내를 보여준다 — 빈 상태와 다른 화면이다', (
    tester,
  ) async {
    final failing = _FailingLikesStore();
    addTearDown(failing.dispose);

    await tester.pumpWidget(screen(backend: failing));
    await tester.pumpAndSettle();

    expect(find.text(LikesTabScreen.loadFailureTitle), findsOneWidget);
    expect(find.text(ContentFallback.retryLabel), findsOneWidget);
    expect(find.text(LikesTabScreen.emptyTitle), findsNothing);
    expect(find.byType(PlaceCard), findsNothing);
  });

  testWidgets('이 탭이 있어도 readLikes 는 세션당 정확히 한 번 — 토글을 반복해도 늘지 않는다', (
    tester,
  ) async {
    await store.addLike(
      _uid,
      const LikeWrite(
        placeId: 'jamsil-cafe',
        stadiumId: 'jamsil',
        category: PlaceCategory.cafe,
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(store.likeReads, 1);

    final card = find.widgetWithText(PlaceCard, '잠실 카페');
    await tester.tap(
      find.descendant(of: card, matching: find.byType(LikeButton)),
    );
    await tester.pumpAndSettle();

    expect(store.likeReads, 1, reason: '토글은 집합만 고쳐 반영하고 다시 읽지 않는다');
  });
}
