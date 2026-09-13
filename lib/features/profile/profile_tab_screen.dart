import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/auth.dart';
import '../../backend/user_data.dart';
import '../../design/tokens.dart';
import '../../ui/shared/content_fallback.dart';
import '../../ui/shared/team_theme_scope.dart';
import '../../ui/shared/team_themed_app_bar.dart';
import '../../ui/shared/theme_settings_sheet.dart';
import 'theme_settings.dart';

/// 마이페이지 탭 (step 3.4) — 닉네임·대표 이메일을 보여주고
/// 닉네임을 바꿀 수 있게 하며 로그아웃 진입점을 둔다.
/// `lib/features/home/main_tabs_root.dart` 의 마이페이지 탭 자리를 채운다.
///
/// - **탭 뿌리가 provider 를 직접 구독한다** ([RecommendTabScreen]·
///   [LikesTabScreen] 이 세운 규칙과 같다 — `MainTabScaffold` 의 탭별
///   Navigator 는 route 를 한 번만 만들기 때문에, 이 화면이 생성자 인자로
///   프로필을 받으면 그 값이 얼어붙어 닉네임을 바꾼 뒤에도 화면이 갱신되지
///   않는다).
/// - **이메일이 없는 계정은 빈칸이 아니라 제공자 표시로 대신한다.** 지금
///   이메일을 주지 않는 제공자는 카카오뿐이다(`AuthUser` 문서 참조) — 구글·
///   애플은 계정이 서는 순간 이메일이 Firebase 에 영구히 남는다. 그래서
///   일반화된 제공자 추론 없이 "이메일이 없으면 카카오 문구"로 고정한다.
/// - 로그인 기기 관리는 없다(non-goal) — 로그아웃은 [AuthService.signOut] 을
///   부르는 것으로 끝나고, 그 뒤의 화면 전환은 `lib/app.dart` 의 `RootGate` 가
///   맡는다(로그인에서 벗어나는 순간 게이트 위 route 를 내리고 로그인 화면을
///   보여준다). 이 화면은 그 전환을 기다리지 않는다 — 실패했을 때만 여기서
///   안내한다.
class ProfileTabScreen extends ConsumerWidget {
  const ProfileTabScreen({super.key});

  /// 앱바 제목.
  static const String title = '마이페이지';

  /// 닉네임 수정 진입점의 접근성 이름.
  static const String nicknameEditTooltip = '닉네임 수정';

  /// 닉네임 저장 버튼.
  static const String nicknameSaveLabel = '저장';

  /// 닉네임 편집 취소 버튼.
  static const String nicknameCancelLabel = '취소';

  /// 길이 계약(UTF-16 코드 단위 1~20)을 벗어난 닉네임의 안내.
  static String get nicknameLengthError =>
      '닉네임은 $kNicknameMinLength~$kNicknameMaxLength자로 입력해 주세요.';

  /// 닉네임 쓰기가 서버에 남지 못했을 때의 안내.
  static const String nicknameSaveFailureNotice =
      '닉네임을 저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.';

  /// 대표 이메일 구역 제목.
  static const String emailSectionTitle = '이메일';

  /// 화면 테마 설정 진입점의 접근성 이름.
  static const String themeSettingsTooltip = '화면 테마 설정';

  /// 테마 설정이 서버에 남지 못했을 때의 안내.
  static const String themeSaveFailureNotice =
      '테마 설정을 저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.';

  /// 이메일을 주지 않는 계정(카카오)의 자리 표시 — 빈칸이 아니라 이 문구로
  /// 대신한다.
  static const String noEmailProviderLabel = '카카오 계정으로 로그인했어요';

  /// 로그아웃 버튼.
  static const String signOutLabel = '로그아웃';

  /// 로그아웃이 실패했을 때의 안내.
  static const String signOutFailureNotice = '로그아웃하지 못했어요. 잠시 뒤 다시 시도해 주세요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    return switch (profileAsync) {
      AsyncData(value: final profile?) => _ProfileBody(profile: profile),
      AsyncError() => Scaffold(
        appBar: AppBar(title: const Text(title)),
        body: ContentFallback(
          loading: false,
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
      ),
      // 로딩(콜드 스타트의 세션·문서 확정 대기) 또는 문서가 아직 없는 구간
      // (이 탭에 닿는 이상 게이트가 이미 온보딩을 마쳤음을 보장하지만, 재구독
      // 순간처럼 한 프레임 비어 있을 수 있는 자리는 조용히 대기 화면으로
      // 넘긴다 — `_HomeTab` 이 같은 자리에서 쓰는 것과 같은 판단이다).
      _ => const Scaffold(body: ContentFallback(loading: true)),
    };
  }
}

