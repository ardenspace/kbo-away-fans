import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/content_loader.dart';
import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/dday_header.dart';
import '../../ui/shared/place_card.dart';
import '../../ui/shared/team_theme_scope.dart';
import '../team_select/team_select_screen.dart';
import 'next_away_game.dart';

/// 홈 화면 (step 2.3) — 다음 원정 경기 D-day 기본 얼굴.
///
/// - 앱 골격(앱바 등)은 응원 팀 테마([TeamThemeScope.forTeam]) 아래 렌더.
/// - D-day 헤더·원정 미리보기 영역은 **그 경기 홈팀** 테마의 중첩 스코프
///   아래 렌더 — 잠실처럼 홈팀이 2팀인 구장의 테마 전환 근거.
/// - schedule 문서를 못 얻으면 안내 + 재시도, 남은 일정이 없으면
///   명시적 빈 상태([DdayHeader.empty])를 띄운다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.teamId});

  /// 선택된 응원 팀 id (common.defs teamId).
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsDoc = _dataOf(ref.watch(teamsProvider));
    final stadiumsDoc = _dataOf(ref.watch(stadiumsProvider));
    final placesDoc = _dataOf(ref.watch(placesProvider));

    final scheduleAsync = ref.watch(scheduleProvider);
    final scheduleDoc = _dataOf(scheduleAsync);
    final next = scheduleDoc == null
        ? null
        : findNextAwayGame(
            schedule: scheduleDoc,
            teamId: teamId,
            now: ref.watch(clockProvider)(),
          );

    final team = teamsDoc?.byId(teamId);
    final scaffold = _HomeScaffold(
      team: team,
      teams: teamsDoc,
      stadiums: stadiumsDoc,
      places: placesDoc,
      next: next,
      scheduleLoading: scheduleDoc == null && scheduleAsync is AsyncLoading,
      onRetrySchedule: () => ref.invalidate(scheduleProvider),
    );
    if (team == null) return scaffold;
    return TeamThemeScope.forTeam(teamId: team.themeKey, child: scaffold);
  }
}

/// [ContentResult] 를 문서로 평탄화 — fresh/캐시는 데이터, 그 외 null.
T? _dataOf<T>(AsyncValue<ContentResult<T>> async) => switch (async) {
      AsyncData(:final value) => switch (value) {
          ContentFresh(:final data) || ContentFromCache(:final data) => data,
          ContentUnavailable() => null,
        },
      _ => null,
    };

/// 미리보기 카드의 카테고리 표시 문구 (필터 칩 로스터와 1:1).
const Map<PlaceCategory, String> _categoryLabels = {
  PlaceCategory.food: '맛집',
  PlaceCategory.cafe: '카페',
  PlaceCategory.escapeRoom: '방탈출',
  PlaceCategory.activity: '액티비티',
  PlaceCategory.landmark: '명소',
};

