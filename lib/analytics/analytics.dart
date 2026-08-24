/// 분석 래퍼 — 앱의 모든 분석 호출은 이 파일 하나를 통과한다.
///
/// - `firebase_analytics`/`firebase_core` import 는 이 파일 밖에 두지 않는다.
/// - 이벤트 이름·파라미터 키는 아래 화이트리스트로 제한한다
///   (성공 지표: 추천 탭 → 지도 진입, 개인 식별 정보 없음).
/// - Firebase 미초기화(설정 파일 없음 포함) 상태에서는 조용히 no-op 한다.
library;

import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 허용된 이벤트 이름 로스터 — 여기 없는 이름은 전송을 거부한다.
const Set<String> kAllowedAnalyticsEvents = {'place_tap', 'map_open'};

/// 허용된 이벤트 파라미터 키 — 구장 id·카테고리만 (개인 식별 정보 금지).
const Set<String> kAllowedAnalyticsParamKeys = {'stadium_id', 'category'};

/// 분석 클라이언트 — 검증(화이트리스트)은 이 베이스의 [log] 한 경로에서만
/// 수행되고, 실제 전송은 [send] 구현이 맡는다 (테스트는 기록용 fake 로 대체).
abstract class AnalyticsClient {
  /// 추천 장소 카드 탭 (성공 지표의 앞단).
  void logPlaceTap({required String stadiumId, required String category}) {
    log('place_tap', {'stadium_id': stadiumId, 'category': category});
  }

  /// 앱 내 지도 화면 진입 (성공 지표: 추천 탭 → 지도 진입).
  void logMapOpen({required String stadiumId, required String category}) {
    log('map_open', {'stadium_id': stadiumId, 'category': category});
  }

  /// 단일 검증 경로 — 이벤트 이름·파라미터 키가 화이트리스트를 벗어나면
  /// [ArgumentError] 를 던져 전송 자체를 차단한다.
  void log(String name, Map<String, Object> params) {
    if (!kAllowedAnalyticsEvents.contains(name)) {
      throw ArgumentError.value(name, 'name', '허용되지 않은 분석 이벤트');
    }
    final disallowed = params.keys
        .where((key) => !kAllowedAnalyticsParamKeys.contains(key))
        .toList();
    if (disallowed.isNotEmpty) {
      throw ArgumentError.value(
        disallowed.join(', '),
        'params',
        '허용되지 않은 분석 파라미터 키',
      );
    }
    send(name, params);
  }

  /// 검증을 통과한 이벤트의 실제 전송 — [log] 를 통해서만 호출된다.
  @protected
  void send(String name, Map<String, Object> params);
}

/// Firebase Analytics 백엔드 구현.
///
/// [ensureInitialized] 가 성공했을 때만 이벤트를 전송하고,
/// 그 외(설정 파일 없음·초기화 실패·미호출)에는 이벤트를 조용히 버린다 —
/// Firebase 미초기화 상태에서 분석 호출이 앱을 죽이지 않게 하는 장치.
class FirebaseAnalyticsClient extends AnalyticsClient {
  FirebaseAnalyticsClient._();

  /// 앱 전역 단일 인스턴스.
  static final FirebaseAnalyticsClient instance = FirebaseAnalyticsClient._();

  FirebaseAnalytics? _backend;

  /// main 에서 1회 호출한다. Firebase 설정(google-services.json /
  /// GoogleService-Info.plist)이 없거나 초기화가 실패하면 예외를 삼키고
  /// no-op 모드로 남는다 — 설정 없이도 빌드·실행이 계속된다.
  Future<void> ensureInitialized() async {
    try {
      await Firebase.initializeApp();
      _backend = FirebaseAnalytics.instance;
    } catch (_) {
      _backend = null;
    }
  }

  @override
  void send(String name, Map<String, Object> params) {
    final backend = _backend;
    if (backend == null) return; // no-op 모드.
    // fire-and-forget — 전송 실패가 UI 흐름을 막지 않게 한다.
    unawaited(
      backend
          .logEvent(name: name, parameters: params)
          .catchError((Object _) {}),
    );
  }
}

/// 화면이 소비하는 분석 클라이언트 — 테스트는 기록용 fake 로 override 한다.
final analyticsProvider = Provider<AnalyticsClient>(
  (ref) => FirebaseAnalyticsClient.instance,
);
