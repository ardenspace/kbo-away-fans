/// Step 2.1 boundary tests — 콘텐츠 로더 단위 테스트.
///
/// 정상 샘플은 저장소의 `content-pipeline/data/*.json` (계약 검증을 통과한
/// 산출물)을 그대로 사용해 파이프라인 ↔ 앱 간 계약 드리프트를 잡는다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kbo_away_fans/content/content_cache.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/models.dart';

const _baseUrl = 'http://content.test';

String _sample(ContentKind kind) =>
    File('content-pipeline/data/${kind.fileName}').readAsStringSync();

/// 샘플 JSON 을 부분 수정한 본문을 만든다.
String _mutate(String body, void Function(Map<String, Object?> root) edit) {
  final root = jsonDecode(body) as Map<String, Object?>;
  edit(root);
  return jsonEncode(root);
}

MockClient _serving(Map<String, String> bodies) {
  return MockClient((request) async {
    final body = bodies[request.url.pathSegments.last];
    if (body == null) return http.Response('not found', 404);
    return http.Response.bytes(utf8.encode(body), 200);
  });
}

MockClient _httpError(int statusCode) =>
    MockClient((_) async => http.Response('error', statusCode));

MockClient _offline() =>
    MockClient((_) async => throw http.ClientException('connection refused'));

