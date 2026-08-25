/// 구장 골라 구경하기(탐색 모드, step 4.3)의 테마 결정 규칙 — 순수 로직.
///
/// 단일 홈팀 구장은 그 팀 테마. 잠실처럼 homeTeams 가 2팀인 구장은
/// 당일(KST) 그 구장 경기의 홈팀 테마, 경기가 없으면 중립
/// (null = 팀 스코프 없음, 기본 토큰).
library;

import '../../content/models.dart';
import 'next_away_game.dart';

/// [stadium] 을 탐색 모드로 구경할 때 적용할 팀 테마 키 — null 이면 중립.
///
/// - 홈팀이 1팀이면 항상 그 팀 테마 (경기 유무와 무관).
/// - 홈팀이 2팀(잠실)이면 당일(KST) 그 구장 경기의 홈팀 테마.
///   당일 경기가 여럿이면 시작 시각이 빠른 경기, 취소(우천 포함) 경기도
///   "그날의 홈팀"으로 인정한다 (플랜B 테마 규칙과 일관).
/// - 당일 경기가 없거나 [schedule] 을 못 얻었으면 중립(null).
String? browseThemeKeyForStadium({
  required Stadium stadium,
  required TeamsDocument teams,
  required ScheduleDocument? schedule,
  required DateTime now,
}) {
  if (stadium.homeTeams.length == 1) {
    final team = teams.byId(stadium.homeTeams.single);
    assert(team != null, '알 수 없는 homeTeam: ${stadium.homeTeams.single}');
    return team!.themeKey;
  }

  if (schedule == null) return null;
  final today = kstDateOf(now);
  Game? todayGame;
  for (final game in schedule.games) {
    if (game.stadiumId != stadium.id) continue;
    if (gameDateOf(game) != today) continue;
    if (todayGame == null ||
        game.startTime.compareTo(todayGame.startTime) < 0) {
      todayGame = game;
    }
  }
  if (todayGame == null) return null;
  return themeKeyForGame(todayGame, teams);
}
