/// 스플래시 연출 — 야구공 실밥이 위아래로 벌어지고 그 사이에서 로고가
/// 튀어나온다.
///
/// 하나의 [AnimationController] 가 전체 타임라인을 돌리고, 구간마다
/// [TweenSequence] 의 가중치로 나눠 쓴다. 가중치의 단위는 밀리초라
/// [SplashTokens] 의 지속시간 토큰을 그대로 더하면 타임라인이 된다.
/// 컨트롤러를 여러 개 두지 않는 이유는 구간이 서로 겹치기 때문이다
/// (로고는 실밥이 벌어지는 도중에 등장한다).
library;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';

const String _seamTopAsset = 'assets/splash/seam_top.png';
const String _seamBottomAsset = 'assets/splash/seam_bottom.png';
const String _logoAsset = 'assets/splash/logo.png';

/// 앱 첫 진입에서 한 번 재생되는 스플래시 화면.
///
/// 연출이 끝나면 [onComplete] 를 한 번 호출한다. 다음 화면으로 넘기는
/// 판단은 호출자([SplashGate])가 한다 — 이 위젯은 연출만 책임진다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  /// 연출이 모두 끝났을 때 한 번 호출된다.
  final VoidCallback onComplete;

  /// 위 실밥 이미지에 붙는 키 (테스트에서 위치를 관찰한다).
  static const Key seamTopKey = Key('splash-seam-top');

  /// 아래 실밥 이미지에 붙는 키.
  static const Key seamBottomKey = Key('splash-seam-bottom');

  /// 로고 이미지에 붙는 키.
  static const Key logoKey = Key('splash-logo');

  /// 연출 전체 길이 — 구간 토큰의 합.
  ///
  /// 실밥 분리는 로고 등장과 겹쳐 진행되므로 합에 따로 더하지 않는다
  /// (반동 + 분리 = 750ms 로 로고 구간 안에서 끝난다).
  static Duration get totalDuration =>
      SplashTokens.seamAnticipation +
      SplashTokens.logoDelay +
      SplashTokens.logoPop +
      SplashTokens.logoBounce +
      SplashTokens.hold;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 실밥이 바깥으로 벌어진 정도 — 화면 높이 대비 비율. 음수는 안쪽(반동).
  late final Animation<double> _seamSpread;

  /// 로고 배율 — 0 이면 아직 등장 전.
  late final Animation<double> _logoScale;

  /// 로고가 떠오른 높이 — 화면 높이 대비 비율. 양수는 위쪽.
  late final Animation<double> _logoLift;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SplashScreen.totalDuration,
    );
    _seamSpread = _controller.drive(_seamSpreadTween());
    _logoScale = _controller.drive(_logoScaleTween());
    _logoLift = _controller.drive(_logoLiftTween());

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 남는 구간(연출이 끝난 뒤 머무는 시간 등)을 채우는 가중치.
  double get _totalWeight =>
      SplashScreen.totalDuration.inMilliseconds.toDouble();

  TweenSequence<double> _seamSpreadTween() {
    const spread = SplashTokens.seamSeparationFactor;
    const pullIn = -spread * SplashTokens.seamAnticipationFactor;
    final movingWeight = (SplashTokens.seamAnticipation +
            SplashTokens.seamSeparation)
        .inMilliseconds
        .toDouble();

    return TweenSequence<double>([
      // 벌어지기 전 안쪽으로 살짝 움츠린다 — 같은 거리라도 훨씬 살아난다.
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: pullIn)
            .chain(CurveTween(curve: MotionTokens.standard)),
        weight: SplashTokens.seamAnticipation.inMilliseconds.toDouble(),
      ),
      // 바깥으로 벌어진다 — 끝에서 살짝 넘쳤다 돌아온다.
      TweenSequenceItem(
        tween: Tween<double>(begin: pullIn, end: spread)
            .chain(CurveTween(curve: MotionTokens.emphasized)),
        weight: SplashTokens.seamSeparation.inMilliseconds.toDouble(),
      ),
      // 벌어진 자리에 그대로 머문다.
      TweenSequenceItem(
        tween: ConstantTween<double>(spread),
        weight: _totalWeight - movingWeight,
      ),
    ]);
  }

  TweenSequence<double> _logoScaleTween() {
    final delayWeight =
        (SplashTokens.seamAnticipation + SplashTokens.logoDelay)
            .inMilliseconds
            .toDouble();
    final restWeight = (SplashTokens.logoBounce + SplashTokens.hold)
        .inMilliseconds
        .toDouble();

    return TweenSequence<double>([
      // 실밥이 먼저 움직이는 동안 로고는 아직 없다.
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: delayWeight,
      ),
      // "띠요옹" — 탄성 커브로 튀어나온다.
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: MotionTokens.bouncy)),
        weight: SplashTokens.logoPop.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: restWeight,
      ),
    ]);
  }

  TweenSequence<double> _logoLiftTween() {
    final beforeWeight = (SplashTokens.seamAnticipation +
            SplashTokens.logoDelay +
            SplashTokens.logoPop)
        .inMilliseconds
        .toDouble();
    // 점프 한 번 = 올라갔다 내려오는 두 구간.
    final jumpWeight = SplashTokens.logoBounce.inMilliseconds /
        (SplashTokens.logoBounceCount * 2);

    final items = <TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: beforeWeight,
      ),
    ];

    var amplitude = SplashTokens.logoBounceFactor;
    for (var i = 0; i < SplashTokens.logoBounceCount; i++) {
      items.add(
        TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: amplitude)
              .chain(CurveTween(curve: MotionTokens.rise)),
          weight: jumpWeight,
        ),
      );
      items.add(
        TweenSequenceItem(
          tween: Tween<double>(begin: amplitude, end: 0)
              .chain(CurveTween(curve: MotionTokens.fall)),
          weight: jumpWeight,
        ),
      );
      // 점프마다 진폭이 줄어 잦아든다.
      amplitude *= SplashTokens.logoBounceDecay;
    }

    items.add(
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: SplashTokens.hold.inMilliseconds.toDouble(),
      ),
    );

    return TweenSequence<double>(items);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: ColorTokens.splashBackground,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final spread = _seamSpread.value * size.height;
          return Stack(
            children: [
              // 위 실밥 — 화면 위 가장자리에 붙어 있다가 위로 밀려난다.
              Positioned(
                left: 0,
                right: 0,
                top: -spread,
                child: Image.asset(
                  _seamTopAsset,
                  key: SplashScreen.seamTopKey,
                  fit: BoxFit.fitWidth,
                ),
              ),
              // 아래 실밥 — 아래 가장자리에 붙어 있다가 아래로 밀려난다.
              Positioned(
                left: 0,
                right: 0,
                bottom: -spread,
                child: Image.asset(
                  _seamBottomAsset,
                  key: SplashScreen.seamBottomKey,
                  fit: BoxFit.fitWidth,
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, -_logoLift.value * size.height),
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Image.asset(
                      _logoAsset,
                      key: SplashScreen.logoKey,
                      width: size.width * SplashTokens.logoWidthFactor,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
