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

/// `text.*` — 폰트·크기·굵기·색을 묶은 **이름 있는 조합 스타일**.
///
/// 화면 코드에서 `TextStyle(fontFamily:…, fontSize:…, fontWeight:…, color:…)`
/// 네 줄을 손으로 다시 쓰지 않는다. 모든 값은 [TypeTokens]·[ColorTokens] 의
/// 낱개 토큰에서 오며 여기서 새 수치를 만들지 않는다.
///
/// 이름 규약 — `<역할>` + 선택 접미사:
/// * 접미사 없음: 본문색([ColorTokens.textPrimary]) 위 기본 굵기
/// * `Muted`: 보조색([ColorTokens.textSecondary])
/// * `Strong`: 같은 크기에서 한 단계 굵게
/// * `onTeam*`: 팀 대표색 위 (기본 전경은 [ColorTokens.textInverse],
///   실제 팀 테마 색은 사용처에서 `.copyWith(color: theme.onPrimary)`)
///
/// | 이름 | 크기 | 굵기 | 색 |
/// |---|---|---|---|
/// | `display` | display | extraBold | textPrimary |
/// | `title` | title | extraBold | textPrimary |
/// | `heading` | heading | extraBold | textPrimary |
/// | `sectionTitle` | heading | bold | textPrimary |
/// | `sectionTitleMuted` | heading | bold | textSecondary |
/// | `body` | body | regular | textPrimary |
/// | `bodyStrong` | body | bold | textPrimary |
/// | `bodyMuted` | body | medium | textSecondary |
/// | `label` | label | bold | textPrimary |
/// | `labelMuted` | label | bold | textSecondary |
/// | `supporting` | label | medium | textSecondary |
/// | `caption` | caption | medium | textSecondary |
/// | `appBarTitle` | heading | extraBold | textInverse |
/// | `onTeamLabel` | label | extraBold | textInverse |
/// | `onTeamLabelCompact` | caption | extraBold | textInverse |
abstract final class TextTokens {
  /// 화면 하나를 여는 가장 큰 글자 (온보딩 첫 문장, D-day 숫자).
  static const TextStyle display = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.display,
    fontWeight: TypeTokens.weightExtraBold,
    color: ColorTokens.textPrimary,
  );

  /// 화면·시트의 제목.
  static const TextStyle title = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.title,
    fontWeight: TypeTokens.weightExtraBold,
    color: ColorTokens.textPrimary,
  );

  /// 구역을 여는 제목 (가장 굵은 단계).
  static const TextStyle heading = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.heading,
    fontWeight: TypeTokens.weightExtraBold,
    color: ColorTokens.textPrimary,
  );

  /// 카드·목록 항목의 제목 ([heading] 과 같은 크기에서 한 단계 얇게).
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.heading,
    fontWeight: TypeTokens.weightBold,
    color: ColorTokens.textPrimary,
  );

  /// 아직 내용이 없는 자리의 제목 (빈 상태·자리 표시).
  static const TextStyle sectionTitleMuted = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.heading,
    fontWeight: TypeTokens.weightBold,
    color: ColorTokens.textSecondary,
  );

  /// 읽는 문장 본문.
  static const TextStyle body = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.body,
    fontWeight: TypeTokens.weightRegular,
    color: ColorTokens.textPrimary,
  );

  /// 본문 중 강조 (버튼 문구, 골라야 하는 항목 이름).
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.body,
    fontWeight: TypeTokens.weightBold,
    color: ColorTokens.textPrimary,
  );

  /// 제목 아래 한 줄 설명 — 가장 많이 쓰이는 보조 문구.
  static const TextStyle bodyMuted = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.body,
    fontWeight: TypeTokens.weightMedium,
    color: ColorTokens.textSecondary,
  );

  /// 칩·버튼 등 누를 수 있는 것의 짧은 이름.
  static const TextStyle label = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.label,
    fontWeight: TypeTokens.weightBold,
    color: ColorTokens.textPrimary,
  );

  /// 고르지 않은 칩처럼 눌리지 않은 상태의 짧은 이름.
  static const TextStyle labelMuted = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.label,
    fontWeight: TypeTokens.weightBold,
    color: ColorTokens.textSecondary,
  );

  /// 카드 안의 부가 정보 한 줄 (주소, 카테고리 등).
  static const TextStyle supporting = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.label,
    fontWeight: TypeTokens.weightMedium,
    color: ColorTokens.textSecondary,
  );

  /// 가장 작은 보조 문구 (뱃지 밑 주석, 안내 소문자).
  static const TextStyle caption = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.caption,
    fontWeight: TypeTokens.weightMedium,
    color: ColorTokens.textSecondary,
  );

  /// 팀 테마 앱바의 제목. 실제 색은 사용처가
  /// `.copyWith(color: theme.onPrimary)` 로 팀 전경색을 덮어쓴다.
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.heading,
    fontWeight: TypeTokens.weightExtraBold,
    color: ColorTokens.textInverse,
  );

  /// 팀 대표색 몸통 위에 얹는 짧은 글자 (팀 약칭, 도장 칸 라벨).
  static const TextStyle onTeamLabel = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.label,
    fontWeight: TypeTokens.weightExtraBold,
    color: ColorTokens.textInverse,
  );

  /// [onTeamLabel] 의 좁은 자리 판 (compact 뱃지).
  static const TextStyle onTeamLabelCompact = TextStyle(
    fontFamily: TypeTokens.fontFamily,
    fontSize: TypeTokens.caption,
    fontWeight: TypeTokens.weightExtraBold,
    color: ColorTokens.textInverse,
  );

  /// 색만 떼어낸 사본 — 전경색을 주변에서 물려받아야 하는 자리용
  /// (`TextButton` 처럼 버튼 테마가 색을 정하는 경우).
  ///
  /// `copyWith(color: null)` 은 색을 지우지 못하므로 이 경로가 필요하다.
  /// 색이 정해져 있는 자리라면 이걸 쓰지 말고 조합 스타일을 그대로 쓴다.
  static TextStyle inheritColor(TextStyle style) => TextStyle(
    fontFamily: style.fontFamily,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
  );

  /// 위 조합 스타일 전체 — 토큰 검사·테스트가 훑는 목록.
  static const List<TextStyle> all = [
    display,
    title,
    heading,
    sectionTitle,
    sectionTitleMuted,
    body,
    bodyStrong,
    bodyMuted,
    label,
    labelMuted,
    supporting,
    caption,
    appBarTitle,
    onTeamLabel,
    onTeamLabelCompact,
  ];
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

