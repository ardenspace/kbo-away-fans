/// 살아 있는 산출물(`content-pipeline/data/*.json`)을 그대로 읽는 시험이
/// **그 안의 특정 경기에 매이지 않도록**, 시험이 설 자리를 실행 시점에
/// 문서에서 고르는 곳.
///
/// ## 왜 이 파일이 있는가
///
/// `content-pipeline/data/schedule.json` 은 GitHub Actions 의 KBO 일정 크롤이
/// **경기 시간대에 20분마다** 다시 쓰는 살아 있는 산출물이다. 크롤 창은 앞뒤로
/// 움직이고(2026-09-05 의 갱신은 창의 시작을 8/18 에서 8/23 으로 밀었다),
/// 경기 상태는 시간이 지나면 `scheduled` 에서 `finished` 로 바뀌며, 우천취소가
/// 생겼다 사라진다. 그래서 그 문서에서 고른 **특정 경기의 id 나 날짜 문자열을
/// 시험에 박아 두면 아무도 코드를 건드리지 않아도 저장소가 스스로 빨간불이
/// 된다.** 실제로 그 갱신 하나가 시험 셋을 빨간불로 만들었다(cycle2 탐침의
/// `8/27`, round5 R2·R5 의 `8/29 (토)`). 경기 시간대에는 그 위험이 20분마다
/// 돌아온다.
///
/// ## 이 파일이 하는 것과 하지 않는 것
///
/// 여기 있는 것은 **고르는 규칙**뿐이다 — "어느 경기를 두고 잴 것인가"와
/// "그 경기의 어느 시각에 시계를 둘 것인가". 화면이 무엇을 말해야 하는지는
/// 정하지 않는다.
///
/// 기대 문구를 짓는 자리([AwayGameAnchor.dayLabel]·[AwayGameAnchor.matchLabel]
/// 등)는 앱의 표기를 **일부러 다시 적어 둔 것**이다. `lib/` 의 구현을 불러다
/// 쓰면 표기가 바뀌어도 시험이 초록불이라 못이 되지 못한다 — 표기가 바뀌면
/// 그 시험들이 빨간불이어야 한다.
///
/// 고를 것이 없으면 **조용히 지나가지 않고 던진다** — "이 산출물에는 이런
/// 경기가 없다"는 것 자체가 다음 사람이 알아야 하는 사실이다.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/location/visit_check.dart'
    show
        kStadiumVisitRadiusMeters,
        kVisitWindowAfterStart,
        kVisitWindowBeforeStart;

/// 5.1 의 acceptance "최근 5경기" — 홈 중단에 실제로 서는 줄의 수.
///
/// 앵커가 그 안에 드는지를 여기서 재므로 `lib/` 의 `kRecentGamesLimit` 을
/// 불러오지 않고 다시 적는다(위 라이브러리 문단의 "일부러 다시 적어 둔 것"과
/// 같은 까닭).
const int _recentRows = 5;

/// 어느 구장에서도 반경 밖인 지점 — 서울 시청.
///
/// "구장을 떠나 집에 왔다"를 흉내 내는 자리들이 함께 쓴다. 실제로 아홉 구장
/// 전부에서 멀리 떨어져 있는지는 [pickAwayGameAnchor] 가 고른 구장에 대해
/// 실행 시점에 확인한다.
const double kOffStadiumLat = 37.5665;

/// [kOffStadiumLat] 의 짝.
const double kOffStadiumLng = 126.9780;

/// 콘텐츠 4종의 실 산출물 — 파싱까지 마친 문서들.
class LiveContent {
  const LiveContent({
    required this.teams,
    required this.stadiums,
    required this.places,
    required this.schedule,
  });

  final TeamsDocument teams;
  final StadiumsDocument stadiums;
  final PlacesDocument places;
  final ScheduleDocument schedule;
}

/// `content-pipeline/data/` 의 JSON 하나를 그대로 읽는다.
Map<String, Object?> readLiveJson(String fileName) =>
    jsonDecode(File('content-pipeline/data/$fileName').readAsStringSync())
        as Map<String, Object?>;

