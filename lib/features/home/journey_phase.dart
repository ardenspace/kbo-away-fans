/// 홈에서 보여 줄 원정 여정의 현재 단계.
///
/// 선언 순서는 판정 우선순위와 같다. 여러 신호가 동시에 참이면
/// [resolveJourneyPhase]는 앞에 있는 단계를 고른다.
enum JourneyPhase { cancelled, live, nearby, moving, postGame, preGame, idle }

/// 시간·위치·취소 신호를 한 단계로 접는 순수 입력.
///
/// nullable 값은 아직 관측하지 못한 신호다. 그런 신호를 추측해서 참으로
/// 만들지 않으며, 판정할 수 있는 다른 신호도 없으면 [JourneyPhase.idle]로
/// 내려간다.
class JourneyPhaseSignals {
  const JourneyPhaseSignals({
    this.now,
    this.gameStartsAt,
    this.gameEndsAt,
    this.cancelled,
    this.nearby,
    this.moving,
  });

  final DateTime? now;
  final DateTime? gameStartsAt;
  final DateTime? gameEndsAt;
  final bool? cancelled;
  final bool? nearby;
  final bool? moving;
}

/// [signals]를 `cancelled > live > nearby > moving > postGame > preGame > idle`
/// 우선순위로 판정한다.
///
/// 경기 시간은 `[gameStartsAt, gameEndsAt)` 구간을 live로 본다. 따라서 시작
/// 시각은 live에 포함되고 종료 시각부터 postGame이다. 시작·종료 중 하나라도
/// 없거나 종료가 시작보다 이르면 시간만으로 단계를 만들지 않는다.
JourneyPhase resolveJourneyPhase(JourneyPhaseSignals signals) {
  if (signals.cancelled == true) return JourneyPhase.cancelled;

  final now = signals.now;
  final startsAt = signals.gameStartsAt;
  final endsAt = signals.gameEndsAt;
  final hasValidTimeline =
      now != null &&
      startsAt != null &&
      endsAt != null &&
      !endsAt.isBefore(startsAt);

  if (hasValidTimeline && !now.isBefore(startsAt) && now.isBefore(endsAt)) {
    return JourneyPhase.live;
  }
  if (signals.nearby == true) return JourneyPhase.nearby;
  if (signals.moving == true) return JourneyPhase.moving;
  if (hasValidTimeline && !now.isBefore(endsAt)) {
    return JourneyPhase.postGame;
  }
  if (hasValidTimeline && now.isBefore(startsAt)) {
    return JourneyPhase.preGame;
  }
  return JourneyPhase.idle;
}
