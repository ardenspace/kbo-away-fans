/// 온보딩 팀 선택 직후의 위치 권한 요청 — step 2.5.
///
/// **왜 이 자리인가.** 팀을 고른 순간부터 홈 상단의 "지금 위치" 표시(5.2)와
/// 구장 도장 판정(4.1)이 위치를 쓴다. 그 전에 한 번, 용도(구장 도장·현재 위치
/// 표시)를 말로 설명하고 권한을 묻는다 — 배지 탭에서 처음 묻는 방식보다 팀
/// 선택을 마쳐 맥락이 생긴 이 자리가 수락률이 높다는 판단
/// (`.wellbegun/decisions.md` 2026-09-01 [M]).
///
/// **거절해도 앱은 그대로 동작한다.** 이 화면이 하는 일은 설명과 요청
/// 하나뿐이다 — 결과가 [LocationPermissionStatus.granted] 든
/// [LocationPermissionStatus.denied] 든 [OnboardingLocationGate] 는 곧장
/// 홈으로 넘어간다. 위치 권한을 요구 조건으로 두는 화면이 이 앱에는 없다.
///
/// **뜨는 신호와 뜨는 시점이 한 자리가 아니다.** [OnboardingLocationGate] 는
/// 팀이 정해진 그 순간 이미 홈을 그리고 있다 — 선택은 낙관적으로 먼저
/// 반영되고([SelectedTeamNotifier.select]), "온보딩에서 방금 새 문서가
/// 만들어졌다"는 사실은 서버 왕복 뒤에야 안다
/// ([onboardingJustOnboardedProvider]). 그래서 이 게이트는 그 신호를
/// `ref.watch` 로 구독해 매 빌드마다 현재값을 본다(`ref.listen` 이 아니다 —
/// 등록 **뒤의 변화**만 잡는 `listen` 은, 신호가 이 위젯이 처음 그려지기도
/// 전에 이미 서 버리는 실행에서 그 사실을 놓친다). 신호가 참인 것을 본
/// 프레임이 끝나면(빌드 도중에 다른 provider 를 고칠 수 없어 한 프레임
/// 미룬다) 신호를 끄고 검사를 시작한다 — 이미 홈을 그리고 있던 뒤라도. 신호가
/// 끝내 서지 않는 렌더(팀을 이미 갖고 있던 정상적인 재실행, 실패해 되돌아간
/// 선택, 이미 있는 문서로 물러선 선택, 변경 모드)는 검사를 시작하지 않고
/// 홈에 그대로 머무른다 — 위치를 다시 묻거나 새로 묻는 일이 없다.
///
/// **알아내지 못한 실행도 사람을 붙잡지 않는다.** 위치 권한 조회가 던지거나
/// 끝나지 않으면 `resolveLocationPermission` 이 `kLocationPermissionTimeout`
/// 에서 잘라 [LocationPermissionStatus.denied] 로 답한다 — 대기 화면은 그
/// 상한을 넘겨 남지 않고, 설명 화면의 두 버튼은 요청이 실패한 실행에서도
/// 홈으로 이어진다.
///
/// **이미 결정된 상태에서는 이 화면조차 뜨지 않는다.**
/// [LocationPermissionGateway.status] 가 이미 결정된 값(허용·영구 거절)을
/// 돌려주면 검사만 하고 곧장 홈으로 간다 — 다시 물어도 OS 가 다이얼로그를
/// 띄우지 않을 상태에서 우리 설명 화면만 한 번 더 보여줄 이유가 없다.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../location/location.dart';
import '../../ui/shared/content_fallback.dart';
import '../home/main_tabs_root.dart';
import '../team_select/selected_team.dart';

/// 팀이 정해진 뒤의 위치 권한 안내 게이트 — 대부분의 렌더는 곧장 [MainTabsRoot]
/// (step 3.1 이전에는 홈 화면 하나였다).
class OnboardingLocationGate extends ConsumerStatefulWidget {
  const OnboardingLocationGate({super.key});

  @override
  ConsumerState<OnboardingLocationGate> createState() =>
      _OnboardingLocationGateState();
}

enum _Stage { home, checking, ask }

