import 'package:flutter/material.dart';

import '../../backend/auth.dart';
import '../../design/tokens.dart';

/// 제공자별 로그인 버튼 (구글·카카오·애플) — 원정 입장권 모양.
///
/// 세 버튼은 같은 입장권 몸통과 절취선을 공유하고, 무엇으로 로그인하는지는
/// 아이콘과 문구가 가른다. 국내 사용자에게 가장 익숙한 카카오는 노란 몸통으로
/// 첫 순서를 강조하고, 나머지 둘은 종이색 표면 위에 둔다. 제공자 색도 화면에
/// 직접 쓰지 않고 `lib/design/` 팔레트의 이름 있는 토큰에서 가져온다.
///
/// [onPressed] 가 null 이면 눌리지 않는다 — 로그인 진행 중에 다른 제공자를
/// 눌러 두 흐름이 겹치지 않게 하는 자리다. 그때 **어느 제공자로** 진행 중인지는
/// [busy] 가 말한다: 아이콘 자리에 스피너가 들어서 사용자가 누른 그 버튼에서
/// 진행 중이라는 신호가 난다. 잠긴 버튼 셋만으로는 로그인이 도는 중인지
/// 그냥 꺼진 화면인지 구분되지 않는다.
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.provider,
    this.onPressed,
    this.busy = false,
  });

  /// 이 버튼이 여는 로그인 제공자.
  final AuthProviderId provider;

  /// 누를 때. null 이면 꺼진 버튼이다.
  final VoidCallback? onPressed;

  /// 이 제공자의 로그인이 진행 중인가 — 아이콘 자리가 스피너가 된다.
  ///
  /// 진행 중인 버튼도 눌리지 않아야 하므로 [onPressed] 는 따로 비운다.
  /// 두 값을 하나로 합치지 않은 것은, 진행 중이 아니어도 잠기는 버튼(다른
  /// 제공자의 로그인이 도는 동안의 나머지 둘)이 있기 때문이다.
  final bool busy;

  /// 제공자별 버튼 문구.
  static String labelOf(AuthProviderId provider) => switch (provider) {
    AuthProviderId.google => '구글 로그인',
    AuthProviderId.apple => '애플 로그인',
    AuthProviderId.kakao => '카카오 로그인',
  };

  /// 테스트와 접근성 검사가 제공자별 실제 심볼 자리를 찾는 키.
  static Key iconKeyOf(AuthProviderId provider) =>
      ValueKey('social-sign-in-icon-${provider.name}');

  /// 진행 중 스피너에 붙는 스크린 리더 문구 — 스피너는 눈으로만 읽힌다.
  static const String busyLabel = '로그인하는 중';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = provider == AuthProviderId.kakao
        ? ColorTokens.kakao
        : colors.surface;
    final foreground = provider == AuthProviderId.kakao
        ? ColorTokens.onKakao
        : colors.onSurface;
    return AnimatedScale(
      scale: busy ? LoginTokens.busyScale : 1,
      duration: MotionTokens.fast,
      curve: MotionTokens.standard,
      child: SizedBox(
        width: double.infinity,
        height: LoginTokens.ticketHeight,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background,
            disabledForegroundColor: foreground,
            side: BorderSide(color: colors.outline),
            padding: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(RadiusTokens.md)),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: SpaceTokens.lg),
              SizedBox(
                width: LoginTokens.iconSlotWidth,
                child: Center(
                  child: busy
                      ? SizedBox.square(
                          dimension: LoginTokens.providerIconSize,
                          child: CircularProgressIndicator(
                            color: foreground,
                            semanticsLabel: busyLabel,
                          ),
                        )
                      : _ProviderIcon(
                          key: iconKeyOf(provider),
                          provider: provider,
                        ),
                ),
              ),
              const SizedBox(width: SpaceTokens.sm),
              Expanded(
                child: Text(
                  labelOf(provider),
                  textAlign: TextAlign.center,
                  style: TextTokens.bodyStrong.copyWith(color: foreground),
                ),
              ),
              CustomPaint(
                painter: _PerforationPainter(colors.outline),
                child: SizedBox(
                  width: LoginTokens.ticketStubWidth,
                  height: double.infinity,
                  child: const Icon(Icons.confirmation_number_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({super.key, required this.provider});

  final AuthProviderId provider;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: LoginTokens.providerIconSize,
      child: switch (provider) {
        AuthProviderId.google => const CustomPaint(
          painter: _GoogleMarkPainter(),
        ),
        AuthProviderId.apple => ClipRect(
          child: Transform.scale(
            scale: LoginTokens.appleSymbolScale,
            child: Image.asset('assets/auth/apple_sign_in_white.png'),
          ),
        ),
        AuthProviderId.kakao => Transform.scale(
          scale: LoginTokens.kakaoSymbolScale,
          child: FittedBox(
            fit: BoxFit.contain,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor:
                    LoginTokens.kakaoAssetHeight / LoginTokens.kakaoAssetWidth,
                child: Image.asset(
                  'assets/auth/kakao_login_medium_narrow.png',
                  width: LoginTokens.kakaoAssetWidth,
                  height: LoginTokens.kakaoAssetHeight,
                ),
              ),
            ),
          ),
        ),
      },
    );
  }
}

