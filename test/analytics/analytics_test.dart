/// Step 3.4 분석 래퍼 단위 테스트 — 이벤트 헬퍼가 화이트리스트 안의
/// 이름·파라미터만 전송하고, 허용 키 밖의 전송 시도는 [ArgumentError] 로
/// 차단되는지(전송 자체가 없는지) 검증한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/analytics/analytics.dart';

import 'recording_analytics.dart';

void main() {
  late RecordingAnalytics analytics;

  setUp(() {
    analytics = RecordingAnalytics();
  });

  test('logPlaceTap 은 place_tap 1회 — 파라미터는 구장 id·카테고리뿐', () {
    analytics.logPlaceTap(stadiumId: 'jamsil', category: 'food');

    expect(analytics.events, hasLength(1));
    expect(analytics.events.single.name, 'place_tap');
    expect(
      analytics.events.single.params,
      {'stadium_id': 'jamsil', 'category': 'food'},
    );
  });

  test('logMapOpen 은 map_open 1회 — 파라미터는 구장 id·카테고리뿐', () {
    analytics.logMapOpen(stadiumId: 'sajik', category: 'cafe');

    expect(analytics.events, hasLength(1));
    expect(analytics.events.single.name, 'map_open');
    expect(
      analytics.events.single.params,
      {'stadium_id': 'sajik', 'category': 'cafe'},
    );
  });

  test('허용 키 밖의 파라미터 전송 시도는 ArgumentError — 전송이 일어나지 않는다',
      () {
    expect(
      () => analytics.log('place_tap', {
        'stadium_id': 'jamsil',
        'user_id': 'someone', // 개인 식별 후보 키 — 화이트리스트 밖.
      }),
      throwsArgumentError,
    );
    expect(analytics.events, isEmpty);
  });

  test('허용 로스터 밖의 이벤트 이름도 ArgumentError — 전송이 일어나지 않는다',
      () {
    expect(
      () => analytics.log('screen_view', {'stadium_id': 'jamsil'}),
      throwsArgumentError,
    );
    expect(analytics.events, isEmpty);
  });

  test('헬퍼가 만드는 파라미터 키는 전부 화이트리스트 안이다', () {
    analytics.logPlaceTap(stadiumId: 'jamsil', category: 'food');
    analytics.logMapOpen(stadiumId: 'jamsil', category: 'food');

    for (final event in analytics.events) {
      expect(kAllowedAnalyticsEvents, contains(event.name));
      for (final key in event.params.keys) {
        expect(kAllowedAnalyticsParamKeys, contains(key));
      }
    }
  });

  test('미초기화 FirebaseAnalyticsClient 의 이벤트 호출은 조용히 no-op 한다', () {
    // ensureInitialized 를 호출하지 않은(또는 실패한) 상태 —
    // 백엔드가 없어도 예외 없이 넘어가야 앱이 죽지 않는다.
    expect(
      () => FirebaseAnalyticsClient.instance
          .logPlaceTap(stadiumId: 'jamsil', category: 'food'),
      returnsNormally,
    );
  });
}