void main() {
  late Directory tempDir;
  late ContentCache cache;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('content_loader_test');
    cache = ContentCache(tempDir);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  ContentLoader loaderWith(http.Client client) =>
      ContentLoader(client: client, cache: cache, baseUrl: _baseUrl);

  File cacheFile(ContentKind kind) =>
      File('${tempDir.path}/${kind.fileName}');

  group('정상 응답 파싱', () {
    test('4종 문서를 파싱하고 캐시에 기록한다', () async {
      final loader = loaderWith(
        _serving({
          for (final kind in ContentKind.values) kind.fileName: _sample(kind),
        }),
      );

      final bundle = await loader.loadAll();

      final teams = bundle.teams;
      expect(teams, isA<ContentFresh<TeamsDocument>>());
      teams as ContentFresh<TeamsDocument>;
      expect(teams.data.teams, hasLength(10));
      expect(teams.data.byId('lg')?.name, 'LG 트윈스');
      // themeKey 는 파싱을 통과했으면 테마 조회가 항상 성공한다 (이음새 계약).
      for (final team in teams.data.teams) {
        expect(team.theme, isNotNull);
      }

      final stadiums = bundle.stadiums;
      expect(stadiums, isA<ContentFresh<StadiumsDocument>>());
      stadiums as ContentFresh<StadiumsDocument>;
      expect(stadiums.data.stadiums, hasLength(9));
      expect(stadiums.data.byId('jamsil')?.homeTeams, ['lg', 'doosan']);

      final places = bundle.places;
      expect(places, isA<ContentFresh<PlacesDocument>>());
      places as ContentFresh<PlacesDocument>;
      expect(places.data.places, isNotEmpty);
      expect(
        places.data.places.every((p) => p.source == 'curated'),
        isTrue,
      );

      final schedule = bundle.schedule;
      expect(schedule, isA<ContentFresh<ScheduleDocument>>());
      schedule as ContentFresh<ScheduleDocument>;
      expect(schedule.data.games, isNotEmpty);
      expect(schedule.data.games.first.status, GameStatus.scheduled);
      // 점수 없는 예정 경기도 그대로 읽힌다 (세 필드는 null).
      expect(schedule.data.games.first.homeScore, isNull);
      expect(schedule.data.games.first.awayScore, isNull);
      expect(schedule.data.games.first.result, isNull);

      // 검증 통과본이 캐시에 기록됐다.
      for (final kind in ContentKind.values) {
        expect(cacheFile(kind).existsSync(), isTrue, reason: kind.fileName);
        expect(cacheFile(kind).readAsStringSync(), _sample(kind));
      }
    });
  });

  group('HTTP 실패 시 캐시 폴백', () {
    test('5xx 응답이면 캐시된 문서로 동작한다', () async {
      await cache.write(ContentKind.teams, _sample(ContentKind.teams));
      final loader = loaderWith(_httpError(500));

      final result = await loader.loadTeams();

      expect(result, isA<ContentFromCache<TeamsDocument>>());
      result as ContentFromCache<TeamsDocument>;
      expect(result.data.teams, hasLength(10));
      expect(result.issue.kind, ContentIssueKind.network);
    });

    test('네트워크 예외(오프라인)에서도 캐시로 동작한다', () async {
      await cache.write(ContentKind.schedule, _sample(ContentKind.schedule));
      final loader = loaderWith(_offline());

      final result = await loader.loadSchedule();

      expect(result, isA<ContentFromCache<ScheduleDocument>>());
      result as ContentFromCache<ScheduleDocument>;
      expect(result.data.games, isNotEmpty);
      expect(result.issue.kind, ContentIssueKind.network);
    });
  });

  group('캐시 없음 + 실패', () {
    test('명시적 에러 상태(ContentUnavailable)를 돌려준다', () async {
      final loader = loaderWith(_offline());

      final result = await loader.loadPlaces();

      expect(result, isA<ContentUnavailable<PlacesDocument>>());
      result as ContentUnavailable<PlacesDocument>;
      expect(result.issue.kind, ContentIssueKind.network);
    });
  });

  group('schedule schemaVersion 2 — 종료 경기의 점수·승패', () {
    /// 샘플의 첫 경기를 종료 경기로 바꾼 본문.
    String finishedSample({
      required int homeScore,
      required int awayScore,
      required String result,
    }) {
      return _mutate(_sample(ContentKind.schedule), (root) {
        ((root['games']! as List<Object?>).first! as Map<String, Object?>)
          ..['status'] = 'finished'
          ..['homeScore'] = homeScore
          ..['awayScore'] = awayScore
          ..['result'] = result;
      });
    }

    test('종료 경기의 점수와 승패를 읽는다', () async {
      final loader = loaderWith(
        _serving({
          'schedule.json': finishedSample(
            homeScore: 7,
            awayScore: 3,
            result: 'home_win',
          ),
        }),
      );

      final result = await loader.loadSchedule();

      expect(result, isA<ContentFresh<ScheduleDocument>>());
      result as ContentFresh<ScheduleDocument>;
      final game = result.data.games.first;
      expect(game.status, GameStatus.finished);
      expect(game.homeScore, 7);
      expect(game.awayScore, 3);
      expect(game.result, GameResult.homeWin);
      // 나머지 경기는 점수 없는 예정 경기 그대로다.
      expect(result.data.games.last.status, GameStatus.scheduled);
      expect(result.data.games.last.homeScore, isNull);
    });

    test('무승부도 읽는다 (점수 비교만으로는 안 갈리는 값)', () async {
      final loader = loaderWith(
        _serving({
          'schedule.json': finishedSample(
            homeScore: 5,
            awayScore: 5,
            result: 'draw',
          ),
        }),
      );

      final result = await loader.loadSchedule();

      expect(result, isA<ContentFresh<ScheduleDocument>>());
      result as ContentFresh<ScheduleDocument>;
      expect(result.data.games.first.result, GameResult.draw);
    });

    test('schemaVersion 1 문서는 거부한다 (schedule 은 2를 요구)', () async {
      final v1Body = _mutate(
        _sample(ContentKind.schedule),
        (root) => root['schemaVersion'] = 1,
      );
      final loader = loaderWith(_serving({'schedule.json': v1Body}));

      final result = await loader.loadSchedule();

      expect(result, isA<ContentUnavailable<ScheduleDocument>>());
      result as ContentUnavailable<ScheduleDocument>;
      expect(result.issue.kind, ContentIssueKind.unsupportedSchemaVersion);
    });

    test('teams 는 1을 그대로 요구한다 (문서마다 버전이 따로다)', () async {
      final v2Body = _mutate(
        _sample(ContentKind.teams),
        (root) => root['schemaVersion'] = 2,
      );
      final loader = loaderWith(_serving({'teams.json': v2Body}));

      final result = await loader.loadTeams();

      expect(result, isA<ContentUnavailable<TeamsDocument>>());
      result as ContentUnavailable<TeamsDocument>;
      expect(result.issue.kind, ContentIssueKind.unsupportedSchemaVersion);
    });
  });

  group('schemaVersion 불일치', () {
    test('갱신을 거부하고 기존 캐시를 유지한다', () async {
      final cachedBody = _sample(ContentKind.teams);
      await cache.write(ContentKind.teams, cachedBody);
      final v2Body = _mutate(
        cachedBody,
        (root) => root['schemaVersion'] = 2,
      );
      final loader = loaderWith(_serving({'teams.json': v2Body}));

      final result = await loader.loadTeams();

      // 갱신 거부가 관찰된다: 결과는 캐시본 + 거부 사유.
      expect(result, isA<ContentFromCache<TeamsDocument>>());
      result as ContentFromCache<TeamsDocument>;
      expect(result.issue.kind, ContentIssueKind.unsupportedSchemaVersion);
      // 캐시 파일이 v2 본문으로 덮이지 않았다.
      expect(cacheFile(ContentKind.teams).readAsStringSync(), cachedBody);
    });

    test('캐시가 없으면 에러 상태로 끝난다 (미검증 데이터 미사용)', () async {
      final v2Body = _mutate(
        _sample(ContentKind.teams),
        (root) => root['schemaVersion'] = 2,
      );
      final loader = loaderWith(_serving({'teams.json': v2Body}));

      final result = await loader.loadTeams();

      expect(result, isA<ContentUnavailable<TeamsDocument>>());
      result as ContentUnavailable<TeamsDocument>;
      expect(result.issue.kind, ContentIssueKind.unsupportedSchemaVersion);
      expect(cacheFile(ContentKind.teams).existsSync(), isFalse);
    });
  });

  group('계약 위반 JSON 거부', () {
    Map<String, Object?> firstOf(Map<String, Object?> root, String field) =>
        (root[field]! as List<Object?>).first! as Map<String, Object?>;

    test('필수 필드 누락 — 캐시 없으면 에러 상태', () async {
      final broken = _mutate(
        _sample(ContentKind.teams),
        (root) => firstOf(root, 'teams').remove('themeKey'),
      );
      final loader = loaderWith(_serving({'teams.json': broken}));

      final result = await loader.loadTeams();

      expect(result, isA<ContentUnavailable<TeamsDocument>>());
      result as ContentUnavailable<TeamsDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
      expect(cacheFile(ContentKind.teams).existsSync(), isFalse);
    });

    test('미지의 경기 상태 enum — 기존 캐시를 유지하고 캐시로 동작', () async {
      final cachedBody = _sample(ContentKind.schedule);
      await cache.write(ContentKind.schedule, cachedBody);
      final broken = _mutate(
        cachedBody,
        (root) => firstOf(root, 'games')['status'] = 'postponed',
      );
      final loader = loaderWith(_serving({'schedule.json': broken}));

      final result = await loader.loadSchedule();

      expect(result, isA<ContentFromCache<ScheduleDocument>>());
      result as ContentFromCache<ScheduleDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
      expect(cacheFile(ContentKind.schedule).readAsStringSync(), cachedBody);
    });

    test('places.source 가 curated 가 아니면 거부', () async {
      final broken = _mutate(
        _sample(ContentKind.places),
        (root) => firstOf(root, 'places')['source'] = 'ugc',
      );
      final loader = loaderWith(_serving({'places.json': broken}));

      final result = await loader.loadPlaces();

      expect(result, isA<ContentUnavailable<PlacesDocument>>());
      result as ContentUnavailable<PlacesDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
    });

    test('TeamThemes 에 없는 themeKey 는 거부 (미지 id 크래시 차단)', () async {
      final broken = _mutate(
        _sample(ContentKind.teams),
        (root) => firstOf(root, 'teams')['themeKey'] = 'no-such-team',
      );
      final loader = loaderWith(_serving({'teams.json': broken}));

      final result = await loader.loadTeams();

      expect(result, isA<ContentUnavailable<TeamsDocument>>());
      result as ContentUnavailable<TeamsDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
    });

    test('미지의 구장 id 는 거부', () async {
      final broken = _mutate(
        _sample(ContentKind.schedule),
        (root) => firstOf(root, 'games')['stadiumId'] = 'pohang',
      );
      final loader = loaderWith(_serving({'schedule.json': broken}));

      final result = await loader.loadSchedule();

      expect(result, isA<ContentUnavailable<ScheduleDocument>>());
      result as ContentUnavailable<ScheduleDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
    });

    test('종료 경기의 점수·승패가 어긋나면 거부', () async {
      final broken = _mutate(_sample(ContentKind.schedule), (root) {
        firstOf(root, 'games')
          ..['status'] = 'finished'
          ..['homeScore'] = 5
          ..['awayScore'] = 3
          ..['result'] = 'away_win';
      });
      final loader = loaderWith(_serving({'schedule.json': broken}));

      final result = await loader.loadSchedule();

      expect(result, isA<ContentUnavailable<ScheduleDocument>>());
      result as ContentUnavailable<ScheduleDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
    });

    test('종료 경기인데 점수가 없으면 거부', () async {
      final broken = _mutate(
        _sample(ContentKind.schedule),
        (root) => firstOf(root, 'games')['status'] = 'finished',
      );
      final loader = loaderWith(_serving({'schedule.json': broken}));

      final result = await loader.loadSchedule();

      expect(result, isA<ContentUnavailable<ScheduleDocument>>());
      result as ContentUnavailable<ScheduleDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
    });

    test('끝나지 않은 경기에 점수가 붙어 있으면 거부', () async {
      final broken = _mutate(
        _sample(ContentKind.schedule),
        (root) => firstOf(root, 'games')['homeScore'] = 3,
      );
      final loader = loaderWith(_serving({'schedule.json': broken}));

      final result = await loader.loadSchedule();

      expect(result, isA<ContentUnavailable<ScheduleDocument>>());
      result as ContentUnavailable<ScheduleDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
    });

    test('JSON 이 아닌 응답(HTML 등)은 거부', () async {
      final loader = loaderWith(
        _serving({'teams.json': '<html>captive portal</html>'}),
      );

      final result = await loader.loadTeams();

      expect(result, isA<ContentUnavailable<TeamsDocument>>());
      result as ContentUnavailable<TeamsDocument>;
      expect(result.issue.kind, ContentIssueKind.contractViolation);
    });
  });
}
