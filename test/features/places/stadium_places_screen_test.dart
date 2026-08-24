/// Step 3.1 추천 목록 위젯 테스트 — PlaceCard 뱃지 렌더,
/// 칩 탭 → 목록 즉시 갱신, 빈 카테고리의 명시적 빈 상태.
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
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/places/stadium_places_screen.dart';
import 'package:kbo_away_fans/ui/shared/category_chip.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';

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

  Widget screen() {
    return ProviderScope(
      overrides: [
        stadiumsProvider.overrideWith(
          (ref) async => ContentFresh<StadiumsDocument>(stadiumsDoc),
        ),
        placesProvider.overrideWith(
          (ref) async => ContentFresh<PlacesDocument>(placesDoc),
        ),
      ],
      child: const MaterialApp(
        home: StadiumPlacesScreen(stadiumId: 'jamsil'),
      ),
    );
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(CategoryChip, label));
    await tester.pumpAndSettle();
  }

  testWidgets('구장 장소만 뜨고, 샤라웃 장소의 PlaceCard 에 출처 뱃지가 렌더된다',
      (tester) async {
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
}
