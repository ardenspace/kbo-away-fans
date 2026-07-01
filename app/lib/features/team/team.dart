/// KBO 팀. DB `teams` 행과 1:1. 색은 `shared/theme/team_colors.dart` 의 abbr 매핑을 쓴다.
class Team {
  final String id;
  final String abbr;
  final String name;
  final String shortName;

  const Team({
    required this.id,
    required this.abbr,
    required this.name,
    required this.shortName,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json['id'] as String,
    abbr: json['abbr'] as String,
    name: json['name'] as String,
    shortName: json['short_name'] as String,
  );
}
