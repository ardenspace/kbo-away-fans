/// Step 5.3 boundary test — 실호스팅 URL 대상 로더 통합 테스트.
///
/// 평상시 `flutter test` 에서는 네트워크를 건드리지 않도록 skip 되고,
/// `--dart-define=CONTENT_LIVE_TEST=true` 를 줄 때만 실제 HTTP 로 4종
/// 문서를 로드한다. 대상 URL 은 [kContentBaseUrl] — CI/로컬에서는
/// `--dart-define=CONTENT_BASE_URL=http://127.0.0.1:8787` 등으로
/// 스테이징·로컬 서버를 겨눌 수 있다.
///
/// 실행 예 (실호스팅):
/// ```sh
/// flutter test test/content/content_loader_live_test.dart \
///   --dart-define=CONTENT_LIVE_TEST=true
/// ```
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kbo_away_fans/content/content_cache.dart';
import 'package:kbo_away_fans/content/content_config.dart';
import 'package:kbo_away_fans/content/content_loader.dart';

const bool _liveEnabled = bool.fromEnvironment('CONTENT_LIVE_TEST');

void main() {
  test(
    '실 URL($kContentBaseUrl)에서 4종 문서가 전부 신선하게 로드된다',
    () async {
      final client = http.Client();
      final tempDir = await Directory.systemTemp.createTemp('content-live-');
      addTearDown(() async {
        client.close();
        await tempDir.delete(recursive: true);
      });

      final loader = ContentLoader(
        client: client,
        cache: ContentCache(tempDir),
      );
      final bundle = await loader.loadAll();

      // 4종 전부 ContentFresh — 원격 응답이 schemaVersion·계약 검증을
      // 통과해 캐시까지 갱신됐다는 뜻이다.
      expect(bundle.teams, isA<ContentFresh<Object?>>(), reason: '${bundle.teams}');
      expect(
        bundle.stadiums,
        isA<ContentFresh<Object?>>(),
        reason: '${bundle.stadiums}',
      );
      expect(
        bundle.places,
        isA<ContentFresh<Object?>>(),
        reason: '${bundle.places}',
      );
      expect(
        bundle.schedule,
        isA<ContentFresh<Object?>>(),
        reason: '${bundle.schedule}',
      );

      // 캐시 파일 4종이 실제로 기록됐는지 (실기기 오프라인 폴백의 전제).
      for (final kind in ContentKind.values) {
        final cached = await ContentCache(tempDir).read(kind);
        expect(cached, isNotNull, reason: '${kind.fileName} 캐시 없음');
      }
    },
    skip: _liveEnabled
        ? false
        : 'CONTENT_LIVE_TEST dart-define 없음 — 네트워크 통합 테스트는 명시 실행 전용',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
