/// 날씨 래퍼 — 앱의 모든 날씨 호출은 이 파일 하나를 통과한다.
///
/// - OpenWeatherMap 의존(호스트·경로·응답 파싱·API 키)은 이 파일 밖에
///   두지 않는다 (얇은 래퍼 뒤 격리 — 소스 교체는 여기 내부만 바꾼다).
/// - API 키는 `--dart-define=OPENWEATHER_API_KEY` 로 주입한다.
/// - 모든 실패(키 미주입·네트워크·비 200·파싱 실패)는 [WeatherEffect.none]
///   ("연출 없음")으로 흡수한다 — 예외를 전파하지 않으므로 날씨가 죽어도
///   여정(홈·추천)은 정상 동작한다.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../content/content_providers.dart' show httpClientProvider;

/// 배경 연출 상태 — 날씨 계층이 화면에 넘기는 유일한 어휘.
enum WeatherEffect {
  /// 연출 없음 (맑음/흐림/실패 전부 여기로).
  none,

  /// 비 연출 (WeatherBackdrop 빗줄기 → 플랜B 유도).
  rain,
}

/// OpenWeatherMap current weather 래퍼.
class WeatherService {
  WeatherService({required this.client, required this.apiKey});

  final http.Client client;

  /// OpenWeatherMap API 키 — 비어 있으면 호출 없이 [WeatherEffect.none].
  final String apiKey;

  static const String _host = 'api.openweathermap.org';
  static const String _path = '/data/2.5/weather';

  /// 좌표의 현재 날씨를 연출 상태로 요약한다. 어떤 실패에도 예외를
  /// 던지지 않고 [WeatherEffect.none] 을 돌려준다.
  Future<WeatherEffect> effectAt({
    required double lat,
    required double lng,
  }) async {
    if (apiKey.isEmpty) return WeatherEffect.none;
    try {
      final response = await client.get(
        Uri.https(_host, _path, {
          'lat': '$lat',
          'lon': '$lng',
          'appid': apiKey,
        }),
      );
      if (response.statusCode != 200) return WeatherEffect.none;
      return parseWeatherEffect(utf8.decode(response.bodyBytes));
    } catch (_) {
      return WeatherEffect.none;
    }
  }
}

/// OpenWeatherMap current weather 응답 본문 → 연출 상태.
///
/// condition id 2xx(뇌우)·3xx(이슬비)·5xx(비)를 비로 본다.
/// 파싱 실패·미지 구조는 [WeatherEffect.none] ("연출 없음").
WeatherEffect parseWeatherEffect(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return WeatherEffect.none;
  }
  if (decoded is! Map<String, Object?>) return WeatherEffect.none;
  final conditions = decoded['weather'];
  if (conditions is! List<Object?>) return WeatherEffect.none;
  for (final condition in conditions) {
    if (condition is! Map<String, Object?>) continue;
    final id = condition['id'];
    if (id is! int) continue;
    final rainy = (id >= 200 && id < 400) || (id >= 500 && id < 600);
    if (rainy) return WeatherEffect.rain;
  }
  return WeatherEffect.none;
}

/// 날씨 좌표 키 — record 라 값 동등성으로 provider family 키가 된다.
typedef WeatherPoint = ({double lat, double lng});

/// 화면이 소비하는 날씨 서비스 — 테스트는 override 로 갈아끼운다.
final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(
    client: ref.watch(httpClientProvider),
    apiKey: const String.fromEnvironment('OPENWEATHER_API_KEY'),
  ),
);

/// 좌표별 연출 상태 — 앱 세션 동안 좌표당 1회 조회하고 캐시한다
/// (연출 용도라 실시간성 요구가 낮음; 강제 갱신은 invalidate).
final weatherEffectProvider =
    FutureProvider.family<WeatherEffect, WeatherPoint>(
  (ref, point) =>
      ref.watch(weatherServiceProvider).effectAt(lat: point.lat, lng: point.lng),
);

/// [weatherEffectProvider] 결과 평탄화 — 로딩·실패는 전부 "연출 없음".
WeatherEffect weatherEffectOf(AsyncValue<WeatherEffect> async) =>
    switch (async) {
      AsyncData(:final value) => value,
      _ => WeatherEffect.none,
    };