/// 콘텐츠 4종을 **실 산출물 그대로** 읽어 판다.
///
/// 파이프라인의 계약과 앱의 파서가 어긋나면 여기서 던진다.
LiveContent readLiveContent() => LiveContent(
  teams: TeamsDocument.fromJson(readLiveJson('teams.json')),
  stadiums: StadiumsDocument.fromJson(readLiveJson('stadiums.json')),
  places: PlacesDocument.fromJson(readLiveJson('places.json')),
  schedule: ScheduleDocument.fromJson(readLiveJson('schedule.json')),
);

/// 추천 목록이 실제로 서는 구장 — `places.json` 이 장소를 아는 곳.
///
/// 장소 문서는 큐레이션이라 크롤이 건드리지 않지만, 어느 구장을 아는지는
/// 시험이 정할 일이 아니므로 문서에서 고른다.
Stadium stadiumWithPlaces(LiveContent content) {
  for (final stadium in content.stadiums.stadiums) {
    if (content.places.forStadium(stadium.id).isNotEmpty) return stadium;
  }
  throw StateError('places.json 이 장소를 아는 구장이 하나도 없다');
}

/// 시험이 두고 재는 원정 경기 하나와, 그 경기에 매인 값들.
///
/// 여기서 나오는 문구·id 는 전부 [game] 과 [stadium] 에서 도출된다 —
/// 산출물이 움직여도 [pickAwayGameAnchor] 가 다른 경기를 고를 뿐이다.
class AwayGameAnchor {
  const AwayGameAnchor({
    required this.teamId,
    required this.game,
    required this.stadium,
  });

  /// 이 경기를 **원정으로** 뛰는 팀 — 시험이 응원 팀으로 고르는 팀이다.
  final String teamId;

  final Game game;

  /// [game] 이 열리는 구장 — 좌표와 이름의 출처.
  final Stadium stadium;

  /// 경기가 시작하는 절대 시각.
  DateTime get startsAt =>
      DateTime.parse('${game.date}T${game.startTime}:00+09:00');

  /// 시작으로부터 [afterStart] 만큼 지난 시각.
  DateTime at(Duration afterStart) => startsAt.add(afterStart);

  /// 경기 도중 — 구장에 서 있는 사람의 시각(시간 창 안, 도장이 나온다).
  DateTime get atGame => at(const Duration(hours: 1));

  /// 시간 창이 **닫힌 뒤**의 시각. 그날(KST) 안이라 판정 후보는 여전히 있다 —
  /// 4.2 의 게이트가 열려 판정이 다시 도는 구간을 재는 자리다.
  DateTime get afterWindow =>
      at(kVisitWindowAfterStart + const Duration(minutes: 15));

  /// 이 화면의 날짜 표기 — `8/29 (토)`.
  String get dayLabel => _dayLabelOf(game.date);

  /// D-day 얼굴의 경기 정보 한 줄 — `8/29 (토) 사직야구장 · 18:00`.
  String get matchLabel => '$dayLabel ${stadium.name} · ${game.startTime}';

  /// 최근 5경기 요약이 이 경기에 적는 점수 — **내 팀이 앞**이다.
  String get scoreLabel => '${game.awayScore} : ${game.homeScore}';

  /// 홈 상단 위치 자리가 이 구장을 특정할 때의 문구.
  String get nearbyLabel => '${stadium.name} 근처예요';

  /// 이 경기의 도장이 들어가는 배지 판의 칸 id — `{stadiumId}_{homeTeamId}`.
  String get boardCellId => '${game.stadiumId}_${game.homeTeamId}';

  /// 이 경기의 도장 문서 id — `{stadiumId}_{gameId}`.
  String get stampDocumentId => '${game.stadiumId}_${game.id}';
}

