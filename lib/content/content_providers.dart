/// 콘텐츠 계층의 Riverpod wiring — feature 들은 이 provider 로 로더를 얻는다.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'content_cache.dart';
import 'content_loader.dart';

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
