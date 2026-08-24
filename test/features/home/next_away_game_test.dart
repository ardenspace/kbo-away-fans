/// Step 2.3 boundary tests (단위) — 다음 원정 경기 계산.
///
/// - 오늘 경기 픽스처 → "오늘" 상태
/// - 미래 경기 픽스처 → 올바른 D-day 수
/// - 일정 소진 픽스처 → 빈 상태
/// - 잠실 경기 픽스처 → 홈팀 기준 테마 선택
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';

/// 테스트용 경기 픽스처 헬퍼.
Game game({
  required String id,
  required String date,
  String startTime = '18:30',
  required String home,
  required String away,
  required String stadium,
  GameStatus status = GameStatus.scheduled,
}) {
  return Game(
    id: id,
    date: date,
    startTime: startTime,
    homeTeamId: home,
    awayTeamId: away,
    stadiumId: stadium,
    status: status,
  );
}

ScheduleDocument schedule(List<Game> games) =>
    ScheduleDocument(generatedAt: DateTime.utc(2026), games: games);

void main() {
  // 기준 시각: 2026-08-25 (화) 낮, KST.
  final now = DateTime.parse('2026-08-25T14:00:00+09:00');

  group('findNextAwayGame', () {
    test('오늘 원정 경기 픽스처 → "오늘" 상태 (AwayGameToday)', () {
      final doc = schedule([
        game(
          id: 'today',
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        ),
      ]);

      final result =
          findNextAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect(result, isA<AwayGameToday>());
      expect((result as AwayGameToday).game.id, 'today');
    });

    test('오늘 경기는 시작 시각(18:30)이 지나도 그날 자정까지 "오늘"이다', () {
      final doc = schedule([
        game(
          id: 'today',
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        ),
      ]);

      final lateNight = DateTime.parse('2026-08-25T23:30:00+09:00');
      final result =
          findNextAwayGame(schedule: doc, teamId: 'lotte', now: lateNight);
      expect(result, isA<AwayGameToday>());
    });

    test('미래 경기 픽스처 → 올바른 D-day 수', () {
      final doc = schedule([
        // 과거 경기·상대 팀 경기·더 먼 경기가 섞여 있어도
        // 가장 가까운 "내 원정" 경기(8/30, D-5)를 골라야 한다.
        game(
          id: 'past',
          date: '2026-08-20',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        ),
        game(
          id: 'someone-else',
          date: '2026-08-27',
          home: 'nc',
          away: 'hanwha',
          stadium: 'changwon',
        ),
        game(
          id: 'home-not-away',
          date: '2026-08-28',
          home: 'lotte',
          away: 'lg',
          stadium: 'sajik',
        ),
        game(
          id: 'next',
          date: '2026-08-30',
          home: 'samsung',
          away: 'lotte',
          stadium: 'daegu',
        ),
        game(
          id: 'later',
          date: '2026-09-02',
          home: 'kia',
          away: 'lotte',
          stadium: 'gwangju',
        ),
      ]);

      final result =
          findNextAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect(result, isA<AwayGameUpcoming>());
      final upcoming = result as AwayGameUpcoming;
      expect(upcoming.game.id, 'next');
      expect(upcoming.dDay, 5);
    });

    test('취소·우천취소 경기는 다음 원정으로 세지 않는다', () {
      final doc = schedule([
        game(
          id: 'rain',
          date: '2026-08-26',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.rainCanceled,
        ),
        game(
          id: 'canceled',
          date: '2026-08-27',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.canceled,
        ),
        game(
          id: 'next',
          date: '2026-08-29',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        ),
      ]);

      final result =
          findNextAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect((result as AwayGameUpcoming).game.id, 'next');
      expect(result.dDay, 4);
    });

    test('일정 소진 픽스처(과거 경기만) → 빈 상태 (NoUpcomingAwayGame)', () {
      final doc = schedule([
        game(
          id: 'past-1',
          date: '2026-08-10',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        ),
        game(
          id: 'past-2',
          date: '2026-08-20',
          home: 'samsung',
          away: 'lotte',
          stadium: 'daegu',
        ),
      ]);

      final result =
          findNextAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect(result, isA<NoUpcomingAwayGame>());
    });

    test('빈 일정 문서 → 빈 상태', () {
      final result = findNextAwayGame(
        schedule: schedule(const []),
        teamId: 'lotte',
        now: now,
      );
      expect(result, isA<NoUpcomingAwayGame>());
    });
  });

  group('themeKeyForGame — 잠실 경기 픽스처', () {
    late TeamsDocument teams;

    setUpAll(() {
      final root = jsonDecode(
        File('content-pipeline/data/teams.json').readAsStringSync(),
      ) as Map<String, Object?>;
      teams = TeamsDocument.fromJson(root);
    });

    test('잠실 경기의 테마는 구장이 아니라 홈팀 기준 — LG 홈이면 lg', () {
      final jamsilLgHome = game(
        id: 'jamsil-lg',
        date: '2026-08-30',
        home: 'lg',
        away: 'lotte',
        stadium: 'jamsil',
      );
      expect(
        themeKeyForGame(jamsilLgHome, teams),
        teams.byId('lg')!.themeKey,
      );
    });

    test('같은 잠실이라도 두산 홈이면 doosan 테마', () {
      final jamsilDoosanHome = game(
        id: 'jamsil-doosan',
        date: '2026-08-31',
        home: 'doosan',
        away: 'lotte',
        stadium: 'jamsil',
      );
      expect(
        themeKeyForGame(jamsilDoosanHome, teams),
        teams.byId('doosan')!.themeKey,
      );
      // 홈팀이 다르면 같은 구장이어도 테마 키가 달라진다.
      expect(
        themeKeyForGame(jamsilDoosanHome, teams),
        isNot(teams.byId('lg')!.themeKey),
      );
    });
  });
}
