/// Step 4.1 날씨 래퍼 단위 테스트 — 응답 파싱과 "실패 시 연출 없음"
/// (예외 전파 금지) 계약을 boundary 로 확인한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kbo_away_fans/weather/weather.dart';

/// OWM current weather 응답 흉내 — condition id 목록만 계약이다.
String owmBody(List<int> conditionIds) {
  final items = conditionIds.map((id) => '{"id": $id, "main": "x"}').join(',');
  return '{"weather": [$items], "main": {"temp": 300.1}, "name": "Busan"}';
}

WeatherService service(MockClient client, {String apiKey = 'test-key'}) =>
    WeatherService(client: client, apiKey: apiKey);

Future<WeatherEffect> effect(WeatherService service) =>
    service.effectAt(lat: 35.194, lng: 129.061);

void main() {
  group('응답 파싱', () {
    test('비(5xx) condition 이면 rain', () async {
      final client = MockClient((_) async => http.Response(owmBody([501]), 200));
      expect(await effect(service(client)), WeatherEffect.rain);
    });

    test('뇌우(2xx)·이슬비(3xx)도 rain', () async {
      for (final id in [211, 302]) {
        final client =
            MockClient((_) async => http.Response(owmBody([id]), 200));
        expect(await effect(service(client)), WeatherEffect.rain,
            reason: 'condition id $id 는 비 연출이어야 한다');
      }
    });

    test('맑음(800)·구름(80x)·눈(6xx)은 연출 없음', () async {
      for (final id in [800, 803, 601]) {
        final client =
            MockClient((_) async => http.Response(owmBody([id]), 200));
        expect(await effect(service(client)), WeatherEffect.none,
            reason: 'condition id $id 는 연출 없음이어야 한다');
      }
    });

    test('복수 condition 중 하나라도 비면 rain', () async {
      final client =
          MockClient((_) async => http.Response(owmBody([701, 500]), 200));
      expect(await effect(service(client)), WeatherEffect.rain);
    });

    test('parseWeatherEffect: JSON 아님·미지 구조는 연출 없음', () {
      expect(parseWeatherEffect('not json'), WeatherEffect.none);
      expect(parseWeatherEffect('[1, 2]'), WeatherEffect.none);
      expect(parseWeatherEffect('{"weather": "oops"}'), WeatherEffect.none);
      expect(
        parseWeatherEffect('{"weather": [{"id": "wet"}]}'),
        WeatherEffect.none,
      );
    });
  });

  group('실패 시 "연출 없음" (예외 전파 금지)', () {
    test('HTTP 오류 응답(401/500)은 연출 없음', () async {
      for (final status in [401, 500]) {
        final client =
            MockClient((_) async => http.Response('denied', status));
        expect(await effect(service(client)), WeatherEffect.none);
      }
    });

    test('네트워크 예외는 삼켜지고 연출 없음', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('no network'),
      );
      await expectLater(effect(service(client)), completion(WeatherEffect.none));
    });

    test('200 인데 본문이 깨져 있어도 연출 없음', () async {
      final client = MockClient((_) async => http.Response('<html>', 200));
      expect(await effect(service(client)), WeatherEffect.none);
    });

    test('API 키 미주입이면 호출 자체를 하지 않고 연출 없음', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response(owmBody([501]), 200);
      });
      expect(await effect(service(client, apiKey: '')), WeatherEffect.none);
      expect(called, isFalse);
    });
  });

  test('요청은 OpenWeatherMap 을 좌표·키 쿼리로 가리킨다', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(owmBody([500]), 200);
    });
    await service(client).effectAt(lat: 35.194, lng: 129.061);

    expect(captured.url.host, 'api.openweathermap.org');
    expect(captured.url.path, '/data/2.5/weather');
    expect(captured.url.queryParameters['lat'], '35.194');
    expect(captured.url.queryParameters['lon'], '129.061');
    expect(captured.url.queryParameters['appid'], 'test-key');
  });
}