class _OnboardingLocationGateState
    extends ConsumerState<OnboardingLocationGate> {
  /// 기본은 홈이다. 정상적으로 팀을 이미 갖고 있던 렌더(온보딩 신호가 끝내
  /// 서지 않는 렌더)는 이 상태에서 한 발도 움직이지 않는다.
  _Stage _stage = _Stage.home;

  /// 온보딩 신호를 이미 처리하기 시작했는가 — 같은 신호로 검사를 두 번
  /// 예약하지 않기 위한 안쪽 표시일 뿐, 신호 자체([onboardingJustOnboardedProvider])를
  /// 끄는 자리는 아니다(그 자리는 [_beginLocationCheck]).
  bool _handling = false;

  @override
  Widget build(BuildContext context) {
    // `ref.watch` 로 읽는다 — `ref.listen` 은 등록된 **뒤의 변화**만 잡는데,
    // 신호가 서는 시점과 이 위젯이 처음 그려지는 시점의 순서가 실행마다
    // 다르다: 선택은 낙관적으로 먼저 반영되므로 이 위젯은 신호가 서기 **전에**
    // 만들어질 수 있지만(실 서버 왕복처럼 그 사이에 실제 시간차가 있는
    // 실행), 대역처럼 그 왕복이 마이크로태스크 몇 번으로 끝나는 실행에서는
    // 신호가 이 위젯이 처음 그려지기 **전에** 이미 서 버린다 — 그 경우
    // `ref.listen` 은 "이미 참인 값"을 놓친다. `watch` 는 등록 시점의 현재값을
    // 그대로 돌려주므로 두 순서 모두에서 옳다.
    final justOnboarded = ref.watch(onboardingJustOnboardedProvider);
    if (justOnboarded && !_handling) {
      _handling = true;
      // 신호를 끄고 검사를 시작하는 일은 프레임이 끝난 뒤로 미룬다 — build
      // 도중에 다른 provider(`onboardingJustOnboardedProvider`)의 상태를
      // 고치면 "빌드 중에 provider 를 바꿨다"는 오류가 난다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // 본 즉시 끈다 — 같은 세션에서 홈이 다시 그려져도 두 번 뜨지 않는다.
        ref.read(onboardingJustOnboardedProvider.notifier).consume();
        _beginLocationCheck();
      });
    }

    return switch (_stage) {
      _Stage.home => const MainTabsRoot(),
      // OS 에 상태를 물어보는 짧은 구간 — 로스터에 있는 단일 로딩 모습을
      // 재사용한다.
      _Stage.checking => const Scaffold(body: ContentFallback(loading: true)),
      _Stage.ask => LocationConsentScreen(
          onAllow: _requestAndFinish,
          onSkip: _finish,
        ),
    };
  }

  void _beginLocationCheck() {
    setState(() => _stage = _Stage.checking);
    unawaited(_checkStatus());
  }

  Future<void> _checkStatus() async {
    // 게이트웨이는 **갈아 끼우는 이음매**다 — 이 화면은 자기가 받은 구현이
    // 던지지 않는지, 답하기는 하는지 확인할 방법이 없다. 그래서 이 계층의
    // 실패 계약(`resolveLocationPermission`)을 화면 쪽에서도 한 번 통과시킨다:
    // 알아내지 못한 실행은 `denied` 로 흘러가고, 사람은 대기 화면에 갇히는
    // 대신 설명 화면에서 두 버튼 중 하나로 나간다.
    final status = await resolveLocationPermission(
      () => ref.read(locationPermissionGatewayProvider).status(),
    );
    if (!mounted) return;
    if (status == LocationPermissionStatus.denied) {
      // 아직 결정되지 않았거나 다시 물어볼 수 있는 상태 — 설명을 먼저 보여준다.
      setState(() => _stage = _Stage.ask);
    } else {
      // 이미 허용됐거나 영구 거절된 상태 — 화면을 한 번 더 보여줄 이유가 없다.
      _finish();
    }
  }

  Future<void> _requestAndFinish() async {
    await resolveLocationPermission(
      () => ref.read(locationPermissionGatewayProvider).request(),
    );
    // 허용이든 거절이든, 아예 알아내지 못했든 결과와 무관하게 홈으로 넘어간다 —
    // 위치 권한은 이 앱의 어떤 화면도 막지 않고, 요청이 실패한 실행에서 버튼이
    // 침묵한 채 남는 일도 없다.
    _finish();
  }

  void _finish() {
    if (!mounted) return;
    setState(() => _stage = _Stage.home);
  }
}

/// 위치 권한 설명 + 요청 화면 — 문구·형태는 이 단계의 재량.
class LocationConsentScreen extends StatelessWidget {
  const LocationConsentScreen({
    super.key,
    required this.onAllow,
    required this.onSkip,
  });

  /// "위치 권한 허용하기" — OS 요청까지 이어간다.
  final Future<void> Function() onAllow;

  /// "나중에 할게요" — OS 에 묻지 않고 곧장 넘어간다.
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SpaceTokens.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 64,
                color: ColorTokens.textPrimary,
              ),
              const SizedBox(height: SpaceTokens.lg),
              const Text(
                '위치 권한이 필요해요',
                style: TextTokens.display,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpaceTokens.md),
              const Text(
                '구장에 도착하면 자동으로 도장을 찍어 드리고,\n'
                '홈 화면에 지금 계신 곳을 보여드릴 때만 위치를 써요.',
                style: TextTokens.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SpaceTokens.xl),
              ElevatedButton(
                onPressed: onAllow,
                child: const Text('위치 권한 허용하기'),
              ),
              const SizedBox(height: SpaceTokens.sm),
              TextButton(
                onPressed: onSkip,
                child: const Text('나중에 할게요'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