/// `badge.*` — 배지 판(10칸)과 도장 칸의 수치 토큰.
///
/// 판은 팀 테마 10개와 1:1 대응하는 10칸이다 (잠실은 그날 홈팀 기준으로 두 칸).
/// 칸 몸통 색은 `TeamTheme` 의 대표색에서 오고, 등급 표현은
/// [BadgeTierTokens] 가 그 위에 얹는다. 판의 배치(격자/지도형)는 판을 만드는
/// 쪽이 정하므로 열 수는 토큰으로 두지 않는다.
///
/// 등급은 **링 하나로만** 나타낸다 — 칸에 따로 붙는 등급 마크는 없으므로
/// 그 크기 토큰도 두지 않는다 (두 벌의 등급 표현이 생기지 않게).
abstract final class BadgeTokens {
  /// 판의 칸 수 — 팀 테마 10개와 1:1.
  static const int cellCount = 10;

  /// 칸 한 변의 기본 크기 (원형이라 지름).
  static const double cellSize = 72;

  /// 칸과 칸 사이 간격.
  static const double cellGap = SpaceTokens.md;

  /// 칸 모서리 — 도장이라 완전한 원.
  static const double cellRadius = RadiusTokens.pill;

  /// 판 바깥 여백.
  static const double boardPadding = SpaceTokens.lg;

  /// 아직 못 간 구장 칸의 팀 색 투명도. 빈 칸도 처음부터 전부 보여주므로
  /// "무엇을 채우면 되는지"는 읽히되 획득 칸과는 확실히 갈려야 한다.
  static const double emptyOpacity = 0.16;

  /// 빈 칸 테두리 굵기 (점선처럼 읽히는 자리 표시).
  static const double emptyBorderWidth = 2;

  /// 빈 칸 테두리 색 — 팔레트의 경계선 색 [ColorTokens.outline] 을 그대로
  /// 쓴다. 굵기만 토큰으로 두면 판을 그리는 쪽이 색을 직접 고르게 되는데,
  /// 그때 고르는 값은 `Colors.grey` 처럼 hex 리터럴이 아닌 형태라
  /// `check-hardcoded-values.sh` 가 잡지 못한 채 팔레트 밖 색이 들어온다.
  static const Color emptyBorderColor = ColorTokens.outline;

