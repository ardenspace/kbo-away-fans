/// 경기 상태 — DB `games.status` CHECK 와 일치.
enum GameStatus {
  scheduled('예정'),
  inProgress('경기중'),
  finished('종료'),
  cancelled('취소'),
  postponed('연기');

  const GameStatus(this.label);
  final String label;

  static GameStatus parse(String raw) => switch (raw) {
    'in_progress' => GameStatus.inProgress,
    'finished' => GameStatus.finished,
    'cancelled' => GameStatus.cancelled,
    'postponed' => GameStatus.postponed,
    _ => GameStatus.scheduled,
  };
}

/// 원정 일정 카드용 경기. `games` + 상대(홈)팀·구장 join 결과.
class Game {
  final String id;
  final DateTime scheduledAt;
  final GameStatus status;
  final String stadiumId;
  final String stadiumName;
  final String homeTeamShortName;
  final String homeTeamAbbr;

  const Game({
    required this.id,
    required this.scheduledAt,
    required this.status,
    required this.stadiumId,
    required this.stadiumName,
    required this.homeTeamShortName,
    required this.homeTeamAbbr,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    final home = json['home_team'] as Map<String, dynamic>;
    final stadium = json['stadium'] as Map<String, dynamic>;
    return Game(
      id: json['id'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      status: GameStatus.parse(json['status'] as String),
      stadiumId: json['stadium_id'] as String,
      stadiumName: stadium['name'] as String,
      homeTeamShortName: home['short_name'] as String,
      homeTeamAbbr: home['abbr'] as String,
    );
  }
}
