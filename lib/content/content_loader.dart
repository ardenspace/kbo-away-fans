/// 콘텐츠 로더 — 원격 JSON 4종을 받아 schemaVersion·계약을 검증하고
/// 로컬 캐시로 폴백한다.
///
/// 동작 계약 (step 2.1):
/// - 네트워크 우선: 매 로드마다 `$baseUrl/<kind>.json` 을 시도한다.
/// - 응답이 schemaVersion·계약 검증을 통과한 경우에만 캐시를 갱신한다.
/// - 실패(네트워크·미지원 schemaVersion·계약 위반)면 기존 캐시를 그대로
///   유지하고, 캐시가 있으면 캐시로 동작([ContentFromCache]),
///   없으면 명시적 에러 상태([ContentUnavailable])를 돌려준다.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'content_cache.dart';
import 'content_config.dart';
import 'models.dart';

/// 원격으로 배포되는 콘텐츠 문서 4종.
enum ContentKind {
  teams('teams.json', kTeamsSchemaVersion),
  stadiums('stadiums.json', kStadiumsSchemaVersion),
  places('places.json', kPlacesSchemaVersion),
  schedule('schedule.json', kScheduleSchemaVersion);

  const ContentKind(this.fileName, this.supportedSchemaVersion);

  /// 배포 원점(base URL) 아래의 파일 이름.
  final String fileName;

  /// 이 문서에서 앱이 이해하는 계약 버전 (`content_config.dart`).
  final int supportedSchemaVersion;
}

/// 원격 문서의 schemaVersion 이 앱이 지원하는 버전과 다름.
///
/// 로더는 갱신을 거부하고 기존 캐시를 유지한다.
class UnsupportedSchemaVersion implements Exception {
  UnsupportedSchemaVersion({required this.expected, required this.found});

  /// 앱이 이해하는 값 (문서마다 다르다).
  final int expected;

  /// 원격 문서가 선언한 값 (없으면 null).
  final Object? found;

  @override
  String toString() => 'UnsupportedSchemaVersion: 지원 $expected, 수신 $found';
}

/// 신선한 로드가 실패한 이유의 분류.
enum ContentIssueKind {
  /// 요청 실패·비 200 응답 등 네트워크 계층 문제.
  network,

  /// schemaVersion 불일치 — 갱신 거부.
  unsupportedSchemaVersion,

  /// JSON 파싱 실패 또는 계약(모델 검증) 위반 — 갱신 거부.
  contractViolation,
}

/// 신선한 로드가 실패한 이유.
class ContentIssue {
  const ContentIssue(this.kind, this.message);

  final ContentIssueKind kind;

  /// 사람이 읽는 진단 메시지.
  final String message;

  @override
  String toString() => 'ContentIssue(${kind.name}): $message';
}

/// 문서 하나의 로드 결과.
sealed class ContentResult<T> {
  const ContentResult();
}

/// 원격에서 받은 신선한 문서 (검증 통과, 캐시 갱신됨).
final class ContentFresh<T> extends ContentResult<T> {
  const ContentFresh(this.data);

  final T data;
}

/// 신선한 로드는 실패했지만 캐시로 동작 중.
final class ContentFromCache<T> extends ContentResult<T> {
  const ContentFromCache(this.data, this.issue);

  final T data;

  /// 신선한 로드가 실패한 이유 (schemaVersion 거부 관찰용).
  final ContentIssue issue;
}

/// 캐시조차 없어 문서를 제공할 수 없음 — 명시적 에러 상태.
final class ContentUnavailable<T> extends ContentResult<T> {
  const ContentUnavailable(this.issue);

  final ContentIssue issue;
}

/// 4종 문서를 한 번에 로드한 결과 묶음.
class ContentBundle {
  const ContentBundle({
    required this.teams,
    required this.stadiums,
    required this.places,
    required this.schedule,
  });

  final ContentResult<TeamsDocument> teams;
  final ContentResult<StadiumsDocument> stadiums;
  final ContentResult<PlacesDocument> places;
  final ContentResult<ScheduleDocument> schedule;
}

typedef _DocumentParser<T> = T Function(Map<String, Object?> json);