  /// 등급 링을 칸 가장자리에서 안쪽으로 들이는 거리.
  static const double tierRingInset = 3;
}

/// 배지 등급 3단계. 값은 [BadgeTierTokens].
///
/// 한 칸(= 팀 홈구장 하나)에 쌓인 도장 개수로 갈린다. 칸이 팀 테마 10개와
/// 1:1 이므로 잠실은 LG·두산 두 칸이고, 두 칸의 등급도 따로 오른다.
enum BadgeTier {
  /// 첫 도장 — 그 구장에 가 봤다.
  first,

  /// 단골 — 여러 번 갔다.
  regular,

  /// 마스터 — 그 구장을 제집처럼 다녔다.
  master,
}

/// 링 한 겹 — 색과 굵기. [BadgeTierStyle.rings] 가 **바깥에서 안쪽 순서로**
/// 쌓는 단위이며, 렌더러는 목록 순서대로 동심원 테두리를 그린다.
@immutable
class BadgeRingLayer {
  const BadgeRingLayer({required this.color, required this.width});

  /// 이 겹의 색.
  final Color color;

  /// 이 겹의 굵기.
  final double width;
}

/// 등급 하나의 표현 값.
///
/// 칸 몸통은 팀 대표색이므로 등급은 **색을 바꾸지 않고 위에 얹는다** —
/// 링은 칸 가장자리에만 놓이고 몸통 한가운데는 언제나 팀 색 그대로다.
///
/// 링이 몸통 위에서 읽히는 세기를 정하는 것은 **링 전체가 아니라 몸통과
/// 실제로 맞닿는 두 끝 겹**이다. 링 바깥도 칸 몸통이고 링 안쪽도 칸 몸통이라
/// 경계는 두 곳이며, 링 한가운데에 아무리 밝은 겹이 있어도 끝 겹이 몸통에
/// 묻으면 링의 실루엣은 뜨지 않는다.
///
/// 그래서 [BadgeTierTokens.haloColor](밝은 겉테)를 **바깥 끝과 안쪽 끝 양쪽**에
/// 둔다. 그러면 경계 대비가 곧 겉테색과 팀 대표색의 대비가 되어, 10개 팀에서
/// 최소 3.37:1(한화) ~ 최대 21.00:1(kt)로 전부 최소선 3:1 위다.
/// 요구 범위를 10개 팀 색으로 한정하는 이유: "어떤 sRGB 색 위에서도"는
/// 흰 몸통이 밝은 겹을, 검은 몸통이 어두운 겹을 각각 죽이므로 경계 기준으로
/// 달성할 수 없다 (`.wellbegun/decisions.md` 참조).
///
/// 등급을 가리키는 [ringColor] 금속 띠는 [BadgeTierTokens.contourColor] 윤곽
/// 안쪽에 갇혀 몸통과 맞닿지 않으므로, 등급이 읽히는 세기가 팀 색에 좌우되지
/// 않는다.
@immutable
class BadgeTierStyle {
  const BadgeTierStyle({
    required this.minStamps,
    required this.label,
    required this.ringColor,
    required this.rings,
  });

  /// 이 등급이 되는 최소 도장 개수.
  final int minStamps;

  /// 화면에 보이는 등급 이름.
  final String label;

  /// 등급을 가리키는 금속색. [rings] 안의 금속 띠 색과 같은 값이다.
  final Color ringColor;

  /// 팀 색 위에 얹는 링 — **바깥에서 안쪽 순서**. 첫 겹과 마지막 겹은 몸통과
  /// 맞닿는 밝은 겉테이고, 금속 띠는 어두운 윤곽 안쪽에 놓인다.
  final List<BadgeRingLayer> rings;

  /// 이 등급이 **실제로 칠하는** 칸 몸통 색.
  ///
  /// 등급은 몸통 색을 갈아치우지 않으므로 지금은 [teamPrimary] 그대로다.
  /// 그런데도 경로를 따로 두는 이유: 예전에는 등급마다 세기가 다른 흰 광택을
  /// 몸통에 덧대면서 링이 실제로 맞닿는 색이 팀 대표색이 아니게 됐는데,
  /// 대비 검사는 계속 팀 대표색을 기준으로 재고 있어 한화×마스터의 실제 경계가
  /// 2.83:1(최소선 미달)인 것을 놓쳤다. 몸통에 무언가를 얹는 값이 다시 생기면
  /// **여기 한 곳에서** 합성해야 판을 그리는 쪽과 검사가 같은 색을 본다.
  Color bodyColor(Color teamPrimary) => teamPrimary;

