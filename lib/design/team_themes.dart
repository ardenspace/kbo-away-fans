import 'package:flutter/material.dart';

/// `team.<id>.*` — 10개 팀 테마 토큰. 구장 화면 컬러 테마 전환의 근거.
///
/// 팀 id는 content-pipeline/schema/common.defs.schema.json 의 teamId enum
/// 10종과 정확히 일치한다 (잠실은 경기의 홈팀 기준으로 테마 전환).
/// 구체 색은 초기값이며 추후 디자인 단계에서 조정할 수 있다.

/// 팀 하나의 테마 색 묶음.
@immutable
class TeamTheme {
  const TeamTheme({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
  });

  /// 팀 대표색.
  final Color primary;

  /// primary 위에 올리는 콘텐츠 색.
  final Color onPrimary;

  /// 보조색 (포인트·배지 등).
  final Color secondary;

  /// secondary 위에 올리는 콘텐츠 색.
  final Color onSecondary;

  /// 두 팀 테마 사이를 색 채널 단위로 보간한다 (테마 전환 연출용).
  ///
  /// [t] 가 0이면 [a] 와, 1이면 [b] 와 같은 색이 나온다. 네 색을 각각
  /// [Color.lerp] 로 건너보내므로 대표색과 그 위 콘텐츠 색이 함께 움직여
  /// 전환 도중에도 대비가 유지된다.
  static TeamTheme lerp(TeamTheme a, TeamTheme b, double t) {
    if (identical(a, b)) return a;
    return TeamTheme(
      primary: Color.lerp(a.primary, b.primary, t)!,
      onPrimary: Color.lerp(a.onPrimary, b.onPrimary, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      onSecondary: Color.lerp(a.onSecondary, b.onSecondary, t)!,
    );
  }

  /// 값 동등성 — 보간이 만드는 인스턴스는 매번 새것이라, 같은 색인지를
  /// 인스턴스 동일성 대신 색 값으로 판정해야 재알림이 낭비되지 않는다.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeamTheme &&
        other.primary == primary &&
        other.onPrimary == onPrimary &&
        other.secondary == secondary &&
        other.onSecondary == onSecondary;
  }

  @override
  int get hashCode => Object.hash(primary, onPrimary, secondary, onSecondary);
}

/// 팀 id → 테마 레지스트리.
abstract final class TeamThemes {
  static const TeamTheme lg = TeamTheme(
    primary: Color(0xFFC30452),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF000000),
    onSecondary: Color(0xFFFFFFFF),
  );

  static const TeamTheme doosan = TeamTheme(
    primary: Color(0xFF1A1748),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFEB1D25),
    onSecondary: Color(0xFFFFFFFF),
  );

  static const TeamTheme kiwoom = TeamTheme(
    primary: Color(0xFF570514),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFB07F4A),
    onSecondary: Color(0xFFFFFFFF),
  );

  static const TeamTheme ssg = TeamTheme(
    primary: Color(0xFFCE0E2D),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFFFB81C),
    onSecondary: Color(0xFF000000),
  );

  static const TeamTheme kt = TeamTheme(
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFEB1C24),
    onSecondary: Color(0xFFFFFFFF),
  );

  static const TeamTheme kia = TeamTheme(
    primary: Color(0xFFEA0029),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF06141F),
    onSecondary: Color(0xFFFFFFFF),
  );

  static const TeamTheme samsung = TeamTheme(
    primary: Color(0xFF074CA1),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFC0C0C0),
    onSecondary: Color(0xFF074CA1),
  );

  static const TeamTheme lotte = TeamTheme(
    primary: Color(0xFF041E42),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFD00F31),
    onSecondary: Color(0xFFFFFFFF),
  );

  static const TeamTheme nc = TeamTheme(
    primary: Color(0xFF315288),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFAF917B),
    onSecondary: Color(0xFF00275A),
  );

  static const TeamTheme hanwha = TeamTheme(
    primary: Color(0xFFFC4E00),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF07111F),
    onSecondary: Color(0xFFFFFFFF),
  );

  /// 팀 id로 테마 조회. 키는 common.defs.schema.json teamId enum 10종.
  static const Map<String, TeamTheme> byId = {
    'lg': lg,
    'doosan': doosan,
    'kiwoom': kiwoom,
    'ssg': ssg,
    'kt': kt,
    'kia': kia,
    'samsung': samsung,
    'lotte': lotte,
    'nc': nc,
    'hanwha': hanwha,
  };
}
