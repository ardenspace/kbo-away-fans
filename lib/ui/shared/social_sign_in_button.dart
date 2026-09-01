import 'package:flutter/material.dart';

import '../../backend/auth.dart';
import '../../design/tokens.dart';

/// 제공자별 로그인 버튼 (구글·카카오·애플) 한 모양.
///
/// 세 버튼이 같은 몸통(팔레트의 면 색 + 경계선)으로 서고, 무엇으로 로그인하는지는
/// **아이콘과 문구**가 가른다. 제공자 브랜드 색을 몸통에 칠하지 않는 이유는,
/// 그 색들이 `lib/design/` 팔레트 밖의 새 색이라 이 골격 단계에서 들이면
/// 토큰 밖 색이 화면 코드에 눌러앉기 때문이다. 브랜드 자산은 실제 로그인이
/// 붙는 단계(phase 2)에서 각 제공자의 표기 지침과 함께 들어온다.
///
/// [onPressed] 가 null 이면 눌리지 않는다 — 로그인 진행 중에 다른 제공자를
/// 눌러 두 흐름이 겹치지 않게 하는 자리다.
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.provider,
    this.onPressed,
  });

  /// 이 버튼이 여는 로그인 제공자.
  final AuthProviderId provider;

  /// 누를 때. null 이면 꺼진 버튼이다.
  final VoidCallback? onPressed;

  /// 제공자별 버튼 문구.
  static String labelOf(AuthProviderId provider) => switch (provider) {
    AuthProviderId.google => '구글로 시작하기',
    AuthProviderId.apple => '애플로 시작하기',
    AuthProviderId.kakao => '카카오로 시작하기',
  };

  /// 제공자별 아이콘 — 색이 같은 세 버튼을 가르는 신호라 서로 달라야 한다.
  static IconData iconOf(AuthProviderId provider) => switch (provider) {
    AuthProviderId.google => Icons.g_mobiledata_rounded,
    AuthProviderId.apple => Icons.apple_rounded,
    AuthProviderId.kakao => Icons.chat_bubble_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(iconOf(provider)),
        label: Text(labelOf(provider), style: TextTokens.bodyStrong),
        style: OutlinedButton.styleFrom(
          backgroundColor: ColorTokens.surface,
          foregroundColor: ColorTokens.textPrimary,
          side: const BorderSide(color: ColorTokens.outline),
          padding: const EdgeInsets.symmetric(
            horizontal: SpaceTokens.lg,
            vertical: SpaceTokens.md,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(RadiusTokens.md)),
          ),
        ),
      ),
    );
  }
}