  /// 링 전체 굵기 — 모든 겹의 합.
  double get ringWidth =>
      rings.fold<double>(0, (sum, layer) => sum + layer.width);

  /// 금속 띠의 개수 — 1/2/3. 색과 무관하게 셀 수 있는 서열 신호라
  /// 색각 이상이나 작은 크기에서도 등급이 갈린다.
  int get bands => rings.where((layer) => layer.color == ringColor).length;
}

/// `badgeTier.*` — 등급 3단계의 표현 값.
///
/// 임계 개수(1/3/10)는 초기값이다 — 한 시즌 한 구장에 서너 번 가는 팬이
/// 흔하다는 가정에서 잡았고, 실사용을 보고 조정한다.
///
/// 등급의 신호는 **금속색 사다리(구리 → 은 → 금) · 띠 개수(1/2/3) ·
/// 링 총 굵기(6.0/8.5/11.0)** 셋뿐이다. 넷째 신호를 더하지 않는다 — 겹이나
/// 신호를 더할수록 검사해야 할 경계가 늘고 그 자리마다 빈틈이 생겨,
/// 몸통에 덧대던 흰 광택은 제거했다 (`.wellbegun/decisions.md` 참조).
///
/// 금속색은 이웃 등급끼리 상대휘도가 1.9배 이상 벌어지도록 골랐고
/// (`test/design/badge_tier_legibility_test.dart` 가 검사), 띠 개수와 굵기는
/// 색이 안 보이는 조건에서도 서열을 남긴다.
abstract final class BadgeTierTokens {
  /// 링의 밝은 겉테 — 몸통과 맞닿는 두 경계(바깥 끝·안쪽 끝)를 모두 이 색이
  /// 맡아 링의 실루엣을 팀 색 위로 띄운다. 팀 색 위의 기본 전경색
  /// [ColorTokens.textInverse] 와 같은 값이라 새 색을 만들지 않는다.
  static const Color haloColor = ColorTokens.textInverse;

  /// 링의 어두운 윤곽 — 금속 띠를 밝은 겉테에서 떼어 놓아 띠가 겉테에
  /// 묻히지 않게 한다. 팔레트의 [ColorTokens.textPrimary](잉크색)와
  /// 같은 값이라 새 색을 만들지 않는다.
  static const Color contourColor = ColorTokens.textPrimary;

  /// 구릿빛 — `first` 의 금속색.
  static const Color bronze = Color(0xFF9C5F2E);

  /// 은빛 — `regular` 의 금속색. 사다리의 두 단(구리↔은 1.918:1,
  /// 은↔금 1.933:1)이 고르게 나뉘도록 상대휘도를 두 끝의 기하평균에 맞췄다.
  static const Color silver = Color(0xFF969FAB);

  /// 금빛 — `master` 의 금속색.
  static const Color gold = Color(0xFFFFD766);

  /// 링의 모든 겹이 지켜야 하는 최소 굵기 (논리픽셀).
  ///
  /// 링에는 대비를 만들지 않는 장식 겹이 없다 — 겉테는 몸통과의 경계를,
  /// 윤곽은 금속 띠와 밝은 이웃의 경계를, 금속 띠는 등급 자체를 만든다.
  /// 그래서 하한은 겹의 역할을 가리지 않고 전부에 걸린다. 값 1 의 근거는
  /// "배율 1x 화면에서 최소 한 장치픽셀은 칠해져야 계산한 대비가 화면에
  /// 남는다" (`badge_tier_legibility_test.dart` 가 겹마다 검사).
  static const double minLayerWidth = 1;

  /// 밝은 겉테 한 줄의 굵기.
  static const double haloWidth = 1.25;

  /// 어두운 윤곽 한 줄의 굵기. 금속 띠와 밝은 겹의 대비를 만드는 겹이므로
  /// [minLayerWidth] 아래로 내려가지 않는다 — 이 겹이 화면에서 사라지면
  /// 금속 띠가 흰 겉테와 직접 맞닿아 대비가 마스터 1.38:1 · 레귤러 2.68:1 로
  /// 무너지고 링이 흰 덩어리로 읽힌다.
  static const double contourWidth = minLayerWidth;

