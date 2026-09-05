/// 홈 최근 5경기 결과 요약 (step 5.1) — 1.2 가 크롤 창을 넓혀 산출한 과거
/// 경기를 내 팀 기준으로 추려 순수 로직만 이 파일에 둔다 (렌더는
/// `home_screen.dart`, [next_away_game.dart] 와 같은 분담).
///
/// "최근 경기"의 기준: 선택 팀이 홈이든 원정이든 상관없이 `status ==
/// finished` 인 경기. 날짜(같은 날이면 시작 시각) 내림차순으로 최신
/// 경기부터 최대 [kRecentGamesLimit] 개를 고른다. 선발 투수·날씨 자리는
/// 만들지 않는다 — 데이터 원천 자체가 없다(decisions.md 2026-09-01).
library;

import '../../content/models.dart';

/// 내 팀 관점의 승패 — [Game.result] 는 언제나 **홈팀 기준**이라
/// [teamId] 가 원정이면 뒤집어야 한다.
enum TeamGameOutcome { win, loss, draw }

/// [game] 을 [teamId] 관점에서 본 승패.
///
/// [game.status] 가 [GameStatus.finished] 여야 한다 — 그 밖의 경기는
/// [Game.result] 가 없어 승패를 잴 수 없다(계약이 그렇게 보장한다).
TeamGameOutcome outcomeFor(Game game, String teamId) {
  final result = game.result;
  assert(result != null, '종료되지 않은 경기의 승패는 없다: ${game.id}');
  return switch (result!) {
    GameResult.draw => TeamGameOutcome.draw,
    GameResult.homeWin =>
      teamId == game.homeTeamId ? TeamGameOutcome.win : TeamGameOutcome.loss,
    GameResult.awayWin =>
      teamId == game.awayTeamId ? TeamGameOutcome.win : TeamGameOutcome.loss,
  };
}

/// [outcome] 의 한 글자 표기 — 요약 카드가 그대로 쓴다.
String outcomeLabel(TeamGameOutcome outcome) => switch (outcome) {
      TeamGameOutcome.win => '승',
      TeamGameOutcome.loss => '패',
      TeamGameOutcome.draw => '무',
    };

/// acceptance criteria "최대 5개"의 개수 상한.
const int kRecentGamesLimit = 5;

/// [teamId] 의 최근 종료 경기를 최신순으로 최대 [limit] 개.
///
/// 홈·원정 구분 없이 [teamId] 가 낀 `finished` 경기만 대상이다 — 예정·취소
/// (우천취소 포함) 경기는 "결과"가 아니므로 제외한다. 경기가 [limit] 보다
/// 적으면 있는 만큼만, 하나도 없으면 빈 리스트를 돌려준다(호출부가 빈
/// 상태를 그린다).
List<Game> recentGamesFor({
  required ScheduleDocument schedule,
  required String teamId,
  int limit = kRecentGamesLimit,
}) {
  final finished = schedule.games.where((game) {
    if (game.status != GameStatus.finished) return false;
    return game.homeTeamId == teamId || game.awayTeamId == teamId;
  }).toList()
    ..sort(_byDateThenStartDesc);
  return finished.take(limit).toList();
}

/// 최신순(내림차순) 정렬 — date·startTime 은 고정 폭이라 문자열 비교가
/// 시간순이다([next_away_game.dart]의 `_byDateThenStart` 와 같은 근거,
/// 방향만 반대).
int _byDateThenStartDesc(Game a, Game b) {
  final byDate = b.date.compareTo(a.date);
  if (byDate != 0) return byDate;
  return b.startTime.compareTo(a.startTime);
}
