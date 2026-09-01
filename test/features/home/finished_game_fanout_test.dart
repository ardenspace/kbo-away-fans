/// schemaVersion 2 의 `finished` 가 홈 계산에 미치는 파장 중, 기존 테스트가
/// 덮지 않는 두 자리를 못 박는다.
///
/// 1. **더블헤더** — 같은 날 원정 경기가 둘일 때 고르는 기준은 종료 여부와
///    무관하게 시작 시각이 빠른 쪽 (decisions.md 2026-09-01 [S]).
///    `next_away_game_test.dart` 는 같은 날 두 건을 세우지 않아 이 규칙이
///    `finished` 유입 뒤에도 유지되는지 확인되지 않는다.
/// 2. **탐색 모드 테마** — 잠실(홈팀 2팀)의 "그날의 홈팀" 판정이 당일 경기가
///    끝난 뒤에도 중립으로 떨어지지 않는지. `stadium_browse_test.dart` 는
///    우천취소까지만 못 박았다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/features/home/stadium_browse.dart';

Game awayGame({
  required String id,
  required String date,
  required String startTime,
  required String home,
  String away = 'lotte',
  String stadium = 'jamsil',
  GameStatus status = GameStatus.scheduled,
  int? homeScore,
  int? awayScore,
  GameResult? result,
}) {
  return Game(
    id: id,
    date: date,
    startTime: startTime,
    homeTeamId: home,
    awayTeamId: away,
    stadiumId: stadium,
    status: status,
    homeScore: homeScore,
    awayScore: awayScore,
    result: result,
  );
}

ScheduleDocument scheduleOf(List<Game> games) =>
    ScheduleDocument(generatedAt: DateTime.utc(2026), games: games);

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  // 기준 시각: 2026-08-25 (화) 20:00 KST — 낮 경기는 끝났고 밤 경기는 시작 전.
  final now = DateTime.parse('2026-08-25T20:00:00+09:00');

  group('더블헤더 — 시작 시각이 빠른 쪽 (종료 여부와 무관)', () {
    test('낮 경기가 끝나고 밤 경기가 남아 있어도 낮(종료) 경기를 고른다', () {
      final doc = scheduleOf([
        awayGame(
          id: 'dh-1',
          date: '2026-08-25',
          startTime: '14:00',
          home: 'lg',
          status: GameStatus.finished,
          homeScore: 3,
          awayScore: 7,
          result: GameResult.awayWin,
        ),
        awayGame(
          id: 'dh-2',
          date: '2026-08-25',
          startTime: '18:30',
          home: 'lg',
        ),
      ]);

      final result = findNextAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect(result, isA<AwayGameToday>());
      expect((result as AwayGameToday).game.id, 'dh-1');
    });

    test('목록 순서가 뒤집혀도 결과가 같다 (밤 경기가 끝나고 낮 경기가 예정인 뒤집힌 짝)', () {
      final late_ = awayGame(
        id: 'dh-2',
        date: '2026-08-25',
        startTime: '18:30',
        home: 'lg',
        status: GameStatus.finished,
        homeScore: 1,
        awayScore: 0,
        result: GameResult.homeWin,
      );
      final early = awayGame(
        id: 'dh-1',
        date: '2026-08-25',
        startTime: '14:00',
        home: 'lg',
      );

      for (final games in [
        [late_, early],
        [early, late_],
      ]) {
        final result = findNextAwayGame(
          schedule: scheduleOf(games),
          teamId: 'lotte',
          now: now,
        );
        expect(result, isA<AwayGameToday>());
        expect((result as AwayGameToday).game.id, 'dh-1');
      }
    });

    test('낮 경기가 우천취소면 밤의 종료 경기가 "오늘 경기", 플랜B 근거는 낮 경기', () {
      final doc = scheduleOf([
        awayGame(
          id: 'dh-1',
          date: '2026-08-25',
          startTime: '14:00',
          home: 'lg',
          status: GameStatus.rainCanceled,
        ),
        awayGame(
          id: 'dh-2',
          date: '2026-08-25',
          startTime: '18:30',
          home: 'lg',
          status: GameStatus.finished,
          homeScore: 2,
          awayScore: 2,
          result: GameResult.draw,
        ),
      ]);

      final next = findNextAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect(next, isA<AwayGameToday>());
      expect((next as AwayGameToday).game.id, 'dh-2');

      expect(
        findTodayCanceledAwayGame(schedule: doc, teamId: 'lotte', now: now)?.id,
        'dh-1',
      );
    });
  });

  group('탐색 모드 테마 — 당일 경기가 끝난 뒤', () {
    late TeamsDocument teams;
    late Stadium jamsil;

    setUpAll(() {
      teams =
          TeamsDocument.fromJson(_readJson('content-pipeline/data/teams.json'));
      jamsil = StadiumsDocument.fromJson(
        _readJson('content-pipeline/data/stadiums.json'),
      ).byId('jamsil')!;
    });

    test('잠실 당일 경기가 끝나 있어도 그 경기 홈팀 테마 (중립으로 안 떨어진다)', () {
      final doc = scheduleOf([
        awayGame(
          id: 'today',
          date: '2026-08-25',
          startTime: '14:00',
          home: 'doosan',
          status: GameStatus.finished,
          homeScore: 9,
          awayScore: 1,
          result: GameResult.homeWin,
        ),
      ]);

      expect(
        browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: doc,
          now: now,
        ),
        'doosan',
      );
    });
  });
}