  /// 금속 띠 한 줄의 굵기. 등급을 가리키는 겹이라 이웃 겹보다 두껍다.
  static const double bandWidth = 1.5;

  /// 몸통과 맞닿는 밝은 겉테 한 겹. 링의 **가장 바깥이자 가장 안쪽**이라
  /// 두 경계의 대비를 모두 이 색이 정한다.
  static const BadgeRingLayer _halo = BadgeRingLayer(
    color: haloColor,
    width: haloWidth,
  );

  /// 금속 띠를 밝은 이웃(겉테·다른 띠)에서 떼어 놓는 어두운 윤곽 한 겹.
  static const BadgeRingLayer _contour = BadgeRingLayer(
    color: contourColor,
    width: contourWidth,
  );

  // 링은 언제나 `겉테 → (윤곽 → 금속 띠) × 띠 개수 → 윤곽 → 겉테` 다.
  // 띠 개수만 1/2/3 으로 늘어나므로 총 굵기도 6.0/8.5/11.0 으로 함께 오른다.

  /// 첫 도장 — 구릿빛 띠 한 줄.
  static const BadgeTierStyle first = BadgeTierStyle(
    minStamps: 1,
    label: '첫 방문',
    ringColor: bronze,
    rings: [
      _halo,
      _contour,
      BadgeRingLayer(color: bronze, width: bandWidth),
      _contour,
      _halo,
    ],
  );

  /// 단골 — 은빛 띠 두 줄.
  static const BadgeTierStyle regular = BadgeTierStyle(
    minStamps: 3,
    label: '단골',
    ringColor: silver,
    rings: [
      _halo,
      _contour,
      BadgeRingLayer(color: silver, width: bandWidth),
      _contour,
      BadgeRingLayer(color: silver, width: bandWidth),
      _contour,
      _halo,
    ],
  );

  /// 마스터 — 금빛 띠 세 줄.
  static const BadgeTierStyle master = BadgeTierStyle(
    minStamps: 10,
    label: '마스터',
    ringColor: gold,
    rings: [
      _halo,
      _contour,
      BadgeRingLayer(color: gold, width: bandWidth),
      _contour,
      BadgeRingLayer(color: gold, width: bandWidth),
      _contour,
      BadgeRingLayer(color: gold, width: bandWidth),
      _contour,
      _halo,
    ],
  );

  /// 등급 → 표현 값. 3단계 전부가 여기 있다.
  static const Map<BadgeTier, BadgeTierStyle> byTier = {
    BadgeTier.first: first,
    BadgeTier.regular: regular,
    BadgeTier.master: master,
  };

  /// 도장 [stamps] 개인 칸의 등급. 0개면 빈 칸이라 등급이 없다(null).
  static BadgeTier? tierFor(int stamps) {
    if (stamps >= master.minStamps) return BadgeTier.master;
    if (stamps >= regular.minStamps) return BadgeTier.regular;
    if (stamps >= first.minStamps) return BadgeTier.first;
    return null;
  }
}

/// 지속시간과 커브를 함께 든 모션 한 벌.
///
/// 낱개 [Duration]·[Curve] 토큰과 달리, 둘을 따로 고르면 조합이 어긋나는
/// 연출(도장 찍기처럼 타이밍과 감속이 한 몸인 것)에 쓴다.
@immutable
class MotionSpec {
  const MotionSpec({required this.duration, required this.curve});

  /// 구간 길이.
  final Duration duration;

  /// 구간 안의 진행 곡선.
  final Curve curve;
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

  /// `motion.stamp` — 도장이 찍히는 순간. 이 사이클의 대표 연출이라
  /// 지속과 커브를 [MotionSpec] 한 벌로 묶어 둔다(따로 고르면 어긋난다).
  ///
  /// [emphasized](easeOutBack)는 목표를 살짝 지나쳤다 되돌아오므로 도장이
  /// 눌렸다 자리를 잡는 인상을 준다. 길이는 [base] 와 [slow] 사이 —
  /// "쿵" 이 읽힐 만큼 길고, 판으로 돌아가는 흐름을 끊지 않을 만큼 짧다.
  static const MotionSpec stamp = MotionSpec(
    duration: Duration(milliseconds: 420),
    curve: emphasized,
  );
}