/// 미리보기에 보이는 장소 개수 상한 (discretion).
const int _previewPlaceCount = 3;

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({
    required this.team,
    required this.teams,
    required this.stadiums,
    required this.places,
    required this.next,
    required this.scheduleLoading,
    required this.onRetrySchedule,
  });

  /// 응원 팀 — teams 문서를 아직 얻지 못했으면 null.
  final Team? team;
  final TeamsDocument? teams;
  final StadiumsDocument? stadiums;
  final PlacesDocument? places;

  /// 다음 원정 경기 상태 — schedule 문서를 못 얻었으면 null.
  final NextAwayGame? next;

  /// schedule 이 아직 로드 중인지 (null 인 이유의 구분).
  final bool scheduleLoading;
  final VoidCallback onRetrySchedule;

  @override
  Widget build(BuildContext context) {
    final theme = TeamThemeScope.maybeOf(context);
    final barBg = theme?.primary ?? ColorTokens.surface;
    final barFg = theme?.onPrimary ?? ColorTokens.textPrimary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barBg,
        foregroundColor: barFg,
        title: Text(
          'KBO 원정 도장깨기',
          style: TextStyle(
            fontFamily: TypeTokens.fontFamily,
            fontSize: TypeTokens.heading,
            fontWeight: TypeTokens.weightExtraBold,
            color: barFg,
          ),
        ),
        actions: [
          // 팀 변경 진입점 (설정) — 같은 선택 화면을 변경 모드로 연다.
          IconButton(
            tooltip: '응원 팀 바꾸기',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TeamSelectScreen(isChange: true),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: SpaceTokens.xxl),
        children: [_face(context)],
      ),
    );
  }

  /// 기본 얼굴 — 다음 원정 상태에 따른 4갈래.
  Widget _face(BuildContext context) {
    return switch (next) {
      null => _scheduleFallback(),
      NoUpcomingAwayGame() => const DdayHeader.empty(),
      AwayGameToday(:final game) => _gameFace(game, dDay: 0),
      AwayGameUpcoming(:final game, :final dDay) => _gameFace(game, dDay: dDay),
    };
  }

  /// schedule 문서를 못 얻은 상태 — 로드 중이거나 실패 + 재시도.
  Widget _scheduleFallback() {
    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: scheduleLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '경기 일정을 불러오지 못했어요',
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
                  onPressed: onRetrySchedule,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
    );
  }

  /// 오늘([dDay] == 0) 또는 미래 원정 경기의 얼굴 — 헤더 + 원정 미리보기.
  /// 그 경기 **홈팀** 테마의 중첩 스코프로 감싼다.
  Widget _gameFace(Game game, {required int dDay}) {
    final stadium = stadiums?.byId(game.stadiumId);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DdayHeader(dDay: dDay, matchLabel: _matchLabel(game, stadium)),
        ..._preview(game, stadium),
      ],
    );

    final teamsDoc = teams;
    if (teamsDoc == null) return content;
    return TeamThemeScope.forTeam(
      teamId: themeKeyForGame(game, teamsDoc),
      child: content,
    );
  }

  /// 경기 정보 한 줄 (예: '8/30 (토) 사직야구장 · vs 롯데 · 18:30').
  String _matchLabel(Game game, Stadium? stadium) {
    final date = gameDateOf(game);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final where = stadium?.name ?? game.stadiumId;
    final opponent = teams?.byId(game.homeTeamId)?.shortName ?? game.homeTeamId;
    return '${date.month}/${date.day} (${weekdays[date.weekday - 1]}) '
        '$where · vs $opponent · ${game.startTime}';
  }

  /// 다음 원정 미리보기 — 목적지 구장의 추천 장소 몇 곳.
  List<Widget> _preview(Game game, Stadium? stadium) {
    final previewPlaces =
        (places?.forStadium(game.stadiumId) ?? const <Place>[])
            .take(_previewPlaceCount)
            .toList();

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.lg),
        child: Text(
          '${stadium?.city ?? ''} 원정 미리보기'.trim(),
          style: const TextStyle(
            fontFamily: TypeTokens.fontFamily,
            fontSize: TypeTokens.heading,
            fontWeight: TypeTokens.weightBold,
            color: ColorTokens.textPrimary,
          ),
        ),
      ),
      const SizedBox(height: SpaceTokens.sm),
      if (previewPlaces.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: SpaceTokens.lg),
          child: Text(
            '이 구장 주변 추천 장소를 준비하고 있어요.',
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.body,
              fontWeight: TypeTokens.weightMedium,
              color: ColorTokens.textSecondary,
            ),
          ),
        )
      else
        for (final place in previewPlaces)
          Padding(
            padding: const EdgeInsets.only(
              left: SpaceTokens.lg,
              right: SpaceTokens.lg,
              bottom: SpaceTokens.md,
            ),
            child: PlaceCard(
              name: place.name,
              categoryLabel: _categoryLabels[place.category]!,
              shoutoutSource: place.shoutout,
            ),
          ),
    ];
  }
}
