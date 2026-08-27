/// 스플래시 연출 — 빈 화면에 로고가 꽂히고, 그 충격으로 실밥이 들이닥친다.
///
/// 로고는 보는 사람 코앞([SplashTokens.logoStartDepth])에서 출발해 화면
/// 평면으로 꽂힌다. 단순한 확대·축소가 아니라 원근이 들어간 [Matrix4] 라
/// 실제로 z축을 지나오는 것처럼 보인다. 세 프레임 만에 끝나는 움직임이라
/// 남은 거리에 비례하는 흐림([SplashTokens.logoMotionBlur])을 걸어야
/// 날아온 것으로 읽힌다.
///
/// 닿는 순간 두 가지가 동시에 일어난다. 화면 전체가 진폭이 줄어드는
/// 진동으로 흔들리고, 그때까지 화면 밖에 있던 실밥 두 가닥이 서로 반대
/// 쪽에서 밀려 들어온다. 진입 방향은 실밥 그림의 기울기와 같아서
/// ([SplashTokens.seamSlantSlope]) 옆으로 미끄러지는 것이 아니라 제
/// 각도를 따라 비스듬히 들어온다. 위 실밥은 왼쪽 아래에서 올라오고,
/// 아래 실밥은 오른쪽 위에서 내려온다.
///
/// 하나의 [AnimationController] 가 전체 타임라인을 돌리고, 구간마다
/// [TweenSequence] 의 가중치로 나눠 쓴다. 가중치의 단위는 밀리초라
/// [SplashTokens] 의 지속시간 토큰을 그대로 더하면 타임라인이 된다.
/// 컨트롤러를 여러 개 두지 않는 이유는 구간이 서로 겹치기 때문이다
/// (흔들림과 실밥 진입이 같은 순간 시작된다).
library;

