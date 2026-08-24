import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/category_chip.dart';
import '../../ui/shared/category_labels.dart';
import '../../ui/shared/place_card.dart';
import '../../ui/shared/place_detail_sheet.dart';
import '../../ui/shared/team_theme_scope.dart';
import 'place_filter.dart';

/// 구장 추천 목록 화면 (step 3.1).
///
/// [stadiumId] 구장의 추천 장소를 카테고리 칩 + 실내 필터로 보여준다.
/// - 칩 선택은 [filterPlaces] 를 거쳐 목록에 즉시 반영된다.
/// - 샤라웃 장소는 [PlaceCard] 의 출처 뱃지로 구분된다.
/// - 필터 결과 0건이면 명시적 빈 상태 문구를 띄운다.
/// - [themeKey] 가 있으면 화면 전체를 그 팀 테마([TeamThemeScope])로 감싼다
///   (홈에서 진입 시 그 경기 홈팀 테마를 이어받는 근거).
class StadiumPlacesScreen extends ConsumerStatefulWidget {
  const StadiumPlacesScreen({
    super.key,
    required this.stadiumId,
    this.themeKey,
  });

  /// 대상 구장 id (common.defs stadiumId).
  final String stadiumId;

  /// 화면에 적용할 팀 테마 키 (null 이면 기본 토큰).
  final String? themeKey;

  @override
  ConsumerState<StadiumPlacesScreen> createState() =>
      _StadiumPlacesScreenState();
}

class _StadiumPlacesScreenState extends ConsumerState<StadiumPlacesScreen> {
  /// 선택된 카테고리 — null 이면 전체.
  PlaceCategory? _category;

  /// 실내만 보기 (우천 플랜B 필터).
  bool _indoorOnly = false;

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesProvider);
    final placesDoc = contentDataOf(placesAsync);
    final stadiumsDoc = contentDataOf(ref.watch(stadiumsProvider));
    final stadium = stadiumsDoc?.byId(widget.stadiumId);

    final body = placesDoc == null
        ? _placesFallback(loading: placesAsync is AsyncLoading)
        : _placesBody(placesDoc);

    final scaffold = Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: _appBar(context, stadium),
      body: body,
    );

    final themeKey = widget.themeKey;
    if (themeKey == null) return scaffold;
    return TeamThemeScope.forTeam(teamId: themeKey, child: scaffold);
  }

  PreferredSizeWidget _appBar(BuildContext context, Stadium? stadium) {
    final theme = TeamThemeScope.maybeOf(context);
    final barBg = theme?.primary ?? ColorTokens.surface;
    final barFg = theme?.onPrimary ?? ColorTokens.textPrimary;
    return AppBar(
      backgroundColor: barBg,
      foregroundColor: barFg,
      title: Text(
        '${stadium?.name ?? widget.stadiumId} 주변 추천',
        style: TextStyle(
          fontFamily: TypeTokens.fontFamily,
          fontSize: TypeTokens.heading,
          fontWeight: TypeTokens.weightExtraBold,
          color: barFg,
        ),
      ),
    );
  }

  /// places 문서를 못 얻은 상태 — 로드 중 또는 실패 + 재시도.
  Widget _placesFallback({required bool loading}) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '추천 장소를 불러오지 못했어요',
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.title,
              fontWeight: TypeTokens.weightExtraBold,
              color: ColorTokens.textPrimary,
            ),
          ),
          const SizedBox(height: SpaceTokens.sm),
          const Text(
            '네트워크를 확인하고 다시 시도해 주세요.',
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.body,
              fontWeight: TypeTokens.weightMedium,
              color: ColorTokens.textSecondary,
            ),
          ),
          const SizedBox(height: SpaceTokens.md),
          FilledButton(
            onPressed: () => invalidateContent(ref),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _placesBody(PlacesDocument doc) {
    final filtered = filterPlaces(
      doc.places,
      stadiumId: widget.stadiumId,
      category: _category,
      indoorOnly: _indoorOnly,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filterChips(),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    SpaceTokens.lg,
                    SpaceTokens.sm,
                    SpaceTokens.lg,
                    SpaceTokens.xxl,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: SpaceTokens.md),
                  itemBuilder: (context, index) {
                    final place = filtered[index];
                    return PlaceCard(
                      name: place.name,
                      categoryLabel: categoryLabelOf(place.category),
                      shoutoutSource: place.shoutout,
                      onTap: () => PlaceDetailSheet.show(
                        context,
                        name: place.name,
                        categoryLabel: categoryLabelOf(place.category),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 카테고리 칩 로스터('전체' + enum 5종) + 실내 필터 칩.
  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: SpaceTokens.lg,
        vertical: SpaceTokens.md,
      ),
      child: Row(
        children: [
          CategoryChip(
            label: '전체',
            selected: _category == null,
            onTap: () => setState(() => _category = null),
          ),
          for (final category in PlaceCategory.values) ...[
            const SizedBox(width: SpaceTokens.sm),
            CategoryChip(
              label: categoryLabelOf(category),
              selected: _category == category,
              onTap: () => setState(() => _category = category),
            ),
          ],
          const SizedBox(width: SpaceTokens.md),
          CategoryChip(
            label: '실내만',
            selected: _indoorOnly,
            onTap: () => setState(() => _indoorOnly = !_indoorOnly),
          ),
        ],
      ),
    );
  }

  /// 필터 결과 0건의 명시적 빈 상태.
  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '이 조건에 맞는 장소가 아직 없어요',
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.heading,
              fontWeight: TypeTokens.weightBold,
              color: ColorTokens.textPrimary,
            ),
          ),
          SizedBox(height: SpaceTokens.sm),
          Text(
            '다른 카테고리를 고르거나 실내 필터를 풀어 보세요.',
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.body,
              fontWeight: TypeTokens.weightMedium,
              color: ColorTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
