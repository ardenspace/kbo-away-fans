/// Step 5.1 boundary tests (단위) — 홈 최근 5경기 결과 요약의 순수 로직.
///
/// - 종료 경기가 5개 초과면 최신 5개만, 최신순
/// - 5개 미만이면 있는 만큼만
/// - 0개면 빈 리스트 (호출부가 빈 상태를 그리는 근거)
/// - 홈/원정 양쪽 경기 모두 대상, 승패는 내 팀 관점으로 뒤집힌다
/// - 무승부 표시
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/recent_games.dart';

/// 테스트용 종료 경기 픽스처 헬퍼 — [next_away_game_test.dart] 의 `game()` 과
/// 같은 모양이되 기본 상태를 finished 로 두고 점수·승패를 필수로 받는다.
Game finishedGame({
  required String id,
  required String date,
  String startTime = '18:30',
  required String home,
  required String away,
  String stadium = 'jamsil',
  required int homeScore,
  required int awayScore,
}) {
  final result = homeScore > awayScore
      ? GameResult.homeWin
      : homeScore < awayScore
          ? GameResult.awayWin
          : GameResult.draw;
  return Game(
    id: id,
    date: date,
    startTime: startTime,
    homeTeamId: home,
    awayTeamId: away,
    stadiumId: stadium,
    status: GameStatus.finished,
    homeScore: homeScore,
    awayScore: awayScore,
    result: result,
  );
}

/// 아직 끝나지 않은(예정) 경기 픽스처 — 결과 대상이 아님을 확인하는 용도.
Game scheduledGame({
  required String id,
  required String date,
  required String home,
  required String away,
  String stadium = 'jamsil',
}) {
  return Game(
    id: id,
    date: date,
    startTime: '18:30',
    homeTeamId: home,
    awayTeamId: away,
    stadiumId: stadium,
    status: GameStatus.scheduled,
  );
}

ScheduleDocument scheduleOf(List<Game> games) =>
    ScheduleDocument(generatedAt: DateTime.utc(2026), games: games);

void main() {
  group('recentGamesFor — 개수 갈래', () {
    test('종료 경기가 5개 초과면 최신 5개만, 최신순으로 돌려준다', () {
      // 8/20 ~ 8/27, 매일 하나씩 8건 — lotte 가 매번 낀다.
      final games = [
        for (var day = 20; day <= 27; day++)
          finishedGame(
            id: 'g$day',
            date: '2026-08-$day',
            home: 'lg',
            away: 'lotte',
            homeScore: day,
            awayScore: 1,
          ),
      ];
      final doc = scheduleOf(games);

      final result = recentGamesFor(schedule: doc, teamId: 'lotte');

      expect(result.length, 5);
      expect(
        result.map((g) => g.id).toList(),
        ['g27', 'g26', 'g25', 'g24', 'g23'],
      );
    });

    test('종료 경기가 5개보다 적으면 있는 만큼만 돌려준다', () {
      final games = [
        finishedGame(
          id: 'g1',
          date: '2026-08-20',
          home: 'lg',
          away: 'lotte',
          homeScore: 3,
          awayScore: 1,
        ),
        finishedGame(
          id: 'g2',
          date: '2026-08-21',
          home: 'lotte',
          away: 'kt',
          homeScore: 2,
          awayScore: 5,
        ),
      ];
      final doc = scheduleOf(games);

      final result = recentGamesFor(schedule: doc, teamId: 'lotte');

      expect(result.length, 2);
      expect(result.map((g) => g.id).toList(), ['g2', 'g1']);
    });

    test('종료 경기가 하나도 없으면 빈 리스트를 돌려준다', () {
      final doc = scheduleOf([
        scheduledGame(id: 's1', date: '2026-08-30', home: 'lg', away: 'lotte'),
      ]);

      final result = recentGamesFor(schedule: doc, teamId: 'lotte');

      expect(result, isEmpty);
    });

    test('내 팀이 낀 경기가 아예 없어도 빈 리스트를 돌려준다', () {
      final doc = scheduleOf([
        finishedGame(
          id: 'g1',
          date: '2026-08-20',
          home: 'lg',
          away: 'kt',
          homeScore: 3,
          awayScore: 1,
        ),
      ]);

      final result = recentGamesFor(schedule: doc, teamId: 'lotte');

      expect(result, isEmpty);
    });

    test('예정·취소 경기는 결과가 아니므로 제외한다', () {
      final doc = scheduleOf([
        finishedGame(
          id: 'finished',
          date: '2026-08-20',
          home: 'lg',
          away: 'lotte',
          homeScore: 3,
          awayScore: 1,
        ),
        scheduledGame(
          id: 'scheduled',
          date: '2026-08-25',
          home: 'lotte',
          away: 'kt',
        ),
        Game(
          id: 'canceled',
          date: '2026-08-24',
          startTime: '18:30',
          homeTeamId: 'lotte',
          awayTeamId: 'samsung',
          stadiumId: 'sajik',
          status: GameStatus.canceled,
        ),
      ]);

      final result = recentGamesFor(schedule: doc, teamId: 'lotte');

      expect(result.map((g) => g.id).toList(), ['finished']);
    });
  });

  group('recentGamesFor — 홈/원정 양쪽 포함', () {
    test('내 팀이 홈인 경기와 원정인 경기를 모두 담는다', () {
      final homeGame = finishedGame(
        id: 'home-game',
        date: '2026-08-21',
        home: 'lotte',
        away: 'kt',
        homeScore: 4,
        awayScore: 2,
      );
      final awayGame = finishedGame(
        id: 'away-game',
        date: '2026-08-20',
        home: 'lg',
        away: 'lotte',
        homeScore: 3,
        awayScore: 6,
      );
      final doc = scheduleOf([homeGame, awayGame]);

      final result = recentGamesFor(schedule: doc, teamId: 'lotte');

      expect(result.map((g) => g.id).toList(), ['home-game', 'away-game']);
    });
  });

  group('outcomeFor — 내 팀 관점 승패', () {
    test('내가 홈이고 홈 승리면 승', () {
      final game = finishedGame(
        id: 'g',
        date: '2026-08-20',
        home: 'lotte',
        away: 'kt',
        homeScore: 5,
        awayScore: 1,
      );
      expect(outcomeFor(game, 'lotte'), TeamGameOutcome.win);
    });

    test('내가 원정이고 홈 승리면 패 (결과 필드가 홈팀 기준이라 뒤집힌다)', () {
      final game = finishedGame(
        id: 'g',
        date: '2026-08-20',
        home: 'lg',
        away: 'lotte',
        homeScore: 5,
        awayScore: 1,
      );
      expect(outcomeFor(game, 'lotte'), TeamGameOutcome.loss);
    });

    test('무승부는 홈/원정 어느 쪽에서 봐도 무 — 그리고 표시 문구는 "무"', () {
      final homeSide = finishedGame(
        id: 'g1',
        date: '2026-08-20',
        home: 'lotte',
        away: 'kt',
        homeScore: 3,
        awayScore: 3,
      );
      final awaySide = finishedGame(
        id: 'g2',
        date: '2026-08-21',
        home: 'kt',
        away: 'lotte',
        homeScore: 2,
        awayScore: 2,
      );

      expect(outcomeFor(homeSide, 'lotte'), TeamGameOutcome.draw);
      expect(outcomeFor(awaySide, 'lotte'), TeamGameOutcome.draw);
      expect(outcomeLabel(TeamGameOutcome.draw), '무');
      expect(outcomeLabel(TeamGameOutcome.win), '승');
      expect(outcomeLabel(TeamGameOutcome.loss), '패');
    });
  });
}
