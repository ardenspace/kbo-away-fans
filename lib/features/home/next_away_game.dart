/// 다음 원정 경기 계산 (step 2.3) — 순수 로직 + "현재 시각" 주입 지점.
///
/// "원정 경기"의 기준: 선택 팀이 `awayTeamId` 인 경기. 구장 테마는 그
/// 경기의 `homeTeamId` 팀 테마를 따른다 (잠실처럼 홈팀이 2팀인 구장에서
/// 테마를 고르는 근거). 날짜 판정은 계약(schedule.json)의 date 가 KST
/// 이므로 KST(UTC+9, DST 없음) 달력 날짜 기준이다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/models.dart';

/// "현재 시각" 주입 지점 — 테스트는 고정 시각 함수로 override 한다.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// [moment] 의 KST(UTC+9 고정) 달력 날짜. 시각 성분은 0 (UTC 자정 표현).
DateTime kstDateOf(DateTime moment) {
  final kst = moment.toUtc().add(const Duration(hours: 9));
  return DateTime.utc(kst.year, kst.month, kst.day);
}

/// 경기의 KST 날짜(YYYY-MM-DD)를 [kstDateOf] 와 같은 표현(UTC 자정)으로.
DateTime gameDateOf(Game game) => DateTime.parse('${game.date}T00:00:00Z');

/// 선택 팀의 다음 원정 경기 상태 — 홈 기본 얼굴의 세 상태와 1:1.
sealed class NextAwayGame {
  const NextAwayGame();
}

/// 오늘(KST) 원정 경기가 있다.
final class AwayGameToday extends NextAwayGame {
  const AwayGameToday(this.game);

  final Game game;
}

/// 다음 원정 경기가 미래에 있다.
final class AwayGameUpcoming extends NextAwayGame {
  const AwayGameUpcoming(this.game, this.dDay);

  final Game game;

  /// 오늘(KST)부터 경기 날짜까지 남은 일수 (>= 1).
  final int dDay;
}

/// 남은 원정 일정이 없다 (시즌 종료) — 명시적 빈 상태의 근거.
final class NoUpcomingAwayGame extends NextAwayGame {
  const NoUpcomingAwayGame();
}

/// [teamId] 팀의 다음 원정 경기를 [schedule] 에서 찾는다.
///
/// - 대상: `awayTeamId == teamId` 이고 status 가 scheduled 인 경기만.
///   (취소·우천취소 경기는 "갈 경기"가 아니므로 건너뛴다.)
/// - 오늘(KST) 경기는 시작 시각이 지났어도 그날 자정까지 "오늘"로 본다.
/// - 같은 날짜가 여럿이면 시작 시각이 빠른 경기를 고른다.
NextAwayGame findNextAwayGame({
  required ScheduleDocument schedule,
  required String teamId,
  required DateTime now,
}) {
  final today = kstDateOf(now);
  Game? next;
  for (final game in schedule.games) {
    if (game.awayTeamId != teamId) continue;
    if (game.status != GameStatus.scheduled) continue;
    if (gameDateOf(game).isBefore(today)) continue;
    if (next == null || _byDateThenStart(game, next) < 0) next = game;
  }
  if (next == null) return const NoUpcomingAwayGame();

  final dDay = gameDateOf(next).difference(today).inDays;
  return dDay <= 0 ? AwayGameToday(next) : AwayGameUpcoming(next, dDay);
}

/// 오늘(KST) 취소된(canceled/우천취소) [teamId] 팀의 원정 경기 — 없으면 null.
///
/// non-null 이면 홈은 플랜B 모드(실내 놀거리 유도, step 4.2)로 분기한다.
/// scheduled 경기는 대상이 아니고, 같은 날 여러 건이면 시작 시각이 빠른
/// 경기를 고른다. [findNextAwayGame] 은 취소 경기를 건너뛰므로 두 계산은
/// 서로 독립이다 — 기존 sealed [NextAwayGame] 사용처는 그대로 동작한다.
Game? findTodayCanceledAwayGame({
  required ScheduleDocument schedule,
  required String teamId,
  required DateTime now,
}) {
  final today = kstDateOf(now);
  Game? canceled;
  for (final game in schedule.games) {
    if (game.awayTeamId != teamId) continue;
    if (game.status == GameStatus.scheduled) continue;
    if (gameDateOf(game) != today) continue;
    if (canceled == null || _byDateThenStart(game, canceled) < 0) {
      canceled = game;
    }
  }
  return canceled;
}

int _byDateThenStart(Game a, Game b) {
  // date(YYYY-MM-DD)·startTime(HH:MM)은 고정 폭이라 문자열 비교가 시간순.
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  return a.startTime.compareTo(b.startTime);
}

/// 경기의 구장 테마 키 — **홈팀** 기준 ([Team.themeKey] 경유).
///
/// 모델 파싱이 teamId enum 멤버십과 팀 10개 전원을 보장하므로
/// 조회는 항상 성공한다.
String themeKeyForGame(Game game, TeamsDocument teams) {
  final home = teams.byId(game.homeTeamId);
  assert(home != null, '알 수 없는 homeTeamId: ${game.homeTeamId}');
  return home!.themeKey;
}
