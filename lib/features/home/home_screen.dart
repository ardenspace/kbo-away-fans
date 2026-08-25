import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/category_labels.dart';
import '../../ui/shared/dday_header.dart';
import '../../ui/shared/place_card.dart';
import '../../ui/shared/stadium_picker.dart';
import '../../ui/shared/team_theme_scope.dart';
import '../../ui/shared/weather_backdrop.dart';
import '../../weather/weather.dart';
import '../places/stadium_places_screen.dart';
import '../team_select/team_select_screen.dart';
import 'next_away_game.dart';
import 'stadium_browse.dart';

/// 홈 화면 (step 2.3) — 다음 원정 경기 D-day 기본 얼굴.
///
/// - 앱 골격(앱바 등)은 응원 팀 테마([TeamThemeScope.forTeam]) 아래 렌더.
/// - D-day 헤더·원정 미리보기 영역은 **그 경기 홈팀** 테마의 중첩 스코프
///   아래 렌더 — 잠실처럼 홈팀이 2팀인 구장의 테마 전환 근거.
/// - schedule 문서를 못 얻으면 안내 + 재시도, 남은 일정이 없으면
///   명시적 빈 상태([DdayHeader.empty])를 띄운다.
/// - 오늘 원정 경기가 취소(우천 포함)된 날은 플랜B 배너가 얼굴 위에 떠서
///   실내 놀거리 추천(실내 필터 켠 추천 목록)으로 유도한다 (step 4.2).
/// - 하단에는 "구장 골라 구경하기"([StadiumPicker]) 섹션이 상시 떠서
///   경기 없는 날에도 아무 구장의 테마·추천을 구경할 수 있다 (step 4.3).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.teamId});

  /// 선택된 응원 팀 id (common.defs teamId).
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsDoc = contentDataOf(ref.watch(teamsProvider));
    final stadiumsDoc = contentDataOf(ref.watch(stadiumsProvider));
    final placesDoc = contentDataOf(ref.watch(placesProvider));

    final scheduleAsync = ref.watch(scheduleProvider);
    final scheduleDoc = contentDataOf(scheduleAsync);
    final now = ref.watch(clockProvider)();
    final next = scheduleDoc == null
        ? null
        : findNextAwayGame(schedule: scheduleDoc, teamId: teamId, now: now);

    // 오늘 원정 경기가 취소(우천 포함)됐으면 플랜B 모드 (step 4.2).
    final canceledToday = scheduleDoc == null
        ? null
        : findTodayCanceledAwayGame(
            schedule: scheduleDoc,
            teamId: teamId,
            now: now,
          );

    // 목적지 구장 좌표의 날씨 → 비 연출 (step 4.1).
    // 플랜B 날엔 오늘 취소된 경기의 구장이 목적지 — 비 연출과 플랜B 유도가
    // 함께 동작한다. 날씨 실패는 래퍼가 "연출 없음"으로 흡수한다.
    final destinationGame = canceledToday ??
        switch (next) {
          AwayGameToday(:final game) || AwayGameUpcoming(:final game) => game,
          _ => null,
        };
    final destination = destinationGame == null
        ? null
        : stadiumsDoc?.byId(destinationGame.stadiumId);
    final raining = destination != null &&
        weatherEffectOf(ref.watch(
              weatherEffectProvider(
                (lat: destination.lat, lng: destination.lng),
              ),
            )) ==
            WeatherEffect.rain;

    final team = teamsDoc?.byId(teamId);
    final scaffold = _HomeScaffold(
      team: team,
      teams: teamsDoc,
      stadiums: stadiumsDoc,
      places: placesDoc,
      next: next,
      canceledToday: canceledToday,
      raining: raining,
      schedule: scheduleDoc,
      now: now,
      scheduleLoading: scheduleDoc == null && scheduleAsync is AsyncLoading,
      // 재시도는 콘텐츠 4종을 함께 다시 로드 — 부분 복구로 홈이
      // raw id 저하 렌더되는 비일관성을 막는다.
      onRetrySchedule: () => invalidateContent(ref),
    );
    if (team == null) return scaffold;
    return TeamThemeScope.forTeam(teamId: team.themeKey, child: scaffold);
  }
}

