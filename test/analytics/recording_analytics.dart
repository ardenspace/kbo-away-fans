import 'package:kbo_away_fans/analytics/analytics.dart';

/// 전송된 분석 이벤트 1건의 기록.
class RecordedEvent {
  RecordedEvent(this.name, this.params);

  final String name;
  final Map<String, Object> params;
}

/// 기록용 mock 래퍼 — 검증([AnalyticsClient.log])은 실물 경로를 그대로 타고,
/// 전송([send])만 리스트 축적으로 대체한다.
class RecordingAnalytics extends AnalyticsClient {
  final List<RecordedEvent> events = [];

  /// [name] 이벤트가 기록된 횟수.
  int countOf(String name) => events.where((e) => e.name == name).length;

  @override
  void send(String name, Map<String, Object> params) {
    events.add(RecordedEvent(name, params));
  }
}
