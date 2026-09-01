/// Step 2.3 boundary tests (단위) — 다음 원정 경기 계산.
///
/// - 오늘 경기 픽스처 → "오늘" 상태
/// - 미래 경기 픽스처 → 올바른 D-day 수
/// - 일정 소진 픽스처 → 빈 상태
/// - 잠실 경기 픽스처 → 홈팀 기준 테마 선택
/// - (schemaVersion 2) 오늘 끝난 경기는 자정까지 "오늘", 지난 종료 경기는 제외
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

    // schemaVersion 2 가 더한 finished 상태 — "오늘 경기는 그날 자정까지 오늘"
    // 불변식이 종료 경기에도 그대로 적용된다 (decisions.md 2026-09-01 [M]).
    group('오늘 끝난 원정 경기 (status: finished)', () {
      Game finishedToday({String id = 'today', String date = '2026-08-25'}) =>
          game(
            id: id,
            date: date,
            home: 'lg',
            away: 'lotte',
            stadium: 'jamsil',
            status: GameStatus.finished,
            homeScore: 3,
            awayScore: 7,
            result: GameResult.awayWin,
          );

      test('뒤에 내일 경기가 있어도 오늘 경기로 남는다 (D-1 로 넘어가지 않는다)', () {
        final doc = schedule([
          finishedToday(),
          game(
            id: 'tomorrow',
            date: '2026-08-26',
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

      test('그날 자정 직전(23:30)까지 오늘 경기다', () {
        final doc = schedule([finishedToday()]);
        final lateNight = DateTime.parse('2026-08-25T23:30:00+09:00');
        expect(
          findNextAwayGame(schedule: doc, teamId: 'lotte', now: lateNight),
          isA<AwayGameToday>(),
        );
      });

      test('자정을 넘긴 어제의 종료 경기는 후보에서 빠진다', () {
        final doc = schedule([finishedToday(id: 'yesterday')]);
        final afterMidnight = DateTime.parse('2026-08-26T00:10:00+09:00');
        expect(
          findNextAwayGame(schedule: doc, teamId: 'lotte', now: afterMidnight),
          isA<NoUpcomingAwayGame>(),
        );
      });

      // step 1.2 가 크롤 창을 과거로 넓히면 지난 종료 경기가 대량으로 들어온다.
      test('지난 날짜의 종료 경기가 섞여 있어도 다음 예정 경기를 고른다', () {
        final doc = schedule([
          finishedToday(id: 'past-1', date: '2026-08-10'),
          finishedToday(id: 'past-2', date: '2026-08-24'),
          game(
            id: 'next',
            date: '2026-08-30',
            home: 'samsung',
            away: 'lotte',
            stadium: 'daegu',
          ),
        ]);

        final result =
            findNextAwayGame(schedule: doc, teamId: 'lotte', now: now);
        expect(result, isA<AwayGameUpcoming>());
        expect((result as AwayGameUpcoming).game.id, 'next');
        expect(result.dDay, 5);
      });
    });

    // step 1.2: 크롤 창이 과거 14일로 넓어지면서 산출물에 지난 경기가 상시로
    // 섞인다(실측 108 → 168경기, 종료 48건). 소수의 픽스처가 아니라 "과거가
    // 대량으로 들어와도 결과가 같다"를 직접 단언한다.
    group('과거 구간이 섞인 산출물 (크롤 창 과거 확장)', () {
      // 오늘(8/25) 이전 14일 × 하루 5경기 = 70경기. 내 팀이 원정인 경기와
      // 아닌 경기, 종료·취소가 섞이도록 만든다.
      List<Game> pastWindow() {
        final games = <Game>[];
        for (var back = 14; back >= 1; back -= 1) {
          final day = DateTime.utc(2026, 8, 25).subtract(Duration(days: back));
          final date = '${day.year.toString().padLeft(4, '0')}-'
              '${day.month.toString().padLeft(2, '0')}-'
              '${day.day.toString().padLeft(2, '0')}';
          for (var slot = 0; slot < 5; slot += 1) {
            final canceled = (back + slot) % 7 == 0;
            games.add(
              game(
                id: 'past-$date-$slot',
                date: date,
                // 절반은 내 팀(lotte)이 원정인 경기 — 날짜로 안 거르면 후보가 된다.
                home: slot.isEven ? 'lg' : 'samsung',
                away: slot.isEven ? 'lotte' : 'kia',
                stadium: slot.isEven ? 'jamsil' : 'daegu',
                status: canceled
                    ? GameStatus.rainCanceled
                    : GameStatus.finished,
                homeScore: canceled ? null : 3,
                awayScore: canceled ? null : 7,
                result: canceled ? null : GameResult.awayWin,
              ),
            );
          }
        }
        return games;
      }

      final future = <Game>[
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
      ];

      test('다음 원정 D-day 가 과거 구간 유무와 무관하게 같다', () {
        final before = findNextAwayGame(
          schedule: schedule(future),
          teamId: 'lotte',
          now: now,
        );
        final after = findNextAwayGame(
          schedule: schedule([...pastWindow(), ...future]),
          teamId: 'lotte',
          now: now,
        );

        expect(before, isA<AwayGameUpcoming>());
        expect((after as AwayGameUpcoming).game.id,
            (before as AwayGameUpcoming).game.id);
        expect(after.dDay, before.dDay);
        expect(after.dDay, 5);
      });

      test('오늘 취소 감지가 과거 구간 유무와 무관하게 같다', () {
        final todayCanceled = game(
          id: 'today',
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.rainCanceled,
        );

        final before = findTodayCanceledAwayGame(
          schedule: schedule([todayCanceled, ...future]),
          teamId: 'lotte',
          now: now,
        );
        final after = findTodayCanceledAwayGame(
          schedule: schedule([...pastWindow(), todayCanceled, ...future]),
          teamId: 'lotte',
          now: now,
        );

        expect(before?.id, 'today');
        expect(after?.id, before?.id);
      });

      test('과거 구간에 취소 경기가 널려 있어도 오늘 취소만 잡는다', () {
        // 과거 창에는 rain_canceled 가 10건 들어 있다 — 날짜를 안 보면 플랜B가
        // 아무 날에나 켜진다.
        final past = pastWindow();
        expect(
          past.where((g) => g.status == GameStatus.rainCanceled).length,
          greaterThan(0),
        );
        expect(
          findTodayCanceledAwayGame(
            schedule: schedule([...past, ...future]),
            teamId: 'lotte',
            now: now,
          ),
          isNull,
        );
      });

      test('과거 종료 경기만 있고 미래가 비면 빈 상태 — 지난 경기를 집어 들지 않는다', () {
        expect(
          findNextAwayGame(
            schedule: schedule(pastWindow()),
            teamId: 'lotte',
            now: now,
          ),
          isA<NoUpcomingAwayGame>(),
        );
      });
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

  group('findTodayCanceledAwayGame — 상태별 홈 모드 분기 (step 4.2)', () {
    Game todayGame(GameStatus status) => game(
          id: 'today',
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: status,
        );

    test('scheduled 오늘 경기 → null (정상 모드, 홈 무변화)', () {
      final doc = schedule([todayGame(GameStatus.scheduled)]);
      expect(
        findTodayCanceledAwayGame(schedule: doc, teamId: 'lotte', now: now),
        isNull,
      );
    });

    // schemaVersion 2 가 더한 상태 — "scheduled 가 아니면 취소"로 읽으면
    // 끝난 경기가 플랜B를 띄운다.
    test('finished 오늘 경기 → null (취소가 아니다)', () {
      final doc = schedule([
        game(
          id: 'today',
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.finished,
          homeScore: 3,
          awayScore: 7,
          result: GameResult.awayWin,
        ),
      ]);
      expect(
        findTodayCanceledAwayGame(schedule: doc, teamId: 'lotte', now: now),
        isNull,
      );
      // 끝난 경기는 플랜B 근거가 아니지만, 오늘 경기라면 여전히 "오늘 경기"다.
      expect(
        findNextAwayGame(schedule: doc, teamId: 'lotte', now: now),
        isA<AwayGameToday>(),
      );
    });

    test('canceled 오늘 경기 → 그 경기 (플랜B 모드)', () {
      final doc = schedule([todayGame(GameStatus.canceled)]);
      final result =
          findTodayCanceledAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect(result?.id, 'today');
    });

    test('rain_canceled 오늘 경기 → 그 경기 (플랜B 모드)', () {
      final doc = schedule([todayGame(GameStatus.rainCanceled)]);
      final result =
          findTodayCanceledAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect(result?.id, 'today');
    });

    test('오늘(KST)이 아닌 취소 경기(어제·내일)는 플랜B 대상이 아니다', () {
      final doc = schedule([
        game(
          id: 'yesterday',
          date: '2026-08-24',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.rainCanceled,
        ),
        game(
          id: 'tomorrow',
          date: '2026-08-26',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.canceled,
        ),
      ]);
      expect(
        findTodayCanceledAwayGame(schedule: doc, teamId: 'lotte', now: now),
        isNull,
      );
    });

    test('내 원정 경기가 아니면(홈 경기·다른 팀 경기) 대상이 아니다', () {
      final doc = schedule([
        game(
          id: 'home-side',
          date: '2026-08-25',
          home: 'lotte',
          away: 'lg',
          stadium: 'sajik',
          status: GameStatus.rainCanceled,
        ),
        game(
          id: 'someone-else',
          date: '2026-08-25',
          home: 'nc',
          away: 'hanwha',
          stadium: 'changwon',
          status: GameStatus.canceled,
        ),
      ]);
      expect(
        findTodayCanceledAwayGame(schedule: doc, teamId: 'lotte', now: now),
        isNull,
      );
    });

    test('오늘 취소 + 미래 경기 → 플랜B와 다음 D-day 계산이 독립으로 동작한다', () {
      final doc = schedule([
        todayGame(GameStatus.rainCanceled),
        game(
          id: 'next',
          date: '2026-08-30',
          home: 'samsung',
          away: 'lotte',
          stadium: 'daegu',
        ),
      ]);

      final canceled =
          findTodayCanceledAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect(canceled?.id, 'today');

      final next = findNextAwayGame(schedule: doc, teamId: 'lotte', now: now);
      expect((next as AwayGameUpcoming).game.id, 'next');
      expect(next.dDay, 5);
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
