/// 콘텐츠 계층의 Riverpod wiring — feature 들은 이 provider 로 로더를 얻는다.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'content_cache.dart';
import 'content_loader.dart';
import 'models.dart';

/// 앱 전역 HTTP 클라이언트 (테스트에서는 override 로 mock 주입).
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// 앱 지원 디렉터리 아래 `content_cache/` 를 쓰는 캐시.
final contentCacheProvider = FutureProvider<ContentCache>((ref) async {
  final supportDir = await getApplicationSupportDirectory();
  return ContentCache(
    Directory('${supportDir.path}${Platform.pathSeparator}content_cache'),
  );
});

/// 콘텐츠 로더 — 소스는 `content_config.dart` 의 URL 상수 하나로 바뀐다.
final contentLoaderProvider = FutureProvider<ContentLoader>((ref) async {
  final cache = await ref.watch(contentCacheProvider.future);
  return ContentLoader(client: ref.watch(httpClientProvider), cache: cache);
});

/// teams.json 로드 결과 — 온보딩·홈의 팀 목록/테마 포인터(themeKey)가
/// 여기서 온다. 실패 시 [ContentUnavailable] 이 그대로 노출되며,
/// 소비 화면이 재시도(ref.invalidate)를 제공한다.
final teamsProvider = FutureProvider<ContentResult<TeamsDocument>>((ref) async {
  final loader = await ref.watch(contentLoaderProvider.future);
  return loader.loadTeams();
});

/// stadiums.json 로드 결과 — 경기 라벨의 구장 이름·구장 맥락이 여기서 온다.
final stadiumsProvider =
    FutureProvider<ContentResult<StadiumsDocument>>((ref) async {
  final loader = await ref.watch(contentLoaderProvider.future);
  return loader.loadStadiums();
});

/// places.json 로드 결과 — 원정 미리보기·추천 목록이 여기서 온다.
final placesProvider =
    FutureProvider<ContentResult<PlacesDocument>>((ref) async {
  final loader = await ref.watch(contentLoaderProvider.future);
  return loader.loadPlaces();
});

/// schedule.json 로드 결과 — 홈의 다음 원정 경기 계산이 여기서 온다.
/// 실패 시 [ContentUnavailable] 이 그대로 노출되며, 소비 화면이
/// 재시도(ref.invalidate)를 제공한다.
final scheduleProvider =
    FutureProvider<ContentResult<ScheduleDocument>>((ref) async {
  final loader = await ref.watch(contentLoaderProvider.future);
  return loader.loadSchedule();
});

/// [ContentResult] 를 문서로 평탄화 — fresh/캐시는 데이터, 그 외 null.
///
/// 소비 화면들이 같은 규칙으로 "문서를 얻었는가"를 판정하는 단일 지점.
T? contentDataOf<T>(AsyncValue<ContentResult<T>> async) => switch (async) {
      AsyncData(:final value) => switch (value) {
          ContentFresh(:final data) || ContentFromCache(:final data) => data,
          ContentUnavailable() => null,
        },
      _ => null,
    };

/// 콘텐츠 provider 4종을 한꺼번에 무효화 — "다시 시도"의 단일 경로.
///
/// 문서별로 골라 invalidate 하면 부분 복구 시 나머지가 실패값으로 남아
/// 화면이 raw id 로 저하 렌더되는 비일관성이 생긴다. 재시도는 항상 4종을
/// 함께 다시 로드한다 (성공해 있던 문서는 재검증 후 그대로 fresh).
void invalidateContent(WidgetRef ref) {
  ref
    ..invalidate(teamsProvider)
    ..invalidate(stadiumsProvider)
    ..invalidate(placesProvider)
    ..invalidate(scheduleProvider);
}