import 'dart:math' show pi, sin;
import 'dart:ui' show ImageFilter;

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

  /// 연출 전체 길이.
  ///
  /// 흔들림과 실밥 진입은 착지 순간 나란히 시작하므로 더하지 않고 둘 중
  /// 긴 쪽만 센다.
  static Duration get totalDuration =>
      impactAt + _afterImpact + SplashTokens.hold;

  /// 로고가 화면에 닿는 시점 — 흔들림과 실밥 진입이 함께 시작되는 순간이다.
  static Duration get impactAt =>
      SplashTokens.logoDelay + SplashTokens.logoSlam;

  static Duration get _afterImpact =>
      SplashTokens.shake > SplashTokens.seamEntry
      ? SplashTokens.shake
      : SplashTokens.seamEntry;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 실밥이 들어온 정도 — 0 이면 아직 화면 밖, 1 이면 제자리다.
  late final Animation<double> _seamEntry;

  /// 로고의 깊이 (논리 픽셀). 음수면 보는 사람 쪽에 떠 있고, 0 이면 착지다.
  late final Animation<double> _logoDepth;

  /// 로고의 불투명도.
  late final Animation<double> _logoOpacity;

  /// 흔들림 진행도 — 0 이 충돌 순간, 1 이 완전히 잦아든 상태다.
  late final Animation<double> _shakeProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SplashScreen.totalDuration,
    );
    _seamEntry = _controller.drive(_seamEntryTween());
    _logoDepth = _controller.drive(_logoDepthTween());
    _logoOpacity = _controller.drive(_logoOpacityTween());
    _shakeProgress = _controller.drive(_shakeProgressTween());

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

  TweenSequence<double> _seamEntryTween() {
    return TweenSequence<double>([
      // 착지 전까지 실밥은 화면 밖에 있어 보이지 않는다.
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: _beforeImpactWeight,
      ),
      // 충격과 함께 밀려 들어와 제자리에서 멎는다.
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: MotionTokens.standard)),
        weight: SplashTokens.seamEntry.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight:
            _totalWeight -
            _beforeImpactWeight -
            SplashTokens.seamEntry.inMilliseconds,
      ),
    ]);
  }

  /// 착지 전까지의 가중치 — 로고가 아직 날아오는 중인 구간.
  double get _beforeImpactWeight =>
      SplashScreen.impactAt.inMilliseconds.toDouble();

  TweenSequence<double> _logoDepthTween() {
    final delayWeight = SplashTokens.logoDelay.inMilliseconds.toDouble();

    return TweenSequence<double>([
      // 빈 화면이 유지되는 동안 로고는 코앞에 떠 있다(아직 투명하다).
      TweenSequenceItem(
        tween: ConstantTween<double>(SplashTokens.logoStartDepth),
        weight: delayWeight,
      ),
      // 첫 프레임에 거리 대부분을 지나가고 급격히 감속하며 꽂힌다.
      TweenSequenceItem(
        tween: Tween<double>(
          begin: SplashTokens.logoStartDepth,
          end: 0,
        ).chain(CurveTween(curve: MotionTokens.swoop)),
        weight: SplashTokens.logoSlam.inMilliseconds.toDouble(),
      ),
      // 꽂힌 자리에 그대로 있는다.
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: _totalWeight - _beforeImpactWeight,
      ),
    ]);
  }

  TweenSequence<double> _logoOpacityTween() {
    final delayWeight = SplashTokens.logoDelay.inMilliseconds.toDouble();
    final fadeWeight =
        SplashTokens.logoSlam.inMilliseconds * SplashTokens.logoFadeInRatio;

    return TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: delayWeight),
      // 날아오는 앞부분에서 또렷해진다 — 큰 로고가 불쑥 나타나지 않게.
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: MotionTokens.standard)),
        weight: fadeWeight,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: _totalWeight - delayWeight - fadeWeight,
      ),
    ]);
  }

  TweenSequence<double> _shakeProgressTween() {
    return TweenSequence<double>([
      // 착지 전에는 흔들리지 않는다.
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: _beforeImpactWeight,
      ),
      // 착지 순간부터 선형으로 흐른다 — 진폭 감쇠는 그리는 쪽에서 준다.
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1),
        weight: SplashTokens.shake.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: SplashTokens.hold.inMilliseconds.toDouble(),
      ),
    ]);
  }

  /// 흔들림 변위 — 진폭이 제곱으로 줄어드는 감쇠 진동이다.
  ///
  /// 진행도 0 과 1 에서 모두 변위가 0 이라 앞뒤 구간과 매끄럽게 이어진다
  /// (0 에서는 sin 이 0, 1 에서는 감쇠가 0). 가로에 위상차를 주면 충돌
  /// 순간 화면이 옆으로 툭 튀므로, 대신 두 배 빠른 진동을 써서 0 에서
  /// 출발하면서도 세로와 다른 리듬을 갖게 한다.
  Offset _shakeOffset(Size size) {
    final t = _shakeProgress.value;
    final decay = (1 - t) * (1 - t);
    final phase = 2 * pi * SplashTokens.shakeOscillations * t;
    final amplitude = SplashTokens.shakeFactor * size.width * decay;
    return Offset(
      amplitude * SplashTokens.shakeLateralRatio * sin(2 * phase),
      amplitude * sin(phase),
    );
  }

  /// 날아드는 로고 — 원근 행렬로 깊이를 주고, 남은 거리만큼 흐려 놓는다.
  ///
  /// 흐림은 착지 순간 정확히 0 이 되고, 그때는 [ImageFiltered] 자체를
  /// 걷어낸다. sigma 0 인 필터를 매 프레임 태우면 착지 후 내내 쓸데없는
  /// 필터 레이어를 그리게 된다.
  Widget _logo(Size size) {
    final depth = _logoDepth.value;
    final sigma =
        depth.abs() /
        SplashTokens.logoStartDepth.abs() *
        SplashTokens.logoMotionBlur;

    Widget image = Image.asset(
      _logoAsset,
      key: SplashScreen.logoKey,
      width: size.width * SplashTokens.logoWidthFactor,
    );
    if (sigma > 0.01) {
      image = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: image,
      );
    }

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, SplashTokens.logoPerspective)
        ..translateByDouble(0.0, 0.0, depth, 1),
      child: Opacity(opacity: _logoOpacity.value, child: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: ColorTokens.splashBackground,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // 화면보다 넓게 그리고 가운데를 맞춘다.
          final seamWidth = size.width * SplashTokens.seamOverscan;
          final seamRest = (size.width - seamWidth) / 2;
          // 제자리에서 이만큼 밀려나 있으면 화면 밖으로 완전히 빠진다.
          final offscreen = (SplashTokens.seamOverscan + 1) / 2 * size.width;
          final approach = (1 - _seamEntry.value) * offscreen;
          // 가로로만 밀면 실밥이 제 각도를 무시하고 옆으로 미끄러진다.
          // 기울기만큼 세로로도 밀어 두면 제 각도를 따라 비스듬히 들어온다.
          // 위 실밥은 아래쪽에서 올라오고, 아래 실밥은 위쪽에서 내려온다.
          final slide = -SplashTokens.seamSlantSlope * approach;

          // 흔들림은 실밥·로고를 모두 감싸 화면 전체에 걸린다. 배경색은
          // Scaffold 가 깔고 있으므로 흔들려도 빈 곳이 드러나지 않는다.
          return Transform.translate(
            offset: _shakeOffset(size),
            child: Stack(
              children: [
                // 위 실밥 — 화면 왼쪽 아래 밖에서 제 각도를 따라 올라온다.
                Positioned(
                  left: seamRest - approach,
                  top: slide,
                  width: seamWidth,
                  child: Image.asset(
                    _seamTopAsset,
                    key: SplashScreen.seamTopKey,
                    fit: BoxFit.fitWidth,
                  ),
                ),
                // 아래 실밥 — 화면 오른쪽 위 밖에서 제 각도를 따라 내려온다.
                Positioned(
                  left: seamRest + approach,
                  bottom: slide,
                  width: seamWidth,
                  child: Image.asset(
                    _seamBottomAsset,
                    key: SplashScreen.seamBottomKey,
                    fit: BoxFit.fitWidth,
                  ),
                ),
                // 로고 — 원근이 들어간 행렬로 z축을 지나 화면에 꽂힌다.
                Center(child: _logo(size)),
              ],
            ),
          );
        },
      ),
    );
  }
}