/// 원격 JSON 4종의 로더. 소스는 [kContentBaseUrl] 상수 하나로 바뀐다.
class ContentLoader {
  ContentLoader({
    required this.client,
    required this.cache,
    this.baseUrl = kContentBaseUrl,
  });

  final http.Client client;
  final ContentCache cache;

  /// 콘텐츠 배포 원점 — 기본값은 [kContentBaseUrl] 상수 하나.
  final String baseUrl;

  Future<ContentResult<TeamsDocument>> loadTeams() =>
      _load(ContentKind.teams, TeamsDocument.fromJson);

  Future<ContentResult<StadiumsDocument>> loadStadiums() =>
      _load(ContentKind.stadiums, StadiumsDocument.fromJson);

  Future<ContentResult<PlacesDocument>> loadPlaces() =>
      _load(ContentKind.places, PlacesDocument.fromJson);

  Future<ContentResult<ScheduleDocument>> loadSchedule() =>
      _load(ContentKind.schedule, ScheduleDocument.fromJson);

  /// 4종을 병렬 로드한다. 문서별로 독립적으로 성공/폴백/에러가 결정된다.
  Future<ContentBundle> loadAll() async {
    final (teams, stadiums, places, schedule) = await (
      loadTeams(),
      loadStadiums(),
      loadPlaces(),
      loadSchedule(),
    ).wait;
    return ContentBundle(
      teams: teams,
      stadiums: stadiums,
      places: places,
      schedule: schedule,
    );
  }

  Future<ContentResult<T>> _load<T>(
    ContentKind kind,
    _DocumentParser<T> parse,
  ) async {
    // 신선한 로드가 실패한 이유 — 폴백 지점에 도달할 때는 항상 채워져 있다.
    ContentIssue? issue;

    String? body;
    try {
      // 타임아웃 없이는 실기기 첫 로드가 무기한 대기할 수 있다 —
      // TimeoutException 은 아래 `on Exception` 이 network issue 로 분류한다.
      final response = await client
          .get(Uri.parse('$baseUrl/${kind.fileName}'))
          .timeout(kContentFetchTimeout);
      if (response.statusCode == 200) {
        body = utf8.decode(response.bodyBytes);
      } else {
        issue = ContentIssue(
          ContentIssueKind.network,
          '${kind.fileName}: HTTP ${response.statusCode}',
        );
      }
    } on Exception catch (error) {
      issue = ContentIssue(
        ContentIssueKind.network,
        '${kind.fileName}: $error',
      );
    }

    if (body != null) {
      try {
        final data = _parseDocument(kind, body, parse);
        await cache.write(kind, body);
        return ContentFresh<T>(data);
      } on UnsupportedSchemaVersion catch (error) {
        issue = ContentIssue(
          ContentIssueKind.unsupportedSchemaVersion,
          '${kind.fileName}: $error',
        );
      } on ContentContractViolation catch (error) {
        issue = ContentIssue(
          ContentIssueKind.contractViolation,
          '${kind.fileName}: ${error.message}',
        );
      } on FormatException catch (error) {
        issue = ContentIssue(
          ContentIssueKind.contractViolation,
          '${kind.fileName}: JSON 아님 — ${error.message}',
        );
      }
    }

    // 신선한 로드 실패 — 기존 캐시는 건드리지 않고 폴백만 시도한다.
    final fallbackIssue = issue!;
    final cached = await cache.read(kind);
    if (cached != null) {
      try {
        return ContentFromCache<T>(
          _parseDocument(kind, cached, parse),
          fallbackIssue,
        );
      } on Exception {
        // 캐시가 깨졌으면(버전 포함) 신선한 로드 실패 사유로 에러 상태.
      }
    }
    return ContentUnavailable<T>(fallbackIssue);
  }

  T _parseDocument<T>(ContentKind kind, String body, _DocumentParser<T> parse) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw ContentContractViolation('문서 루트가 객체가 아님');
    }
    final version = decoded['schemaVersion'];
    if (version != kind.supportedSchemaVersion) {
      throw UnsupportedSchemaVersion(
        expected: kind.supportedSchemaVersion,
        found: version,
      );
    }
    return parse(decoded);
  }
}
