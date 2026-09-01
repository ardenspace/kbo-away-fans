/// 계층 사이의 이음매 — 각 계층 테스트가 자기 안에서만 촘촘해서
/// 아무도 밟지 않는 자리를 잰다.
///
/// 개별 계층의 테스트는 각자 자기 안에서 이미 촘촘하다. 여기서 재는 것은
/// 그 테스트들이 서로 만나지 않는 자리다:
///
///  1) 크롤러가 **실제로 만든 산출물**(`content-pipeline/data/schedule.json`)이
///     앱 파서(1.1)를 지나 백엔드 write 타입(1.6)까지 그대로 흐르는가.
///     기존 테스트는 파서까지만 실물을 태우고, 백엔드 테스트는 손으로 지은
///     값만 태운다 — 둘을 잇는 자리는 비어 있다.
///  2) 배지 판의 칸 값 공간이 실물 일정 · 백엔드 상수 · 판 위젯 · 팀 테마
///     넷에서 한 벌인가 (StampBoard 가 `TeamThemes.byId[...]!` 로 단언하는 그 자리).
///  3) `docs/firestore-schema.md` · `firestore.rules` · Dart 상수에 **세 벌로
///     복제된 값 공간**이 실제로 같은가. 규칙 테스트는 Node 에서만 돌아
///     Dart 상수를 볼 수 없고, Dart 테스트는 규칙 파일을 읽지 않는다 —
///     복제가 어긋나도 두 쪽 테스트가 모두 초록이다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_ids.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  late ScheduleDocument schedule;
  late TeamsDocument teams;

  setUpAll(() {
    final scheduleRoot = _json('content-pipeline/data/schedule.json');
    // 로더가 파싱 전에 거는 관문 — 실물 산출물이 앱이 아는 계약 버전인가.
    expect(scheduleRoot['schemaVersion'], 2);
    schedule = ScheduleDocument.fromJson(scheduleRoot);
    teams = TeamsDocument.fromJson(_json('content-pipeline/data/teams.json'));
  });

  group('실물 크롤 산출물 → 앱 파서 → 백엔드 write 타입', () {
    test('과거 창 확장이 실제로 종료 경기를 남겼다 (점수·승패까지)', () {
      final finished =
          schedule.games.where((g) => g.status == GameStatus.finished).toList();
      expect(
        finished,
        isNotEmpty,
        reason: '과거 14일 창(1.2)이 살아 있으면 산출물에 종료 경기가 있어야 한다',
      );
      for (final game in finished) {
        expect(game.homeScore, isNotNull, reason: game.id);
        expect(game.awayScore, isNotNull, reason: game.id);
        expect(game.result, isNotNull, reason: game.id);
      }
    });

    test('산출물의 모든 경기가 도장 payload 로 그대로 옮겨진다', () {
      for (final game in schedule.games) {
        final stamp = StampWrite(
          stadiumId: game.stadiumId,
          gameId: game.id,
          homeTeamId: game.homeTeamId,
          gameDate: game.date,
        );

        // 계약 위반이면 여기서 ArgumentError 로 막힌다 (1.6 의 값 검사).
        final data = stamp.toData();

        expect(data.keys.toSet(), StampFields.all, reason: game.id);
        expect(data[StampFields.gameId], game.id);
        expect(data[StampFields.stampedAt], isA<ServerTimestamp>());
        // 규칙이 요구하는 문서 id 의 유일한 형태 (1.5 ↔ 1.6).
        expect(stamp.documentId, '${game.stadiumId}_${game.id}');
        expect(kBoardCellIds, contains(stamp.cellId));
      }
    });

    test('산출물의 구장×홈팀 짝이 판의 칸을 벗어나지 않는다', () {
      final pairs = {
        for (final game in schedule.games)
          '${game.stadiumId}_${game.homeTeamId}',
      };
      expect(pairs.difference(kBoardCellIds), isEmpty);
    });

    test('모든 경기의 구장 테마 조회가 성공한다 (홈 화면의 assert 자리)', () {
      for (final game in schedule.games) {
        final key = themeKeyForGame(game, teams);
        expect(TeamThemes.byId[key], isNotNull, reason: game.id);
      }
    });
  });

  group('배지 판의 칸이 네 자리에서 한 값 공간', () {
    test('칸 id 의 뒷조각이 팀 테마 10종과 1:1 (StampBoard 의 `!` 근거)', () {
      final themeKeys = <String>{};
      for (final cellId in kBoardCellIds) {
        final teamId = boardCellTeamId(cellId);
        expect(kTeamIds, contains(teamId), reason: cellId);
        expect(TeamThemes.byId[teamId], isNotNull, reason: cellId);
        themeKeys.add(teamId);
      }
      expect(themeKeys.length, kBoardCellIds.length);
      expect(themeKeys, TeamThemes.byId.keys.toSet());
    });

    test('teams.json 의 themeKey 가 팀 id 와 같다 (규칙이 두 값을 같은 공간으로 잰다)', () {
      // firestore.rules 의 validUser 는 profileThemeKey 를 teamIds() 로 잰다.
      // 두 값 공간이 갈리는 순간 프로필 색이 규칙에서 거부된다.
      for (final team in teams.teams) {
        expect(team.themeKey, team.id);
      }
    });

    test('칸 요약의 등급이 판이 다시 계산한 등급과 어긋날 수 없다', () {
      // BoardCell(1.6)은 tier 를 저장하고 StampBadge(1.8)는 count 에서 다시
      // 계산한다 — 두 경로가 같은 사다리를 쓰는지 개수마다 확인한다.
      for (var count = 1; count <= 15; count++) {
        final cell = BoardCell.forCount(count: count);
        expect(cell.tier, BadgeTierTokens.tierFor(count), reason: '$count개');
      }
      expect(BadgeTierTokens.tierFor(0), isNull);
    });
  });

  group('세 벌로 복제된 값 공간이 실제로 같은가', () {
    late String rules;
    late String schemaDoc;

    setUpAll(() {
      rules = File('firestore.rules').readAsStringSync();
      schemaDoc = File('docs/firestore-schema.md').readAsStringSync();
    });

    /// 규칙의 `함수() { return [...]; }` 에서 따옴표 문자열만 걷어 낸다.
    Set<String> listInRulesFunction(String name) {
      final body = RegExp(
        'function\\s+$name\\s*\\(\\)\\s*\\{(.*?)\\}',
        dotAll: true,
      ).firstMatch(rules);
      expect(body, isNotNull, reason: 'firestore.rules 에 $name() 이 없다');
      return RegExp("'([^']+)'")
          .allMatches(body!.group(1)!)
          .map((m) => m.group(1)!)
          .toSet();
    }

    test('칸 id 10개 — Dart 상수 · 규칙 · 계약 문서', () {
      expect(listInRulesFunction('cellIds'), kBoardCellIds);
      for (final cellId in kBoardCellIds) {
        expect(
          schemaDoc,
          contains('`$cellId`'),
          reason: 'docs/firestore-schema.md 에 $cellId 이 없다',
        );
      }
    });

    test('팀·구장 로스터 — Dart 상수 ↔ 규칙', () {
      expect(listInRulesFunction('teamIds'), kTeamIds);
      expect(listInRulesFunction('stadiumIds'), kStadiumIds);
    });

    test('카테고리 — PlaceCategory ↔ 규칙', () {
      expect(
        listInRulesFunction('categories'),
        PlaceCategory.values.map((c) => c.contractValue).toSet(),
      );
    });

    test('등급 사다리 — BadgeTierTokens ↔ 규칙의 tierFor', () {
      final tierFor = RegExp(
        r'function\s+tierFor\(count\)\s*\{(.*?)\n\s*\}',
        dotAll: true,
      ).firstMatch(rules);
      expect(tierFor, isNotNull);
      final body = tierFor!.group(1)!;

      // 임계값 — 규칙이 든 `count >= N` 전부가 토큰의 minStamps 와 같아야 한다.
      final thresholds = RegExp(r'count\s*>=\s*(\d+)')
          .allMatches(body)
          .map((m) => int.parse(m.group(1)!))
          .toSet();
      expect(thresholds, {
        BadgeTierTokens.regular.minStamps,
        BadgeTierTokens.master.minStamps,
      });

      // 등급 이름의 값 공간 — 규칙이 돌려주는 문자열 셋 = BadgeTier 세 이름.
      final names = RegExp("'([^']+)'")
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();
      expect(names, BadgeTier.values.map((t) => t.name).toSet());
    });

    test('닉네임 길이 한도 — kNicknameMaxLength ↔ 규칙의 size() 검사', () {
      final min = RegExp(r'nickname\.size\(\)\s*>=\s*(\d+)').firstMatch(rules);
      final max = RegExp(r'nickname\.size\(\)\s*<=\s*(\d+)').firstMatch(rules);
      expect(min, isNotNull);
      expect(max, isNotNull);
      expect(int.parse(min!.group(1)!), kNicknameMinLength);
      expect(int.parse(max!.group(1)!), kNicknameMaxLength);
    });

    test('필드 화이트리스트 — 규칙의 hasOnly ↔ Dart 필드 상수', () {
      Set<String> hasOnlyAfter(String anchor) {
        final at = rules.indexOf(anchor);
        expect(at, greaterThanOrEqualTo(0), reason: anchor);
        final call = RegExp(r'hasOnly\(\[(.*?)\]\)', dotAll: true)
            .firstMatch(rules.substring(at));
        expect(call, isNotNull, reason: anchor);
        return RegExp("'([^']+)'")
            .allMatches(call!.group(1)!)
            .map((m) => m.group(1)!)
            .toSet();
      }

      expect(hasOnlyAfter('function validCell('), BoardCellFields.all);
      expect(hasOnlyAfter('function validUser('), UserFields.all);
      expect(hasOnlyAfter('function validStamp('), StampFields.all);
      expect(hasOnlyAfter('function validLike('), LikeFields.all);
    });

    test('도장·좋아요 id 정규식 — Dart 검사 ↔ 규칙', () {
      expect(rules, contains(r"gameId.matches('^[A-Za-z0-9-]{1,64}$')"));
      expect(rules, contains(r"placeId.matches('^[a-z][a-z0-9-]{0,63}$')"));
      // 같은 형태를 Dart 쪽이 실제로 강제하는지 경계값으로 확인한다.
      expect(
        () => StampWrite(
          stadiumId: 'jamsil',
          gameId: 'a' * 65,
          homeTeamId: 'lg',
          gameDate: '2026-09-01',
        ).toData(),
        throwsArgumentError,
      );
      expect(
        () => const LikeWrite(
          placeId: 'Jamsil-Gopchang',
          stadiumId: 'jamsil',
          category: PlaceCategory.food,
        ).toData(),
        throwsArgumentError,
      );
    });
  });

  group('실물 일정으로 홈 계산을 창 전체에 걸쳐 걸어 본다', () {
    test('어느 팀 · 어느 날에도 지난 종료 경기가 얼굴로 올라오지 않는다', () {
      final dates = schedule.games.map((g) => g.date).toSet().toList()..sort();

      for (final teamId in kTeamIds) {
        for (final date in dates) {
          // 그날 KST 정오.
          final now = DateTime.parse('${date}T03:00:00Z');
          final today = kstDateOf(now);
          final next = findNextAwayGame(
            schedule: schedule,
            teamId: teamId,
            now: now,
          );
          switch (next) {
            case AwayGameToday(:final game):
              expect(gameDateOf(game), today, reason: '$teamId/$date');
              expect(game.awayTeamId, teamId);
            case AwayGameUpcoming(:final game, :final dDay):
              expect(dDay, greaterThanOrEqualTo(1), reason: '$teamId/$date');
              expect(
                game.status,
                GameStatus.scheduled,
                reason: '미래 후보는 예정 경기뿐이다 ($teamId/$date)',
              );
              expect(gameDateOf(game).isAfter(today), isTrue);
            case NoUpcomingAwayGame():
              break;
          }
        }
      }
    });

    test('오늘 끝난 원정 경기는 그날 자정까지 얼굴에 남는다 (실물 종료 경기로)', () {
      final finished = schedule.games.firstWhere(
        (g) => g.status == GameStatus.finished,
      );
      // 그날 23:59 KST = 14:59Z.
      final lateNight = DateTime.parse('${finished.date}T14:59:00Z');
      final next = findNextAwayGame(
        schedule: schedule,
        teamId: finished.awayTeamId,
        now: lateNight,
      );
      expect(next, isA<AwayGameToday>());
      expect(gameDateOf((next as AwayGameToday).game).toIso8601String(),
          gameDateOf(finished).toIso8601String());

      // 다음 날 00:01 KST 로 넘어가면 더 이상 후보가 아니다.
      final nextDay = DateTime.parse('${finished.date}T15:01:00Z');
      final after = findNextAwayGame(
        schedule: schedule,
        teamId: finished.awayTeamId,
        now: nextDay,
      );
      if (after is AwayGameToday) {
        expect(gameDateOf(after.game), isNot(gameDateOf(finished)));
      }
    });
  });
}
