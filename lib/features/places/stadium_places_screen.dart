import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../analytics/analytics.dart';
import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/category_chip.dart';
import '../../ui/shared/category_labels.dart';
import '../../ui/shared/map_links.dart';
import '../../ui/shared/place_card.dart';
import '../../ui/shared/place_detail_sheet.dart';
import '../../ui/shared/scratch_card.dart';
import '../../ui/shared/team_theme_scope.dart';
import 'place_filter.dart';
import 'place_map_screen.dart';
import 'scratch_pick.dart';

/// 구장 추천 목록 화면 (step 3.1 + 3.2).
///
/// [stadiumId] 구장의 추천 장소를 카테고리 칩 + 실내 필터로 보여준다.
/// - 칩 선택은 [filterPlaces] 를 거쳐 목록에 즉시 반영된다.
/// - 샤라웃 장소는 [PlaceCard] 의 출처 뱃지로 구분된다.
/// - 필터 결과 0건이면 명시적 빈 상태 문구를 띄운다.
/// - 목록 마지막 항목은 [ScratchCard]: 긁으면 현재 필터 풀에서
///   [pickScratchPlace] 로 뽑은 랜덤 장소가 드러난다. 풀이 비면 카드도 없다.
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

  /// 긁기 카드 랜덤 소스 (선택 규칙 자체는 [pickScratchPlace] 가 단위 테스트 커버).
  final Random _random = Random();

  /// 현재 긁기 카드에 숨겨진 장소 — 필터 풀에서 벗어나면 재선택된다.
  Place? _scratchPick;

  /// 필터 변경으로 재선택될 때 카드(커버) 상태를 리셋하는 키 카운터.
  int _scratchRound = 0;

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
    _syncScratchPick(filtered);
    final scratchPick = _scratchPick;

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
                  itemCount:
                      filtered.length + (scratchPick == null ? 0 : 1),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: SpaceTokens.md),
                  itemBuilder: (context, index) {
                    if (scratchPick != null && index == filtered.length) {
                      return ScratchCard(
                        key: ValueKey('scratch-round-$_scratchRound'),
                        hiddenLabel: scratchPick.name,
                        hiddenSublabel: categoryLabelOf(scratchPick.category),
                        onRescratch: () => setState(() {
                          _scratchPick = pickScratchPlace(filtered, _random);
                        }),
                      );
                    }
                    final place = filtered[index];
                    return PlaceCard(
                      name: place.name,
                      categoryLabel: categoryLabelOf(place.category),
                      shoutoutSource: place.shoutout,
                      onTap: () => _showDetailSheet(place),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 장소 상세 시트 — 지도 진입·길안내 딥링크·OS 공유의 진입점 (step 3.3).
  ///
  /// 성공 지표 계측: 카드 탭이 곧 `place_tap` (step 3.4).
  void _showDetailSheet(Place place) {
    ref.read(analyticsProvider).logPlaceTap(
          stadiumId: widget.stadiumId,
          category: place.category.contractValue,
        );
    PlaceDetailSheet.show(
      context,
      name: place.name,
      categoryLabel: categoryLabelOf(place.category),
      address: place.address,
      description: place.description,
      onOpenMap: () => _openMap(place),
      onDirections: () => launchNaverMapRoute(
        name: place.name,
        lat: place.lat,
        lng: place.lng,
      ),
      onShare: () => _share(place),
    );
  }

  /// 시트를 닫고 앱 내 지도 화면(구장·장소 마커)으로 진입한다.
  ///
  /// 성공 지표 계측: 이 전이가 곧 `map_open` (step 3.4).
  void _openMap(Place place) {
    ref.read(analyticsProvider).logMapOpen(
          stadiumId: widget.stadiumId,
          category: place.category.contractValue,
        );
    final stadium =
        contentDataOf(ref.read(stadiumsProvider))?.byId(widget.stadiumId);
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaceMapScreen(
          place: place,
          stadium: stadium,
          themeKey: widget.themeKey,
        ),
      ),
    );
  }

  /// OS 공유 시트 — 장소 이름 + 지도 링크 페이로드.
  Future<void> _share(Place place) {
    return SharePlus.instance.share(
      ShareParams(
        text: buildMapSharePayload(
          name: place.name,
          categoryLabel: categoryLabelOf(place.category),
        ),
      ),
    );
  }

  /// 긁기 카드의 숨김 장소를 현재 필터 풀과 동기화한다.
  ///
  /// - 풀이 비면 카드 비노출(null).
  /// - 기존 pick 이 풀을 벗어나면 재선택하고, 라운드 키를 올려 커버를 리셋한다.
  /// - 재긁기(onRescratch)의 재선택은 카드가 스스로 커버를 리셋하므로
  ///   라운드는 그대로 둔다.
  void _syncScratchPick(List<Place> pool) {
    if (pool.isEmpty) {
      _scratchPick = null;
      return;
    }
    final current = _scratchPick;
    if (current != null && pool.any((p) => p.id == current.id)) return;
    _scratchPick = pickScratchPlace(pool, _random);
    _scratchRound++;
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
