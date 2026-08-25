import 'package:flutter/material.dart';

/// 디자인 토큰 원본 (팀 테마는 team_themes.dart).
///
/// 규칙: `lib/design/` 밖에서는 raw hex·치수 리터럴을 쓰지 않는다.
/// 모든 색·간격·모서리·타이포·모션 값은 이 파일과 team_themes.dart 의
/// 이름 있는 토큰에서 온다 (`scripts/hooks/check-hardcoded-values.sh`가 검사).
/// 구체 값은 초기값이며 추후 디자인 단계에서 조정할 수 있다.

/// `color.*` — 기본 팔레트 + 시맨틱 색. 팀 테마와 무관한 모든 색.
abstract final class ColorTokens {
  // 배경·표면
  static const Color background = Color(0xFFF7F6F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFEDEBE6);
  static const Color outline = Color(0xFFD9D6CF);

  // 텍스트
  static const Color textPrimary = Color(0xFF1A1A1E);
  static const Color textSecondary = Color(0xFF6B6B73);
  static const Color textInverse = Color(0xFFFFFFFF);

  // 시맨틱
  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFF2A93B);
  static const Color danger = Color(0xFFE0455A);

  // 연출 (비 오는 날 배경 오버레이 등)
  static const Color rainOverlay = Color(0x662F3B52);

  /// 빗줄기(RainLayer) 색 — 반투명 슬레이트 블루.
  static const Color rainDrop = Color(0x8C42557C);
}

/// `space.*` — 간격 스케일. 마진, 패딩, 갭.
abstract final class SpaceTokens {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// `radius.*` — 모서리 스케일. "통통 튀는" 톤이라 큰 라운드가 기본.
abstract final class RadiusTokens {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// 칩·필 형태 (사실상 완전한 라운드).
  static const double pill = 999;
}

/// `type.*` — 폰트 패밀리·크기·굵기. 트렌디하고 둥근 볼드 지향.
abstract final class TypeTokens {
  /// 기본 폰트 패밀리. null 이면 플랫폼 기본 폰트.
  /// 둥근 볼드 계열 커스텀 폰트는 디자인 단계에서 번들 후 여기만 바꾼다.
  static const String? fontFamily = null;

  // 크기 스케일
  static const double display = 32;
  static const double title = 24;
  static const double heading = 20;
  static const double body = 16;
  static const double label = 14;
  static const double caption = 12;

  // 굵기 — 둥근 볼드 지향이라 굵은 쪽을 기본으로 쓴다.
  static const FontWeight weightRegular = FontWeight.w400;
  static const FontWeight weightMedium = FontWeight.w500;
  static const FontWeight weightBold = FontWeight.w700;
  static const FontWeight weightExtraBold = FontWeight.w800;
}

/// `rain.*` — 비 연출(WeatherBackdrop 빗줄기) 수치 토큰.
///
/// 색은 [ColorTokens.rainDrop]/[ColorTokens.rainOverlay],
/// 낙하 주기는 [MotionTokens.rainFall] 에서 온다.
abstract final class RainTokens {
  /// 화면에 동시에 떠 있는 빗줄기 개수.
  static const int dropCount = 90;

  /// 빗줄기 기본 길이 (방울별로 축소 변주된다).
  static const double dropLength = 16;

  /// 빗줄기 선 굵기.
  static const double strokeWidth = 2;

  /// 빗줄기 기울기 — 낙하 거리 대비 가로 이동 비율.
  static const double slant = 0.2;
}

/// `motion.*` — 지속시간·커브. 탄성(bouncy spring)이 기본 톤.
abstract final class MotionTokens {
  // 지속시간
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 450);

  /// 팀 테마 전환 연출 (구장 화면 진입 등).
  static const Duration themeShift = Duration(milliseconds: 600);

  /// 날씨 배경 연출 (비 시작/그침 등).
  static const Duration weatherShift = Duration(milliseconds: 900);

  /// 빗줄기 한 방울이 화면을 종단하는 낙하 주기 (RainLayer 반복 주기).
  static const Duration rainFall = Duration(milliseconds: 800);

  // 커브 — 탄성 커브가 기본값.
  static const Curve bouncy = Curves.elasticOut;
  static const Curve emphasized = Curves.easeOutBack;
  static const Curve standard = Curves.easeOutCubic;
}