/// 미리보기에 보이는 장소 개수 상한 (discretion).
const int _previewPlaceCount = 3;

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({
    required this.team,
    required this.teams,
    required this.stadiums,
    required this.places,
    required this.next,
    required this.canceledToday,
    required this.raining,
    required this.schedule,
    required this.now,
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

  /// 오늘(KST) 취소된 원정 경기 — non-null 이면 플랜B 모드 (step 4.2).
  final Game? canceledToday;

  /// 목적지 구장에 비가 오는지 (배경 연출용 — 여정과 무관).
  final bool raining;

  /// 경기 일정 — 잠실 탐색 테마 결정(당일 홈팀)에 쓴다. 못 얻었으면 null.
  final ScheduleDocument? schedule;

  /// 현재 시각 ([clockProvider] 주입) — 잠실 "당일" 판정 기준.
  final DateTime now;

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
      body: WeatherBackdrop(
        raining: raining,
        child: ListView(
          padding: const EdgeInsets.only(bottom: SpaceTokens.xxl),
          children: [..._planB(context), _face(context), ..._explore(context)],
        ),
      ),
    );
  }

  /// 플랜B 배너 (step 4.2) — 오늘 원정 경기가 취소된 날만 렌더된다.
  /// 정상(scheduled) 경기에서는 빈 목록이라 홈에 아무 변화가 없다.
  List<Widget> _planB(BuildContext context) {
    final game = canceledToday;
    if (game == null) return const [];

    final rain = game.status == GameStatus.rainCanceled;
    final city = stadiums?.byId(game.stadiumId)?.city;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          SpaceTokens.lg,
          SpaceTokens.lg,
          SpaceTokens.lg,
          SpaceTokens.sm,
        ),
        child: Container(
          padding: const EdgeInsets.all(SpaceTokens.lg),
          decoration: BoxDecoration(
            color: ColorTokens.surface,
            borderRadius: BorderRadius.circular(RadiusTokens.lg),
            border: Border.all(color: ColorTokens.warning),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    rain
                        ? Icons.umbrella_rounded
                        : Icons.event_busy_rounded,
                    color: ColorTokens.warning,
                  ),
                  const SizedBox(width: SpaceTokens.sm),
                  Expanded(
                    child: Text(
                      rain ? '오늘 경기가 우천으로 취소됐어요' : '오늘 경기가 취소됐어요',
                      style: const TextStyle(
                        fontFamily: TypeTokens.fontFamily,
                        fontSize: TypeTokens.heading,
                        fontWeight: TypeTokens.weightExtraBold,
                        color: ColorTokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpaceTokens.sm),
              Text(
                '아쉽지만 ${city ?? '근처'} 실내 놀거리로 플랜B 어때요?',
                style: const TextStyle(
                  fontFamily: TypeTokens.fontFamily,
                  fontSize: TypeTokens.body,
                  fontWeight: TypeTokens.weightMedium,
                  color: ColorTokens.textSecondary,
                ),
              ),
              const SizedBox(height: SpaceTokens.md),
              FilledButton(
                onPressed: () => _openPlanB(context, game),
                child: const Text('실내 놀거리 보러 가기'),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// 플랜B 진입 — 취소된 경기 구장의 추천 목록을 실내 필터 켠 채로 연다.
  /// 테마는 '전체 보기'와 같은 규칙(그 경기 홈팀)을 따른다.
  void _openPlanB(BuildContext context, Game game) {
    final teamsDoc = teams;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StadiumPlacesScreen(
          stadiumId: game.stadiumId,
          themeKey: teamsDoc == null ? null : themeKeyForGame(game, teamsDoc),
          initialIndoorOnly: true,
        ),
      ),
    );
  }

  /// 구장 골라 구경하기 (step 4.3) — 경기 없는 날의 두 번째 진입점.
  ///
  /// 얼굴 상태와 무관하게 홈 하단에 상시 떠서, 아무 구장이나 골라 그 구장
  /// 테마·추천 목록을 구경할 수 있다. stadiums 문서를 못 얻었으면 비노출.
  List<Widget> _explore(BuildContext context) {
    final stadiumsDoc = stadiums;
    if (stadiumsDoc == null) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          SpaceTokens.lg,
          SpaceTokens.xl,
          SpaceTokens.lg,
          0,
        ),
        child: StadiumPicker(
          stadiums: [
            for (final stadium in stadiumsDoc.stadiums)
              StadiumPickerItem(id: stadium.id, label: stadium.name),
          ],
          onSelected: (id) => _openBrowse(context, stadiumsDoc, id),
        ),
      ),
    ];
  }

  /// 탐색 진입 — 선택 구장의 추천 목록을 [browseThemeKeyForStadium] 이
  /// 정한 테마(잠실 무경기 날은 중립 = null)로 push. 뒤로 가면 내 팀 홈.
  void _openBrowse(
    BuildContext context,
    StadiumsDocument stadiumsDoc,
    String stadiumId,
  ) {
    final stadium = stadiumsDoc.byId(stadiumId);
    final teamsDoc = teams;
    final themeKey = stadium == null || teamsDoc == null
        ? null
        : browseThemeKeyForStadium(
            stadium: stadium,
            teams: teamsDoc,
            schedule: schedule,
            now: now,
          );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StadiumPlacesScreen(
          stadiumId: stadiumId,
          themeKey: themeKey,
        ),
      ),
    );
  }

  /// 기본 얼굴 — 다음 원정 상태에 따른 4갈래.
  Widget _face(BuildContext context) {
    return switch (next) {
      null => _scheduleFallback(),
      NoUpcomingAwayGame() => const DdayHeader.empty(),
      AwayGameToday(:final game) => _gameFace(context, game, dDay: 0),
      AwayGameUpcoming(:final game, :final dDay) =>
        _gameFace(context, game, dDay: dDay),
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
  Widget _gameFace(BuildContext context, Game game, {required int dDay}) {
    final stadium = stadiums?.byId(game.stadiumId);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DdayHeader(dDay: dDay, matchLabel: _matchLabel(game, stadium)),
        ..._preview(context, game, stadium),
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

  /// 다음 원정 미리보기 — 목적지 구장의 추천 장소 몇 곳 + 추천 목록 진입.
  List<Widget> _preview(BuildContext context, Game game, Stadium? stadium) {
    final previewPlaces =
        (places?.forStadium(game.stadiumId) ?? const <Place>[])
            .take(_previewPlaceCount)
            .toList();

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.lg),
        child: Row(
          children: [
            Expanded(
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
            // 추천 목록(step 3.1) 진입점 — 그 경기 홈팀 테마를 이어받는다.
            TextButton(
              onPressed: () {
                final teamsDoc = teams;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StadiumPlacesScreen(
                      stadiumId: game.stadiumId,
                      themeKey: teamsDoc == null
                          ? null
                          : themeKeyForGame(game, teamsDoc),
                    ),
                  ),
                );
              },
              child: const Text('전체 보기'),
            ),
          ],
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
              categoryLabel: categoryLabelOf(place.category),
              shoutoutSource: place.shoutout,
            ),
          ),
    ];
  }
}
