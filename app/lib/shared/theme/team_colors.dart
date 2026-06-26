import 'package:flutter/material.dart';

/// 한 팀의 브랜드 색. `scripts/seed/data/teams.json` 의 primary/secondary 와 일치.
class TeamColors {
  final Color primary;
  final Color secondary;
  const TeamColors(this.primary, this.secondary);
}

/// abbr → 팀 색. 키는 teams.json 의 `abbr` (DB teams.abbr 와 동일).
const Map<String, TeamColors> kTeamColors = {
  'OB': TeamColors(Color(0xFF131230), Color(0xFFC8102E)), // 두산 베어스
  'LG': TeamColors(Color(0xFFC8102E), Color(0xFF000000)), // LG 트윈스
  'KW': TeamColors(Color(0xFF002D6D), Color(0xFFC8102E)), // 키움 히어로즈
  'SK': TeamColors(Color(0xFFCE0E2D), Color(0xFF000000)), // SSG 랜더스
  'LT': TeamColors(Color(0xFFCE0E2D), Color(0xFF003087)), // 롯데 자이언츠
  'SS': TeamColors(Color(0xFF0038A8), Color(0xFFCE0E2D)), // 삼성 라이온즈
  'HH': TeamColors(Color(0xFFF37021), Color(0xFF1A1A1A)), // 한화 이글스
  'HT': TeamColors(Color(0xFFCE0E2D), Color(0xFF000000)), // KIA 타이거즈
  'NC': TeamColors(Color(0xFF003A6C), Color(0xFFB5A36A)), // NC 다이노스
  'KT': TeamColors(Color(0xFF000000), Color(0xFFCE0E2D)), // KT 위즈
};

/// 팀 미선택 시 쓰는 중립 기본색 (KBO 느낌의 네이비).
const TeamColors kNeutralColors = TeamColors(Color(0xFF1B2A4A), Color(0xFF8A94A6));
