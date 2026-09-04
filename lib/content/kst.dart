/// KST 달력 — `schedule.json` 의 `date`(YYYY-MM-DD)·`startTime`(HH:MM)이 KST
/// 라는 계약을 절대 시각으로 옮기는 자리.
///
/// **왜 콘텐츠 계층이 소유하는가.** "이 날짜와 시각이 어느 시간대의 것인가"는
/// 콘텐츠 계약(`content-pipeline` 의 schedule 스키마)이 정하는 사실이고,
/// `models.dart` 의 `Game.date`·`Game.startTime` 문서가 그렇게 적고 있다.
/// 2.3 이 이 함수들을 `lib/features/home/next_away_game.dart` 안에 두었던 것은
/// 그때 유일한 소비자가 홈이었기 때문인데, 4.1 의 구장 방문 판정
/// (`lib/location/visit_check.dart`)이 같은 달력을 두 번째로 쓴다. 비 UI
/// 계층이 feature 를 import 하는 방향은 만들지 않으므로 공용 자리로 옮겼다.
/// 옛 자리는 이 파일을 그대로 다시 내보내므로 부르는 쪽의 import 는 그대로다.
library;

import 'models.dart';

/// KST 와 UTC 의 차 — 한국은 서머타임이 없어 연중 고정이다.
const Duration kstOffset = Duration(hours: 9);

/// [moment] 의 KST 달력 날짜. 시각 성분은 0 (UTC 자정 표현).
DateTime kstDateOf(DateTime moment) {
  final kst = moment.toUtc().add(kstOffset);
  return DateTime.utc(kst.year, kst.month, kst.day);
}

/// 경기의 KST 날짜(YYYY-MM-DD)를 [kstDateOf] 와 같은 표현(UTC 자정)으로.
DateTime gameDateOf(Game game) => DateTime.parse('${game.date}T00:00:00Z');

/// 경기가 시작하는 **절대 시각**(UTC 표현).
///
/// `date`·`startTime` 두 문자열이 KST 라는 계약을 시각 하나로 접는 유일한
/// 자리다 — 시간 창 판정(`lib/location/visit_check.dart`)이 기기의 지금
/// 시각과 비교할 수 있는 값은 이것뿐이다.
DateTime gameStartsAt(Game game) =>
    DateTime.parse('${game.date}T${game.startTime}:00+09:00').toUtc();
