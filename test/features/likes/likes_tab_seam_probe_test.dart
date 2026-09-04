/// 통합 검증 탐침 — 좋아요 탭(3.3)의 목록과 `LikeButton`(3.2)의 낙관적 지역
/// 상태가 만나는 이음매.
///
/// 3.3 은 카드마다 `liked: true` 를 **상수로** 넘긴다(목록에 있는 것은 전부
/// 좋아요한 것이므로 그 자리에서는 참이다). 3.2 의 [LikeButton] 은 자기
/// `_liked` 를 지역 상태로 들고 있고, 바깥 값이 **바뀔 때만**
/// (`didUpdateWidget` 의 `widget.liked != oldWidget.liked`) 그 값을 따라간다.
/// 두 사실이 겹치면, 같은 카테고리 안에서 앞 카드를 풀었을 때 그 카드의
/// element 가 (키가 없어 위치로 짝지어져) 뒤 카드의 위젯을 받아 **뒤 카드가
/// 앞 카드의 꺼진 하트를 물려받는다** — 여전히 좋아요한 장소인데 하트가
/// 비어 보인다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/likes/likes_tab_screen.dart';
import 'package:kbo_away_fans/ui/shared/like_button.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';

import '../../backend/fake_backend.dart';

const _uid = 'kakao:1234567890';

Place _place({
  required String id,
  required String name,
  required PlaceCategory category,
}) {
  return Place(
    id: id,
    stadiumId: 'jamsil',
    name: name,
    category: category,
    indoor: true,
    source: 'curated',
    lat: 37.5,
    lng: 127.0,
  );
}

void main() {
  // 같은 카테고리(맛집) 안에 둘, 콘텐츠 순서는 첫째 → 둘째.
  final placesDoc = PlacesDocument(
    places: [
      _place(id: 'first-food', name: '첫째 국밥집', category: PlaceCategory.food),
      _place(id: 'second-food', name: '둘째 국밥집', category: PlaceCategory.food),
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

  Widget screen() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        stadiumsProvider.overrideWith(
          (ref) async => const ContentFresh<StadiumsDocument>(
            StadiumsDocument(stadiums: []),
          ),
        ),
        placesProvider.overrideWith(
          (ref) async => ContentFresh<PlacesDocument>(placesDoc),
        ),
      ],
      child: const MaterialApp(home: LikesTabScreen()),
    );
  }

  testWidgets('같은 카테고리에서 앞 카드를 풀어도 남은 카드의 하트는 켜진 채다', (tester) async {
    for (final id in ['first-food', 'second-food']) {
      await store.addLike(
        _uid,
        LikeWrite(
          placeId: id,
          stadiumId: 'jamsil',
          category: PlaceCategory.food,
        ),
      );
    }

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));

    // 앞 카드(첫째 국밥집)의 좋아요를 푼다.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(PlaceCard, '첫째 국밥집'),
        matching: find.byType(LikeButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('첫째 국밥집'), findsNothing);
    expect(find.text('둘째 국밥집'), findsOneWidget);

    // 서버는 여전히 둘째를 좋아요로 들고 있다.
    final remaining = await store.readLikes(_uid);
    expect(remaining.map((e) => e.placeId), ['second-food']);

    // 그런데 화면의 하트는?
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.widgetWithText(PlaceCard, '둘째 국밥집'),
        matching: find.byType(Icon),
      ),
    );
    expect(
      icon.icon,
      LikeButton.likedIcon,
      reason: '남은 카드는 여전히 좋아요한 장소이므로 하트가 채워져 있어야 한다',
    );
  });
}
