import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/auth.dart';
import '../../backend/errors.dart';
import '../../design/tokens.dart';
import '../../ui/shared/social_sign_in_button.dart';

/// 로그인 화면 — 앱의 첫 화면이다.
///
/// 계정 없이 쓰는 경로가 없다는 결정([XL] 소셜 로그인 필수)이 화면 하나로
/// 드러나는 자리라, 여기에는 "나중에 하기" 같은 우회로를 두지 않는다.
/// 세 제공자 버튼은 [SocialSignInButton] 한 모양이고, 이 화면은 탭을
/// [AuthService.signIn] 까지만 잇는다 (실제 제공자 연결은 2.2·2.3).
///
/// 실패는 전부 [BackendError.from] 한 경로로 문구가 된다 — SDK 예외든,
/// 구현이 아직 주입되지 않아 provider 가 던지는 [UnimplementedError] 든
/// 같은 자리에서 화면 안내로 바뀌므로 로그인 화면에서 앱이 죽지 않는다.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.notice});

  /// 게이트가 세션을 확인하지 못했을 때 함께 띄우는 안내.
  /// null 이면 평범한 첫 진입이다.
  final String? notice;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  /// 지금 진행 중인 로그인. null 이 아니면 세 버튼이 모두 잠긴다 —
  /// 두 제공자의 흐름이 겹치면 어느 쪽 결과가 세션이 되는지가 흐려진다.
  AuthProviderId? _pending;

  /// 마지막 실패 안내. 다음 시도를 시작할 때 지운다.
  String? _failure;

  Future<void> _signIn(AuthProviderId provider) async {
    setState(() {
      _pending = provider;
      _failure = null;
    });
    String? failure;
    try {
      await ref.read(authServiceProvider).signIn(provider);
    } catch (error) {
      failure = _messageOf(BackendError.from(error));
    }
    if (!mounted) return;
    setState(() {
      _pending = null;
      _failure = failure;
    });
  }

  /// 도메인 오류 셋을 사람 말로 — 갈래가 셋인 이유가 그대로 문구가 된다.
  static String _messageOf(BackendError error) => switch (error) {
    BackendNetworkError() => '연결이 불안정해요. 잠시 뒤 다시 시도해 주세요.',
    BackendPermissionError() => '로그인이 완료되지 않았어요. 다시 시도해 주세요.',
    BackendUnknownError() => '로그인하지 못했어요. 잠시 뒤 다시 시도해 주세요.',
  };

  @override
  Widget build(BuildContext context) {
    final notice = _failure ?? widget.notice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SpaceTokens.lg,
              vertical: SpaceTokens.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('원정 가자', style: TextTokens.display),
                const SizedBox(height: SpaceTokens.sm),
                const Text(
                  '로그인하면 다녀온 구장의 도장과 찜한 장소가\n계정에 남아요.',
                  style: TextTokens.bodyMuted,
                ),
                const SizedBox(height: SpaceTokens.xxl),
                for (final provider in AuthProviderId.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SpaceTokens.md),
                    child: SocialSignInButton(
                      provider: provider,
                      onPressed: _pending == null
                          ? () => _signIn(provider)
                          : null,
                    ),
                  ),
                if (notice != null) ...[
                  const SizedBox(height: SpaceTokens.sm),
                  SignInNotice(message: notice),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 로그인 화면의 실패 안내 한 줄.
///
/// 별도 위젯인 것은 "안내가 떴다"를 게이트 테스트가 문구가 아니라 자리로
/// 잴 수 있게 하려는 것이다 — 문구는 다듬을 수 있어도 안내가 서는 자리는
/// 이 단계의 acceptance 다.
class SignInNotice extends StatelessWidget {
  const SignInNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextTokens.label.copyWith(color: ColorTokens.danger),
    );
  }
}
