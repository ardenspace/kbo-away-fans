import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import '../../location/location.dart'
    show LocationPermissionStatus, locationPermissionStatusProvider;
import '../../location/visit_check.dart' show StadiumVisitResult;
import '../../ui/shared/category_labels.dart';
import '../../ui/shared/dday_header.dart';
import '../../ui/shared/empty_state_notice.dart';
import '../../ui/shared/place_card.dart';
import '../../ui/shared/stadium_picker.dart';
import '../../ui/shared/team_theme_scope.dart';
import '../../ui/shared/weather_backdrop.dart';
import '../../weather/weather.dart';
import '../badges/stadium_visit.dart'
    show stadiumVisitProvider, stadiumVisitRunProvider;
import '../places/stadium_places_screen.dart';
import '../team_select/team_select_screen.dart';
import 'current_location.dart';
import 'next_away_game.dart';
import 'recent_games.dart';
import 'stadium_browse.dart';

/// 홈 화면 (step 2.3) — 다음 원정 경기 D-day 기본 얼굴.
///
/// - 앱 골격(앱바 등)은 앱 루트 [AppVisualTheme] 역할색으로 렌더.
/// - D-day 헤더·원정 미리보기의 경기 보조 요소에는 **그 경기 홈팀** 색을
///   [TeamThemeScope]로 공급한다 — 잠실처럼 홈팀이 2팀인 구장의 맥락 근거.
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
    final destinationGame =
        canceledToday ??
        switch (next) {
          AwayGameToday(:final game) || AwayGameUpcoming(:final game) => game,
          _ => null,
        };
    final destination = destinationGame == null
        ? null
        : stadiumsDoc?.byId(destinationGame.stadiumId);
    final raining =
        destination != null &&
        weatherEffectOf(
              ref.watch(
                weatherEffectProvider((
                  lat: destination.lat,
                  lng: destination.lng,
                )),
              ),
            ) ==
            WeatherEffect.rain;

    // 홈 상단 현재 위치 (step 5.2) — 기본은 새 권한 조회를 만들지 않고 4.1 이
    // 앱을 열 때·포그라운드로 돌아올 때 이미 돌리고 있는 판정 결과만 읽는다
    // (`current_location.dart` docstring 참조 — 독립된 조회를 매 빌드마다
    // 뒀다가 위치 게이트웨이를 override 하지 않는 부팅 시험들이 무더기로
    // 깨진 실측이 있다).
    final stadiumVisit = ref.watch(stadiumVisitProvider);

    // 4.2 는 새 도장이 나올 수 없는 구간에서 측위를 건너뛰므로, 판정 결과값
    // 만으로는 그것이 지금의 답인지 알 수 없다(`stadiumVisitRunProvider`
    // 문서 참조). 그 기록이 두 물음에 따로 답한다.
    final lastVisitRun = ref.watch(stadiumVisitRunProvider);
    final judgmentAttempted = lastVisitRun != null;
    // (1) **이** 실행이 판정까지 갔는가 — 아니면 판정 안의 "권한이 있었다"도
    // 옛 사실이라, 자리를 그릴지를 권한을 다시 물어 정한다(round 3 의
    // REJECT 사유. 그 값을 그대로 믿으면 권한을 끄고 돌아온 사람의 홈 상단이
    // 다섯 시간까지 그대로 선다).
    final lastRunJudged = lastVisitRun != null && lastVisitRun.judged;
    // (2) 손에 든 판정이 **언제** 난 것인가 — 구장 이름을 쓸지를 정하는 나이의
    // 기준점이고, 건너뛴 실행을 지나도 그대로 이어진다.
    final judgedAt = lastVisitRun?.judgedAt;

    // 판정이 권한을 대신 말해 주지 못하는 갈래에서만 권한을 다시 묻는다
    // (`noGameToday`, 콘텐츠를 못 얻어 판정이 아예 없는 실행, 그리고 마지막
    // 시도가 판정까지 가지 못한 실행). 다른 갈래에서는 이 provider 를
    // 구독조차 하지 않는다 — `autoDispose` 라 그동안 인스턴스화되지 않는다
    // (`current_location.dart` docstring 참조). 그 조회는 다이얼로그가 없는
    // `status()` 하나이고, 새로 답이 나는 것은 `StadiumVisitTrigger` 가 그
    // provider 를 버리는 **포그라운드 복귀당 한 번**이다.
    final LocationPermissionStatus? askedPermission =
        currentLocationNeedsPermissionAnswer(
          stadiumVisit,
          judgmentAttempted: judgmentAttempted,
          lastRunJudged: lastRunJudged,
        )
        ? ref.watch(locationPermissionStatusProvider).value
        : null;

    final team = teamsDoc?.byId(teamId);
    final scaffold = _HomeScaffold(
      teamId: teamId,
      team: team,
      teams: teamsDoc,
      stadiums: stadiumsDoc,
      places: placesDoc,
      next: next,
      canceledToday: canceledToday,
      raining: raining,
      schedule: scheduleDoc,
      now: now,
      stadiumVisit: stadiumVisit,
      judgmentAttempted: judgmentAttempted,
      lastRunJudged: lastRunJudged,
      visitJudgedAt: judgedAt,
      askedPermission: askedPermission,
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

/// 요일 표기 — 이 화면에서 날짜를 쓰는 자리가 둘이라 배열도 한 자리에 둔다.
const List<String> _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

/// 이 화면의 날짜 표기 한 자리 — `8/20 (목)`.
///
/// 한 화면에 표기가 둘로 갈려 있었다: D-day 얼굴([_HomeScaffold._matchLabel])은
/// `8/20 (목)`, 최근 5경기 요약([_RecentGameRow])은 `8/20(목)` 이었고 요일
/// 배열도 두 곳에 따로 선언되어 있었다(phase 5 통합 검증의 계약 밖 발견).
/// 어느 표기로 모을지는 5.1 의 discretion 이라, 이미 저장소에 선례가 있는
/// 쪽(D-day 얼굴 · `lib/ui/shared/dday_header.dart` 문서의 예시 문구)으로
/// 모은다.
String _dayLabel(DateTime date) =>
    '${date.month}/${date.day} (${_weekdayLabels[date.weekday - 1]})';

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({
    required this.teamId,
    required this.team,
    required this.teams,
    required this.stadiums,
    required this.places,
    required this.next,
    required this.canceledToday,
    required this.raining,
    required this.schedule,
    required this.now,
    required this.stadiumVisit,
    required this.judgmentAttempted,
    required this.lastRunJudged,
    required this.visitJudgedAt,
    required this.askedPermission,
    required this.scheduleLoading,
    required this.onRetrySchedule,
  });

  /// 선택된 응원 팀 id — teams 문서를 못 얻어 [team] 이 null 이어도
  /// 최근 5경기 요약(step 5.1)은 schedule 문서만으로 계산할 수 있다.
  final String teamId;

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

  /// 가장 최근 방문 판정 (step 4.1 이 이미 돌리는 [stadiumVisitProvider]) —
  /// 홈 상단 위치 자리를 그릴지·"어느 구장 근처인지"를 아는 유일한 자리다.
  final StadiumVisitResult? stadiumVisit;

  /// 판정 트리거가 이 실행에서 한 번이라도 돌았는가
  /// ([stadiumVisitRunProvider] 에 기록이 있는가) — [stadiumVisit] 이 null 일
  /// 때 "아직 안 돌았다"와 "돌았지만 콘텐츠를 못 얻어 판정하지 못했다"를
  /// 가르는 값이다.
  final bool judgmentAttempted;

  /// 마지막 판정 시도가 **판정까지 갔는가** (`stadiumVisitRunProvider` 의
  /// `judged`) — 거짓이면 [stadiumVisit] 은 그 **이전** 실행의 답이라,
  /// 그 안의 "권한이 있었다"도 옛 사실이다. 그 갈래에서 자리를 그릴지는
  /// [askedPermission] 이 정한다([currentLocationVisible] 문서 참조).
  final bool lastRunJudged;

  /// [stadiumVisit] 이 **난 시각** — 한 번도 판정된 적이 없으면 null.
  ///
  /// 건너뛴 실행([lastRunJudged] 이 거짓)을 지나도 이 값은 그대로다 — 그
  /// 실행은 판정을 낡게 만들지 않는다. 나이가 실제로 자라는 것은 시각이
  /// 흐르는 것뿐이고, 그 나이를 재는 자리가 [CurrentLocationRow] 다.
  final DateTime? visitJudgedAt;

  /// 판정이 권한을 대신 말해 주지 못하는 갈래에서 [HomeScreen] 이 한 번 더
  /// 물은 권한 상태 (`current_location.dart` docstring 참조). 그 밖의
  /// 갈래에서는 항상 null 이고 [currentLocationVisible] 도 그 값을 쓰지 않는다.
  final LocationPermissionStatus? askedPermission;

  /// schedule 이 아직 로드 중인지 (null 인 이유의 구분).
  final bool scheduleLoading;
  final VoidCallback onRetrySchedule;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<AppVisualTheme>();
    final barBg = visual?.background ?? ColorTokens.background;
    final barFg = visual?.textPrimary ?? ColorTokens.textPrimary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barBg,
        foregroundColor: barFg,
        title: Text(
          'KBO 원정러',
          style: TextTokens.appBarTitle.copyWith(color: barFg),
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
          children: [
            ..._currentLocation(context),
            ..._planB(context),
            _face(context),
            ..._recentGames(context),
            ..._explore(context),
          ],
        ),
      ),
    );
  }

  /// 홈 상단 현재 위치 (step 5.2) — 위치 권한이 있으면(4.1 이 그것을 실제로
  /// 확인한 판정이 있거나, [askedPermission] 이 대신 답했으면) 구장 근접
  /// 표시를, 아니면 자리를 그대로 접는다. 그 재조회 하나를 뺀 새 권한 조회는
  /// 만들지 않는다 — `current_location.dart` docstring 참조.
  ///
  /// **구장 이름은 판정이 아직 [kCurrentLocationFreshness] 안일 때만 쓴다.**
  /// 4.2 의 재판정 게이트가 닫혀 있는 동안에는 사람이 구장을 떠나도 판정이
  /// 갱신되지 않아서, 그 값을 그대로 "현재 위치"로 세우면 홈 상단이 이미 떠난
  /// 구장을 몇 시간 동안 가리킨다(phase 5 통합 검증의 REJECT 사유).
  /// **그 나이를 재는 것은 이 화면이 아니라 [CurrentLocationRow] 다** — 나이는
  /// 아무도 아무 일을 하지 않아도 자라는데 이 `build` 는 시간이 흐르는 것만으로
  /// 다시 돌지 않기 때문이다(그 위젯 문서 참조. round 2 의 REJECT 사유다).
  ///
  /// **재요청 버튼을 두지 않는다.** acceptance 가 허용한 두 갈래("자리가
  /// 사라지거나 권한 안내로 바뀌고") 중 앞엣것을 고른다 — 권한을 다시
  /// 묻는 진입점은 이미 배지 탭(`VisitStatusNotice`)에 있고, 여기 또 두면
  /// 같은 결정을 두 화면에서 각자 묻게 된다.
  ///
  /// **좌표는 이 메서드에 값으로 온 적이 없다** — [stadiumVisit] 은 4.1 이
  /// 이미 돌리고 있는 판정 결과([StadiumVisitResult])이고, [noGameTodayPermission]
  /// 은 권한 상태([LocationPermissionStatus])뿐이다. 둘 다 좌표 필드가
  /// 없다(`lib/location/visit_check.dart` 겹 5·`lib/location/location.dart`).
  List<Widget> _currentLocation(BuildContext context) {
    if (!currentLocationVisible(
      stadiumVisit,
      judgmentAttempted: judgmentAttempted,
      lastRunJudged: lastRunJudged,
      askedPermission: askedPermission,
    )) {
      return const [];
    }
    return [
      CurrentLocationRow(
        // 이 자리가 홈 목록의 **맨 위**라는 것을 시험이 자리 자체로 잴 수
        // 있게 하는 표지다 (5.2 acceptance 의 "상단"). 그 전에는 이 조각을
        // 목록 맨 아래로 옮겨도 저장소 전체가 초록불이었다.
        key: kCurrentLocationRowKey,
        visit: stadiumVisit,
        stadiums: stadiums,
        judgedAt: visitJudgedAt,
      ),
    ];
  }

  /// 플랜B 배너 (step 4.2) — 오늘 원정 경기가 취소된 날만 렌더된다.
  /// 정상(scheduled) 경기에서는 빈 목록이라 홈에 아무 변화가 없다.
  List<Widget> _planB(BuildContext context) {
    final game = canceledToday;
    if (game == null) return const [];

    final rain = game.status == GameStatus.rainCanceled;
    final city = stadiums?.byId(game.stadiumId)?.city;
    final material = Theme.of(context);
    final visual = material.extension<AppVisualTheme>();
    final warning = visual?.warning ?? ColorTokens.warning;
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
            color: visual?.surface ?? material.colorScheme.surface,
            borderRadius: BorderRadius.circular(RadiusTokens.lg),
            border: Border.all(color: warning),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    rain ? Icons.umbrella_rounded : Icons.event_busy_rounded,
                    color: warning,
                  ),
                  const SizedBox(width: SpaceTokens.sm),
                  Expanded(
                    child: Text(
                      rain ? '오늘 경기가 우천으로 취소됐어요' : '오늘 경기가 취소됐어요',
                      style: TextTokens.onSurface(context, TextTokens.heading),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpaceTokens.sm),
              Text(
                '아쉽지만 ${city ?? '근처'} 실내 놀거리로 플랜B 어때요?',
                style: TextTokens.onSurfaceMuted(context, TextTokens.bodyMuted),
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

  /// 최근 5경기 결과 요약 (step 5.1) — 홈 중단, D-day 얼굴과 탐색 진입점
  /// 사이. 내 팀이 홈이든 원정이든 상관없이 종료 경기를 최신순으로 최대
  /// [kRecentGamesLimit] 개 보여준다. schedule 문서를 못 얻었으면(로딩·실패)
  /// 자리 자체를 접는다 — 그 상태는 이미 [_scheduleFallback] 이 안내한다.
  List<Widget> _recentGames(BuildContext context) {
    final scheduleDoc = schedule;
    if (scheduleDoc == null) return const [];

    final games = recentGamesFor(schedule: scheduleDoc, teamId: teamId);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          SpaceTokens.lg,
          SpaceTokens.xl,
          SpaceTokens.lg,
          SpaceTokens.sm,
        ),
        child: Text(
          '최근 5경기',
          style: TextTokens.onSurface(context, TextTokens.sectionTitle),
        ),
      ),
      if (games.isEmpty)
        const EmptyStateNotice(
          title: '아직 경기 결과가 없어요',
          message: '경기가 끝나면 이 자리에 최근 결과가 쌓여요.',
        )
      else
        for (final game in games)
          Padding(
            padding: const EdgeInsets.only(
              left: SpaceTokens.lg,
              right: SpaceTokens.lg,
              bottom: SpaceTokens.sm,
            ),
            child: _RecentGameRow(
              game: game,
              teamId: teamId,
              teams: teams,
              stadiums: stadiums,
            ),
          ),
    ];
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
        builder: (_) =>
            StadiumPlacesScreen(stadiumId: stadiumId, themeKey: themeKey),
      ),
    );
  }

  /// 기본 얼굴 — 다음 원정 상태에 따른 4갈래.
  Widget _face(BuildContext context) {
    return switch (next) {
      null => _scheduleFallback(context),
      NoUpcomingAwayGame() => const DdayHeader.empty(),
      AwayGameToday(:final game) => _gameFace(context, game, dDay: 0),
      AwayGameUpcoming(:final game, :final dDay) => _gameFace(
        context,
        game,
        dDay: dDay,
      ),
    };
  }

  /// schedule 문서를 못 얻은 상태 — 로드 중이거나 실패 + 재시도.
  Widget _scheduleFallback(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: scheduleLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '경기 일정을 불러오지 못했어요',
                  style: TextTokens.onSurface(context, TextTokens.title),
                ),
                const SizedBox(height: SpaceTokens.sm),
                Text(
                  '네트워크를 확인하고 다시 시도해 주세요.',
                  style: TextTokens.onSurfaceMuted(
                    context,
                    TextTokens.bodyMuted,
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
        DdayHeader(
          dDay: dDay,
          matchLabel: _matchLabel(game, stadium),
          opponentShortName: _opponentShortName(game),
        ),
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

  /// 경기 정보 한 줄 (예: '8/30 (토) 사직야구장 · 18:30').
  ///
  /// 상대팀은 이 문구에 넣지 않는다. [DdayHeader] 가 [_opponentShortName] 을
  /// 받아 팀 색이 들어간 배지로 따로 보여 주기 때문이다.
  String _matchLabel(Game game, Stadium? stadium) {
    final where = stadium?.name ?? game.stadiumId;
    return '${_dayLabel(gameDateOf(game))} $where · ${game.startTime}';
  }

  /// 원정 경기에서 만나는 상대팀(= 그 경기 홈팀)의 약칭.
  /// 팀 목록을 아직 못 받았으면 배지를 세우지 않도록 null 을 준다.
  String? _opponentShortName(Game game) =>
      teams?.byId(game.homeTeamId)?.shortName;

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
                style: TextTokens.onSurface(context, TextTokens.sectionTitle),
              ),
            ),
            // 추천 목록 진입점 — 그 경기 홈팀을 경기·구장 보조 맥락으로 넘긴다.
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.lg),
          child: Text(
            '이 구장 주변 추천 장소를 준비하고 있어요.',
            style: TextTokens.onSurfaceMuted(context, TextTokens.bodyMuted),
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

/// 최근 5경기 요약 한 줄 (step 5.1) — 날짜·구장·상대(홈/원정)·점수·승패.
///
/// 선발 투수·날씨 자리는 만들지 않는다(이번 사이클 범위 밖 — decisions.md
/// 2026-09-01). 이 화면 한 곳에서만 렌더되는 요약 카드라 `lib/ui/shared/`
/// 로 승격하지 않았다(공통 요소 규칙: 두 군데 이상에서 쓰일 때 승격).
class _RecentGameRow extends StatelessWidget {
  const _RecentGameRow({
    required this.game,
    required this.teamId,
    required this.teams,
    required this.stadiums,
  });

  final Game game;

  /// 이 요약을 보는 기준 팀 — 홈/원정 판정과 승패 뒤집기의 기준.
  final String teamId;
  final TeamsDocument? teams;
  final StadiumsDocument? stadiums;

  @override
  Widget build(BuildContext context) {
    final material = Theme.of(context);
    final visual = material.extension<AppVisualTheme>();
    final isHome = game.homeTeamId == teamId;
    final opponentId = isHome ? game.awayTeamId : game.homeTeamId;
    final opponentName = teams?.byId(opponentId)?.shortName ?? opponentId;
    final stadiumName = stadiums?.byId(game.stadiumId)?.name ?? game.stadiumId;
    final myScore = isHome ? game.homeScore : game.awayScore;
    final opponentScore = isHome ? game.awayScore : game.homeScore;
    final outcome = outcomeFor(game, teamId);

    final dateLabel = _dayLabel(gameDateOf(game));

    return Container(
      padding: const EdgeInsets.all(SpaceTokens.md),
      decoration: BoxDecoration(
        color: visual?.surface ?? material.colorScheme.surface,
        borderRadius: BorderRadius.circular(RadiusTokens.sm),
        border: Border.all(
          color: visual?.outline ?? material.colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Text(
            dateLabel,
            style: TextTokens.onSurfaceMuted(context, TextTokens.caption),
          ),
          const SizedBox(width: SpaceTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isHome ? '홈' : '원정'} · $opponentName',
                  style: TextTokens.onSurface(context, TextTokens.bodyStrong),
                ),
                Text(
                  stadiumName,
                  style: TextTokens.onSurfaceMuted(context, TextTokens.caption),
                ),
              ],
            ),
          ),
          Text(
            '$myScore : $opponentScore',
            style: TextTokens.onSurface(context, TextTokens.bodyStrong),
          ),
          const SizedBox(width: SpaceTokens.sm),
          Text(
            outcomeLabel(outcome),
            style: TextTokens.bodyStrong.copyWith(
              color: outcome == TeamGameOutcome.draw
                  ? visual?.textSecondary ??
                        material.colorScheme.onSurfaceVariant
                  : _outcomeColor(outcome),
            ),
          ),
        ],
      ),
    );
  }

  Color _outcomeColor(TeamGameOutcome outcome) => switch (outcome) {
        TeamGameOutcome.win => ColorTokens.success,
        TeamGameOutcome.loss => ColorTokens.danger,
        TeamGameOutcome.draw => ColorTokens.textSecondary,
      };
}
