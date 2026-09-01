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

  /// 제공자 로그인은 성공했는데 세션이 서지 않았을 때의 안내.
  ///
  /// "로그인하지 못했어요"라고 하지 않는 것은 사용자가 제공자 화면에서 실제로
  /// 로그인을 마쳤기 때문이다 — 무엇이 남았는지를 말해야 다시 눌러 볼 수 있다.
  static const String sessionMissingMessage = '로그인 상태를 세우지 못했어요. 다시 시도해 주세요.';

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  /// 이 화면이 시작한 로그인. 진행 중이거나 이미 성공해서 게이트가 화면을
  /// 걷어가기를 기다리는 동안 null 이 아니고, 그동안 세 버튼이 모두 잠긴다 —
  /// 두 제공자의 흐름이 겹치면 어느 쪽 결과가 세션이 되는지가 흐려진다.
  /// 실패로 끝났을 때만 다시 null 이 된다.
  AuthProviderId? _pending;

  /// 마지막 실패 안내. 다음 시도를 시작할 때 지운다.
  String? _failure;

  Future<void> _signIn(AuthProviderId provider) async {
    // 잠금을 `_pending` → rebuild → `onPressed: null` 경로에만 기대면 같은
    // 프레임에 도착한 두 번째 탭(두 손가락 동시 탭)이 그대로 통과한다.
    // 결정("진행 중이면 셋 다 잠근다")을 지키는 자리는 핸들러 안쪽이다 —
    // `LikeButton` 이 연타를 막은 방식과 같다.
    if (_pending != null) return;
    setState(() {
      _pending = provider;
      _failure = null;
    });
    String? failure;
    var signedIn = false;
    try {
      await ref.read(authServiceProvider).signIn(provider);
      signedIn = true;
    } catch (error) {
      failure = _messageOf(BackendError.from(error));
    }
    if (!mounted) return;
    if (signedIn) {
      // 세션 상태를 다시 세운다. 세션 스트림은 오류와 함께 끝나기도 하는데
      // (권한을 잃은 스냅샷 스트림이 그렇다) 그러면 provider 가 죽은 구독을
      // 든 채 남아, 다시 로그인해도 게이트가 넘어가지 않는다. 자동 재시도를
      // 끈 결정은 그대로 두고, 다시 세우는 시점만 사람의 행동인 이 자리에
      // 붙인다.
      ref.invalidate(authStateProvider);

      // 그리고 다시 세운 상태를 **읽어서** 세션이 실제로 섰는지 본다.
      // `signIn` 이 성공을 돌려줬다는 것과 세션이 섰다는 것은 같은 사실이
      // 아니다 (커스텀 토큰 교환이 성공한 뒤 세션 수립이 조용히 실패하는
      // 자리가 2.3 에 있다). 세션이 서지 않았는데 성공으로 두면 게이트가
      // 화면을 걷어가지 않고, 잠금을 푸는 자리가 게이트뿐이라 화면이 영구히
      // 죽는다 — 앱을 다시 켜는 것 말고 나갈 길이 없어진다.
      if (await _sessionStands()) {
        // 세션이 섰다. 잠금은 풀지 않는다 — 이 화면은 게이트가 곧 걷어내므로
        // 여기서 더 할 일이 없고, 푸는 순간 게이트가 화면을 바꾸기 전(아직 한
        // 프레임도 그리지 않은 사이)에 들어온 탭이 두 번째 로그인을 연다.
        return;
      }
      if (!mounted) return;
      failure = SignInScreen.sessionMissingMessage;
    }
    setState(() {
      _pending = null;
      _failure = failure;
    });
  }

  /// 다시 세운 [authStateProvider] 의 첫 값이 로그인한 사용자인가.
  ///
  /// 시간을 추측하지 않는다(타임아웃도, 프레임 세기도 아니다) — provider 가
  /// 내놓는 첫 값을 그대로 기다려 읽는다. 그 값이 null 이거나 상태가 오류면
  /// 세션이 서지 않은 것이다.
  Future<bool> _sessionStands() async {
    try {
      return await ref.read(authStateProvider.future) != null;
    } catch (_) {
      // 세션 상태를 확인하지 못한 것도 "섰다"고 볼 수는 없다. 여기서 나온
      // 실패는 게이트가 안내와 함께 로그인 화면으로 받는 그 실패와 같다.
      return false;
    }
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
                      // 진행 중이면 셋 다 잠기고, 진행 중이라는 사실은 사용자가
                      // 누른 그 버튼의 스피너가 말한다 — 잠긴 버튼 셋만 남으면
                      // 로그인이 도는 중인지 화면이 죽은 것인지 알 수 없다.
                      busy: _pending == provider,
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