/// 문서가 확정된 뒤의 실제 화면 — 편집 중인 닉네임처럼 서버 스트림과 무관한
/// 로컬 상태를 여기서 든다.
class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _editingNickname = false;
  bool _nicknameSaving = false;
  String? _nicknameFieldError;
  late final TextEditingController _nicknameController = TextEditingController(
    text: widget.profile.nickname,
  );

  bool _signingOut = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final user = ref.watch(authStateProvider).value;

    final scaffold = Scaffold(
      appBar: TeamThemedAppBar(
        title: ProfileTabScreen.title,
        actions: [
          IconButton(
            key: const ValueKey('profile-theme-settings'),
            tooltip: ProfileTabScreen.themeSettingsTooltip,
            icon: const Icon(Icons.palette_outlined),
            onPressed: _openThemeSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SpaceTokens.lg),
          children: [
            _nicknameSection(profile),
            const SizedBox(height: SpaceTokens.xl),
            const Text(
              ProfileTabScreen.emailSectionTitle,
              style: TextTokens.label,
            ),
            const SizedBox(height: SpaceTokens.xs),
            Text(
              user?.email ?? ProfileTabScreen.noEmailProviderLabel,
              style: TextTokens.bodyMuted,
            ),
            const SizedBox(height: SpaceTokens.xxl),
            const Divider(),
            const SizedBox(height: SpaceTokens.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('profile-sign-out'),
                onPressed: _signingOut ? null : _signOut,
                child: _signingOut
                    ? const SizedBox(
                        width: SpaceTokens.lg,
                        height: SpaceTokens.lg,
                        child: CircularProgressIndicator(
                          strokeWidth: ProfileTokens.spinnerStrokeWidth,
                        ),
                      )
                    : Text(
                        ProfileTabScreen.signOutLabel,
                        style: TextTokens.label.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
    final teamId = profile.favoriteTeamId;
    return teamId == null
        ? scaffold
        : TeamThemeScope.forTeam(teamId: teamId, child: scaffold);
  }

  Future<void> _openThemeSettings() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final settings = ref.watch(themeSettingsProvider);
          return ThemeSettingsSheet(
            selectedFamily: settings.family,
            brightnessMode: settings.brightnessMode,
            onFamilyChanged: (family) {
              unawaited(
                _saveThemeSetting(
                  ref.read(themeSettingsProvider.notifier).setFamily(family),
                  messenger,
                ),
              );
            },
            onBrightnessModeChanged: (mode) {
              unawaited(
                _saveThemeSetting(
                  ref
                      .read(themeSettingsProvider.notifier)
                      .setBrightnessMode(mode),
                  messenger,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _saveThemeSetting(
    Future<void> saved,
    ScaffoldMessengerState? messenger,
  ) async {
    try {
      await saved;
    } on Object {
      messenger?.showSnackBar(
        const SnackBar(content: Text(ProfileTabScreen.themeSaveFailureNotice)),
      );
    }
  }

  // -------------------------------------------------------------------------
  // 닉네임
  // -------------------------------------------------------------------------

  Widget _nicknameSection(UserProfile profile) {
    if (!_editingNickname) {
      return Row(
        children: [
          Expanded(
            child: Text(
              profile.nickname,
              key: const ValueKey('profile-nickname-text'),
              style: TextTokens.title,
            ),
          ),
          IconButton(
            key: const ValueKey('profile-nickname-edit'),
            tooltip: ProfileTabScreen.nicknameEditTooltip,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              _nicknameController.text = profile.nickname;
              setState(() {
                _editingNickname = true;
                _nicknameFieldError = null;
              });
            },
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('profile-nickname-field'),
          controller: _nicknameController,
          autofocus: true,
          style: TextTokens.body,
          decoration: InputDecoration(errorText: _nicknameFieldError),
        ),
        const SizedBox(height: SpaceTokens.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _nicknameSaving
                  ? null
                  : () => setState(() => _editingNickname = false),
              child: const Text(ProfileTabScreen.nicknameCancelLabel),
            ),
            const SizedBox(width: SpaceTokens.sm),
            FilledButton(
              key: const ValueKey('profile-nickname-save'),
              onPressed: _nicknameSaving ? null : () => _saveNickname(profile),
              child: _nicknameSaving
                  ? const SizedBox(
                      width: SpaceTokens.lg,
                      height: SpaceTokens.lg,
                      child: CircularProgressIndicator(
                        strokeWidth: ProfileTokens.spinnerStrokeWidth,
                      ),
                    )
                  : const Text(ProfileTabScreen.nicknameSaveLabel),
            ),
          ],
        ),
      ],
    );
  }

  /// 닉네임 길이 계약(UTF-16 코드 단위 1~20)을 화면에서도 잰다. `runes` 로
  /// 세지 않는 이유는 `lib/backend/user_data.dart` 의 `kNicknameMaxLength`
  /// 문서와 같다 — 규칙의 `nickname.size()` 와 같은 단위(UTF-16)로 맞춰야
  /// 화면이 통과시킨 값이 서버에서 다시 거부되지 않는다.
  String? _nicknameError(String value) {
    final length = value.length;
    if (length < kNicknameMinLength || length > kNicknameMaxLength) {
      return ProfileTabScreen.nicknameLengthError;
    }
    return null;
  }

  Future<void> _saveNickname(UserProfile profile) async {
    final trimmed = _nicknameController.text.trim();
    final error = _nicknameError(trimmed);
    if (error != null) {
      setState(() => _nicknameFieldError = error);
      return;
    }
    setState(() {
      _nicknameSaving = true;
      _nicknameFieldError = null;
    });
    try {
      await ref
          .read(userDataStoreProvider)
          .patchProfile(profile.uid, UserProfilePatch(nickname: trimmed));
      if (!mounted) return;
      setState(() {
        _editingNickname = false;
        _nicknameSaving = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _nicknameSaving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(ProfileTabScreen.nicknameSaveFailureNotice),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // 로그아웃
  // -------------------------------------------------------------------------

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
      // 성공하면 여기서 더 할 일이 없다 — `RootGate` 가 세션 전이를 보고
      // 이 탭째로 화면을 걷어간다. 잠금을 풀지 않는 것은 `SignInScreen` 이
      // 로그인 성공 뒤에 잠금을 유지하는 것과 같은 이유다: 걷어가기 전(아직
      // 한 프레임도 그리지 않은 사이) 들어온 탭이 두 번째 로그아웃 호출을
      // 열지 않게 한다.
    } on Object {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(ProfileTabScreen.signOutFailureNotice)),
      );
    }
  }
}