/// 시험이 두고 잴 원정 경기 하나를 **실 일정에서** 고른다.
///
/// 고르는 조건(전부 만족해야 한다):
///
///  1. `awayTeamId == teamId` 이고 이미 끝난(`finished`) 경기 — 점수·승패가
///     있어야 최근 5경기 요약이 그 경기를 값으로 말한다.
///  2. 구장 문서가 좌표를 아는 구장 — 반경 판정에 넣을 수 있어야 한다.
///  3. 그날 그 구장에 **다른 경기가 없다** — 도장과 "그 구장 근처예요"가
///     어느 경기의 것인지 갈리지 않게.
///  4. 그날 그 팀의 **다른 원정 경기가 없다**(취소는 셈에서 뺀다) —
///     `findNextAwayGame` 이 고를 경기가 이 경기 하나여야 D-day 얼굴이
///     가리키는 것이 이 경기다.
///  5. 시간 창이 닫히는 시각([AwayGameAnchor.afterWindow])이 아직 **그날
///     (KST) 안** — 그 시각에도 판정 후보가 남아 있어야 "창이 닫히면 판정이
///     다시 돈다"를 잴 수 있다.
///  6. 그 팀의 최근 종료 경기 [_recentRows] 개 안에 들고, 그 안에서 날짜
///     표기와 점수 표기가 **겹치지 않는다** — 한 화면이 같은 경기를 두 번
///     말하는지를 `findsOneWidget` 으로 잴 수 있어야 한다.
///
/// 팀은 [preferredTeamId] 부터 보고, 그 팀에 맞는 경기가 없으면 **다른 팀으로
/// 넘어간다**. 어느 팀을 응원하는지는 이 탐침들이 재는 성질이 아니고, 한 팀만
/// 고집하면 그 팀이 마침 홈 다섯 경기를 연달아 치른 창에서 시험이 통째로
/// 빨간불이 된다 — 그것은 코드의 결함이 아니라 일정의 모양이다. 고른 팀은
/// [AwayGameAnchor.teamId] 로 나가므로 부르는 쪽은 그 값을 쓰면 된다.
///
/// 여럿이면 가장 최근 경기. 열 팀 어디에도 없으면 [StateError] — 산출물이
/// 그런 모양이라는 사실이 조용히 묻히지 않게 한다.
AwayGameAnchor pickAwayGameAnchor({
  required LiveContent content,
  String? preferredTeamId,
}) {
  final order = [
    ?preferredTeamId,
    for (final team in content.teams.teams)
      if (team.id != preferredTeamId) team.id,
  ];
  for (final teamId in order) {
    final anchor = _anchorFor(content, teamId);
    if (anchor != null) return anchor;
  }

  final schedule = content.schedule;
  throw StateError(
    '시험이 둘 자리를 실 일정에서 찾지 못했다 — 어느 팀에도 "끝난 원정 '
    '경기이면서, 그날 그 구장·그 팀의 유일한 경기이고, 최근 $_recentRows '
    '경기 안에서 날짜·점수 표기가 겹치지 않는" 경기가 없다 '
    '(문서 생성 ${schedule.generatedAt.toIso8601String()}, '
    '경기 ${schedule.games.length}건)',
  );
}

/// [teamId] 하나를 두고 위 조건을 재 본다 — 맞는 경기가 없으면 null.
AwayGameAnchor? _anchorFor(LiveContent content, String teamId) {
  final schedule = content.schedule;
  final recent = _recentFinishedGames(schedule, teamId);

  for (final game in recent) {
    if (game.awayTeamId != teamId) continue;
    final stadium = content.stadiums.byId(game.stadiumId);
    if (stadium == null) continue;

    final sameStadiumThatDay = schedule.games.where(
      (g) =>
          g.date == game.date &&
          g.stadiumId == game.stadiumId &&
          g.status != GameStatus.canceled &&
          g.status != GameStatus.rainCanceled,
    );
    if (sameStadiumThatDay.length != 1) continue;

    final awayThatDay = schedule.games.where(
      (g) =>
          g.date == game.date &&
          g.awayTeamId == teamId &&
          g.status != GameStatus.canceled &&
          g.status != GameStatus.rainCanceled,
    );
    if (awayThatDay.length != 1) continue;

    final anchor = AwayGameAnchor(teamId: teamId, game: game, stadium: stadium);
    if (_kstDay(anchor.afterWindow) != game.date) continue;

    final labels = [for (final g in recent) _dayLabelOf(g.date)];
    final scores = [for (final g in recent) _scoreLabelOf(g, teamId)];
    if (labels.where((l) => l == anchor.dayLabel).length != 1) continue;
    if (scores.where((s) => s == anchor.scoreLabel).length != 1) continue;

    // "집에 왔다"를 흉내 내는 지점이 이 구장 반경 안이면 그 시나리오가
    // 무너진다 — 고르는 자리에서 함께 확인한다.
    if (_metersBetween(
          kOffStadiumLat,
          kOffStadiumLng,
          stadium.lat,
          stadium.lng,
        ) <
        kStadiumVisitRadiusMeters * 10) {
      continue;
    }

    return anchor;
  }
  return null;
}

