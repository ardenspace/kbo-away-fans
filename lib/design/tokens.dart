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

  /// 스플래시 배경 — 실밥 에셋(`assets/splash/seam_*.png`)에 구워진
  /// 오프화이트와 정확히 같은 값이어야 이음매가 보이지 않는다.
  /// 에셋을 다시 만들면 이 값도 함께 맞춘다.
  static const Color splashBackground = Color(0xFFF1F0EF);
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

/// `splash.*` — 스플래시 연출 수치 토큰.
///
/// 실밥 두 가닥이 위아래로 살짝 벌어지고, 그 사이에서 로고가 튀어나와
/// 몇 번 작게 점프한다. 거리 값은 전부 화면 크기 대비 비율이라 기기
/// 크기와 무관하게 같은 인상을 준다. 커브는 [MotionTokens] 에서 온다.
abstract final class SplashTokens {
  /// 벌어지기 직전 안쪽으로 움츠리는 반동 구간.
  static const Duration seamAnticipation = Duration(milliseconds: 150);

  /// 실밥이 바깥으로 벌어지는 구간.
  static const Duration seamSeparation = Duration(milliseconds: 600);

  /// 실밥이 최종적으로 벌어지는 거리 — 화면 높이 대비 비율.
  ///
  /// 세로 분리는 가로 미끄러짐보다 훨씬 잘 보이므로, 가로가 묻히지 않게
  /// 일부러 작게 잡았다. 이 값을 키우면 가로 움직임이 다시 가려진다.
  static const double seamSeparationFactor = 0.02;

  /// 실밥이 가로로 미끄러지는 거리 — 화면 폭 대비 비율.
  /// 위 실밥은 왼쪽으로, 아래 실밥은 오른쪽으로 간다.
  ///
  /// 실밥이 수평에서 12도밖에 안 기울어서, 옆으로 미는 것은 실밥을 제
  /// 방향으로 미는 것에 가깝다. 그래서 눈에 띄려면 이동 거리가 커야 하고,
  /// 그만큼 [seamOverscan] 도 함께 커진다.
  static const double seamDriftFactor = 0.25;

  /// 실밥을 화면 폭보다 넓게 그려 두는 배율.
  ///
  /// 가로로 미끄러질 때 가장자리에 빈 구간이 드러나지 않게 하는 여유분이며,
  /// 한쪽 여유는 `(seamOverscan - 1) / 2` 다. 이 값이 [seamDriftFactor] 보다
  /// 커야 하므로 둘 중 하나를 조정할 때는 함께 확인한다.
  static const double seamOverscan = 1.6;

  /// 반동으로 안쪽으로 움츠리는 거리 — 벌어지는 거리 대비 비율.
  static const double seamAnticipationFactor = 0.15;

  /// 실밥이 벌어지기 시작한 뒤 로고가 등장하기까지의 지연.
  static const Duration logoDelay = Duration(milliseconds: 200);

  /// 로고가 크기 0 에서 1 로 튀어나오는 구간 ("띠요옹").
  static const Duration logoPop = Duration(milliseconds: 700);

  /// 등장 후 작은 점프를 모두 마치기까지의 구간.
  static const Duration logoBounce = Duration(milliseconds: 500);

  /// 작은 점프 횟수.
  static const int logoBounceCount = 3;

  /// 첫 점프의 높이 — 화면 높이 대비 비율.
  static const double logoBounceFactor = 0.028;

  /// 점프마다 높이가 줄어드는 비율 (1 이면 잦아들지 않는다).
  static const double logoBounceDecay = 0.55;

  /// 로고 폭 — 화면 폭 대비 비율.
  static const double logoWidthFactor = 0.68;

  /// 연출이 끝나고 다음 화면으로 넘기기 전 머무는 시간.
  static const Duration hold = Duration(milliseconds: 300);

  /// 스플래시에서 앱 첫 화면으로 넘어가는 페이드 구간.
  static const Duration handoff = Duration(milliseconds: 350);
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

  /// 위로 솟는 구간 — 처음이 빠르고 정점에서 느려진다 (점프의 상승부).
  static const Curve rise = Curves.easeOut;

  /// 아래로 떨어지는 구간 — 중력처럼 끝으로 갈수록 빨라진다 (점프의 하강부).
  static const Curve fall = Curves.easeIn;
}
