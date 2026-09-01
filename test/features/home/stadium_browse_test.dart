/// Step 4.3 boundary tests (단위) — 탐색 모드 테마 결정 규칙.
///
/// 잠실(homeTeams 2팀): 당일(KST) 그 구장 경기가 있으면 그 경기 홈팀 테마,
/// 없으면 중립(null = 팀 스코프 없음). 단일 홈팀 구장은 항상 그 팀 테마.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/stadium_browse.dart';

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

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  late TeamsDocument teams;
  late StadiumsDocument stadiums;
  late Stadium jamsil;

  setUpAll(() {
    teams = TeamsDocument.fromJson(_readJson('content-pipeline/data/teams.json'));
    stadiums = StadiumsDocument.fromJson(
      _readJson('content-pipeline/data/stadiums.json'),
    );
    jamsil = stadiums.byId('jamsil')!;
  });

  // 기준 시각: 2026-08-25 (화) 낮, KST.
  final now = DateTime.parse('2026-08-25T14:00:00+09:00');

  group('browseThemeKeyForStadium — 잠실 (homeTeams 2팀)', () {
    test('당일 잠실 경기가 있으면 그 경기 홈팀 테마 — LG 홈이면 lg', () {
      final doc = schedule([
        game(
          id: 'today',
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        ),
      ]);
      expect(
        browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: doc,
          now: now,
        ),
        teams.byId('lg')!.themeKey,
      );
    });

    test('같은 잠실이라도 당일 두산 홈 경기면 doosan 테마', () {
      final doc = schedule([
        game(
          id: 'today',
          date: '2026-08-25',
          home: 'doosan',
          away: 'kia',
          stadium: 'jamsil',
        ),
      ]);
      expect(
        browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: doc,
          now: now,
        ),
        teams.byId('doosan')!.themeKey,
      );
    });

    test('당일 잠실 경기가 없으면(다른 날·다른 구장뿐) 중립(null)', () {
      final doc = schedule([
        // 내일 잠실 경기 — "당일"이 아니다.
        game(
          id: 'tomorrow',
          date: '2026-08-26',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        ),
        // 당일이지만 다른 구장.
        game(
          id: 'elsewhere',
          date: '2026-08-25',
          home: 'samsung',
          away: 'nc',
          stadium: 'daegu',
        ),
      ]);
      expect(
        browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: doc,
          now: now,
        ),
        isNull,
      );
    });

    test('빈 일정 문서 → 중립(null)', () {
      expect(
        browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: schedule(const []),
          now: now,
        ),
        isNull,
      );
    });

    test('schedule 문서를 못 얻었으면(null) 중립(null)', () {
      expect(
        browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: null,
          now: now,
        ),
        isNull,
      );
    });

    test('당일 우천취소 경기도 "그날의 홈팀"으로 인정한다 (플랜B 테마 규칙과 일관)', () {
      final doc = schedule([
        game(
          id: 'today-rain',
          date: '2026-08-25',
          home: 'doosan',
          away: 'lotte',
          stadium: 'jamsil',
          status: GameStatus.rainCanceled,
        ),
      ]);
      expect(
        browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: doc,
          now: now,
        ),
        teams.byId('doosan')!.themeKey,
      );
    });

    // step 1.2: 크롤 창이 과거 14일로 넓어져 산출물에 지난 경기가 상시로 섞인다.
    // 잠실은 홈팀이 2팀이라 "그날의 홈팀"을 지난 경기에서 고르면 테마가 틀린다.
    group('과거 구간이 섞인 산출물 (크롤 창 과거 확장)', () {
      // 오늘(8/25) 이전 14일치 잠실 경기 — LG·두산이 번갈아 홈이고 전부 종료.
      List<Game> pastJamsil() => [
            for (var back = 14; back >= 1; back -= 1)
              game(
                id: 'past-$back',
                date: '2026-08-${(25 - back).toString().padLeft(2, '0')}',
                startTime: '14:00', // 오늘 경기보다 이른 시각 — 정렬만 보면 이긴다
                home: back.isEven ? 'doosan' : 'lg',
                away: 'lotte',
                stadium: 'jamsil',
                status: GameStatus.finished,
              ),
          ];

      test('과거 잠실 경기가 대량으로 섞여도 당일 홈팀 테마는 그대로다', () {
        final today = game(
          id: 'today',
          date: '2026-08-25',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        );
        final before = browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: schedule([today]),
          now: now,
        );
        final after = browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: schedule([...pastJamsil(), today]),
          now: now,
        );
        expect(after, before);
        expect(after, teams.byId('lg')!.themeKey);
      });

      test('과거 잠실 경기만 있고 당일 경기가 없으면 중립(null)', () {
        expect(
          browseThemeKeyForStadium(
            stadium: jamsil,
            teams: teams,
            schedule: schedule(pastJamsil()),
            now: now,
          ),
          isNull,
        );
      });
    });

    test('당일 경기가 여럿이면 시작 시각이 빠른 경기의 홈팀', () {
      final doc = schedule([
        game(
          id: 'evening',
          date: '2026-08-25',
          startTime: '18:30',
          home: 'doosan',
          away: 'kia',
          stadium: 'jamsil',
        ),
        game(
          id: 'afternoon',
          date: '2026-08-25',
          startTime: '14:00',
          home: 'lg',
          away: 'lotte',
          stadium: 'jamsil',
        ),
      ]);
      expect(
        browseThemeKeyForStadium(
          stadium: jamsil,
          teams: teams,
          schedule: doc,
          now: now,
        ),
        teams.byId('lg')!.themeKey,
      );
    });
  });

  group('browseThemeKeyForStadium — 단일 홈팀 구장', () {
    test('사직은 경기가 없어도 항상 lotte 테마', () {
      expect(
        browseThemeKeyForStadium(
          stadium: stadiums.byId('sajik')!,
          teams: teams,
          schedule: schedule(const []),
          now: now,
        ),
        teams.byId('lotte')!.themeKey,
      );
    });

    test('schedule 이 null 이어도 단일 홈팀 구장은 그 팀 테마 (대구 → samsung)', () {
      expect(
        browseThemeKeyForStadium(
          stadium: stadiums.byId('daegu')!,
          teams: teams,
          schedule: null,
          now: now,
        ),
        teams.byId('samsung')!.themeKey,
      );
    });
  });
}
