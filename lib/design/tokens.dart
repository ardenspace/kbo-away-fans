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
/// 빈 화면에서 로고가 코앞으로부터 날아와 꽂히고, 그 충격으로 화면이
/// 흔들리는 동시에 실밥 두 가닥이 좌우에서 밀려 들어온다. 거리 값은 전부
/// 화면 크기 대비 비율이라 기기 크기와 무관하게 같은 인상을 준다.
/// 커브는 [MotionTokens] 에서 온다.
abstract final class SplashTokens {
  /// 착지 순간부터 실밥이 화면 밖에서 제자리까지 밀려 들어오는 구간.
  static const Duration seamEntry = Duration(milliseconds: 1200);

  /// 실밥이 들어오는 방향의 기울기 (가로 이동 대비 세로 이동).
  ///
  /// 0 이면 순수한 가로 이동이라 실밥이 옆으로 미끄러져 들어온다. 실밥
  /// 그림의 기울기(원화를 재면 위 실밥 -0.219, 아래 실밥 -0.252)를 넣으면
  /// 제 각도를 따라 비스듬히 들어온다. 두 실밥의 기울기를 따로 두면 좌우
  /// 진입이 비대칭으로 보이므로 하나로 쓴다.
  static const double seamSlantSlope = 0;

  /// 실밥을 화면 폭보다 넓게 그려 두는 배율.
  ///
  /// 무늬 크기를 정하는 값이면서, 실밥이 화면 밖 어디에서 출발하는지도
  /// 여기서 나온다. 완전히 가려지려면 화면 폭의 `(seamOverscan + 1) / 2`
  /// 만큼 밀려나 있어야 하므로, 이 값을 키우면 들어오는 거리도 길어진다.
  static const double seamOverscan = 1.6;

  /// 빈 화면이 유지되다 로고가 날아들기까지의 지연.
  static const Duration logoDelay = Duration(milliseconds: 750);

  /// 로고가 코앞에서 화면으로 꽂히는 구간 ("쾅").
  ///
  /// 60fps 기준 아홉 프레임이다. [MotionTokens.swoop] 커브가 첫 프레임에
  /// 거리 대부분을 지나가므로, 구간이 길어져도 "다가온다" 가 아니라
  /// "꽂힌 뒤 여운이 남는다" 로 읽힌다.
  static const Duration logoSlam = Duration(milliseconds: 150);

  /// 날아드는 동안 로고에 걸리는 흐림의 최대 세기 (가우시안 sigma).
  ///
  /// 남은 거리에 비례해 줄어들어 착지 순간 정확히 0 이 된다. 이 흐림이
  /// 없으면 순식간에 지나가는 구간이라 그냥 튀어나온 것처럼 보인다.
  static const double logoMotionBlur = 28;

  /// 로고가 출발하는 깊이 (논리 픽셀). 음수가 보는 사람 쪽이다.
  ///
  /// [logoPerspective] 와 함께 시작 배율을 정한다. 화면 크기와 무관하게
  /// 배율이 같으므로 절대값으로 둔다.
  static const double logoStartDepth = -420;

  /// 원근 강도 — 클수록 깊이 차이가 과장된다.
  ///
  /// 시작 배율은 `1 / (1 + logoPerspective * logoStartDepth)` 로,
  /// 현재 값에서는 약 2.7배다.
  static const double logoPerspective = 0.0015;

  /// 로고가 흐릿한 상태에서 또렷해지는 구간 — [logoSlam] 대비 비율.
  /// 갑자기 큰 로고가 튀어나오는 인상을 눌러 준다.
  static const double logoFadeInRatio = 0.4;

  /// 로고 폭 — 화면 폭 대비 비율.
  static const double logoWidthFactor = 0.68;

  /// 착지 충격으로 화면 전체가 흔들리는 구간.
  ///
  /// 진동 속도는 이 값과 [shakeOscillations] 가 함께 정한다
  /// (초당 진동수 = shakeOscillations / shake). 짧을수록 빠르다.
  /// 지금은 초당 2.9회이며, 빠르게 올려 봤더니 잔떨림처럼 보여서
  /// 느긋한 쪽으로 정착했다.
  static const Duration shake = Duration(milliseconds: 1200);

  /// 흔들림의 세로 진폭 — 화면 폭 대비 비율.
  static const double shakeFactor = 0.02;

  /// 흔들림이 잦아들 때까지의 진동 횟수.
  static const double shakeOscillations = 3.5;

  /// 세로 진폭 대비 가로 진폭의 비율.
  static const double shakeLateralRatio = 0.5;

  /// 연출이 끝나고 다음 화면으로 넘기기 전 머무는 시간.
  static const Duration hold = Duration(milliseconds: 900);

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

  /// 튀어나오듯 시작해 급격히 감속하며 멎는 구간.
  /// 첫 프레임에 거리 대부분을 지나가므로 아주 짧은 구간에서도 속도가 읽힌다.
  static const Curve swoop = Curves.easeOutQuart;
}