/// Google 이 배포한 48×48 컬러 G 벡터 경로를 크기에 맞춰 그린다.
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);

    _draw(
      canvas,
      Path()
        ..moveTo(24, 9.5)
        ..relativeCubicTo(3.54, 0, 6.71, 1.22, 9.21, 3.6)
        ..relativeLineTo(6.85, -6.85)
        ..cubicTo(35.9, 2.38, 30.47, 0, 24, 0)
        ..cubicTo(14.62, 0, 6.51, 5.38, 2.56, 13.22)
        ..relativeLineTo(7.98, 6.19)
        ..cubicTo(12.43, 13.72, 17.74, 9.5, 24, 9.5)
        ..close(),
      ColorTokens.googleRed,
    );
    _draw(
      canvas,
      Path()
        ..moveTo(46.98, 24.55)
        ..relativeCubicTo(0, -1.57, -0.15, -3.09, -0.38, -4.55)
        ..lineTo(24, 20)
        ..relativeLineTo(0, 9.02)
        ..relativeLineTo(12.94, 0)
        ..relativeCubicTo(-0.58, 2.96, -2.26, 5.48, -4.78, 7.18)
        ..relativeLineTo(7.73, 6)
        ..cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55)
        ..close(),
      ColorTokens.googleBlue,
    );
    _draw(
      canvas,
      Path()
        ..moveTo(10.53, 28.59)
        ..relativeCubicTo(-0.48, -1.45, -0.76, -2.99, -0.76, -4.59)
        ..relativeCubicTo(0, -1.6, 0.27, -3.14, 0.76, -4.59)
        ..relativeLineTo(-7.98, -6.19)
        ..cubicTo(0.92, 16.46, 0, 20.12, 0, 24)
        ..relativeCubicTo(0, 3.88, 0.92, 7.54, 2.56, 10.78)
        ..relativeLineTo(7.97, -6.19)
        ..close(),
      ColorTokens.googleYellow,
    );
    _draw(
      canvas,
      Path()
        ..moveTo(24, 48)
        ..relativeCubicTo(6.48, 0, 11.93, -2.13, 15.89, -5.81)
        ..relativeLineTo(-7.73, -6)
        ..relativeCubicTo(-2.15, 1.45, -4.92, 2.3, -8.16, 2.3)
        ..relativeCubicTo(-6.26, 0, -11.57, -4.22, -13.47, -9.91)
        ..relativeLineTo(-7.98, 6.19)
        ..cubicTo(6.51, 42.62, 14.62, 48, 24, 48)
        ..close(),
      ColorTokens.googleGreen,
    );
    canvas.restore();
  }

  void _draw(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) => false;
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = LoginTokens.perforationWidth;
    for (var y = 0.0; y < size.height; y += LoginTokens.perforationDash * 2) {
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset.zero.translate(
          0,
          (y + LoginTokens.perforationDash).clamp(0, size.height),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter oldDelegate) =>
      oldDelegate.color != color;
}