/// 리그 전체에 경기가 없고 **어느 경기의 시간 창도 덮지 않는** 시각.
///
/// `judgeStadiumVisit` 이 권한을 묻기도 전에 `noGameToday` 로 끝나는 갈래를
/// 재는 자리다. 문서가 아는 날짜 창 안에서 그런 날의 KST 오전 10시를 고른다.
DateTime pickNoGameMoment(ScheduleDocument schedule) {
  final dates = schedule.games.map((g) => g.date).toSet().toList()..sort();
  if (dates.isEmpty) throw StateError('일정 문서에 경기가 하나도 없다');

  var day = DateTime.parse('${dates.first}T00:00:00Z');
  final last = DateTime.parse('${dates.last}T00:00:00Z');
  while (!day.isAfter(last)) {
    final date = _kstDay(day);
    if (!dates.contains(date)) {
      final moment = DateTime.parse('${date}T10:00:00+09:00');
      final covered = schedule.games.any((g) {
        final starts = DateTime.parse('${g.date}T${g.startTime}:00+09:00');
        return !moment.isBefore(starts.subtract(kVisitWindowBeforeStart)) &&
            !moment.isAfter(starts.add(kVisitWindowAfterStart));
      });
      if (!covered) return moment;
    }
    day = day.add(const Duration(days: 1));
  }

  throw StateError('이 일정 문서(${dates.first}~${dates.last})에는 리그 전체가 쉬는 날이 없다');
}

/// [teamId] 가 낀 종료 경기를 최신순으로 최대 [_recentRows] 개.
///
/// 5.1 의 규칙을 시험 쪽에서 다시 적은 것이다 — 홈 중단에 실제로 서는 줄이
/// 무엇인지 알아야 앵커를 고를 수 있고, `lib/` 의 계산을 불러다 쓰면 그
/// 계산이 틀려도 앵커가 함께 틀려 시험이 초록불이 된다.
List<Game> _recentFinishedGames(ScheduleDocument schedule, String teamId) {
  final finished =
      schedule.games
          .where(
            (g) =>
                g.status == GameStatus.finished &&
                (g.homeTeamId == teamId || g.awayTeamId == teamId),
          )
          .toList()
        ..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          return byDate != 0 ? byDate : b.startTime.compareTo(a.startTime);
        });
  return finished.take(_recentRows).toList();
}

/// 날짜 표기 한 자리 — `8/29 (토)`. 앱의 표기를 시험 쪽에서 다시 적은 것이다.
String _dayLabelOf(String date) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  final parsed = DateTime.parse('${date}T00:00:00Z');
  return '${parsed.month}/${parsed.day} (${labels[parsed.weekday - 1]})';
}

String _scoreLabelOf(Game game, String teamId) {
  final mine = game.homeTeamId == teamId ? game.homeScore : game.awayScore;
  final theirs = game.homeTeamId == teamId ? game.awayScore : game.homeScore;
  return '$mine : $theirs';
}

/// [moment] 의 KST 달력 날짜(YYYY-MM-DD).
String _kstDay(DateTime moment) {
  final kst = moment.toUtc().add(const Duration(hours: 9));
  final month = kst.month.toString().padLeft(2, '0');
  final day = kst.day.toString().padLeft(2, '0');
  return '${kst.year}-$month-$day';
}

/// 두 점 사이의 대략적인 거리(m) — 반경 밖인지만 가르면 되므로 등거리
/// 근사로 충분하다.
double _metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const metersPerDegree = 111320.0;
  final dLat = (lat1 - lat2) * metersPerDegree;
  final dLng = (lng1 - lng2) * metersPerDegree * 0.8;
  return math.sqrt(dLat * dLat + dLng * dLng);
}
