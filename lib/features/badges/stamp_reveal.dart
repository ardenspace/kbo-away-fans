/// 도장이 찍히는 순간의 연출 (step 4.4) — 이 사이클의 대표 연출이다.
///
/// **왜 이 파일인가.** [StampAward.award] 가 도장을 쓴 결과([StampWriteOutcome])
/// 를 그대로 버리던 자리였다 — 4.2 가 그 값을 `void` 에서 열거값으로 바꾼
/// 까닭이 "4.4 의 연출 조건이 같은 값"이라는 것이었는데도(`.wellbegun/decisions.md`
/// 2026-09-05 `[S]`), 그 이음매를 잇는 코드가 없었다. 이제 [StampAward.award]
/// 가 [StampAwardResult] 를 돌려주고, [StadiumVisitCheck.run] 이 그것을
/// [stampCelebrationProvider] 에 밀어 넣으며, 이 파일의 [StampRevealOverlay]
/// 가 그 큐를 지켜보다 화면 위에 얹는다.
///
/// **데이터가 언제나 먼저다.** 이 파일의 어떤 위젯도 쓰기를 시작하지 않는다
/// — [StampAward.award] 가 **로컬에 확정된** 도장의 결과만 여기로 흘러온다
/// (2026-09-06 `[M]`: 그 확정의 순간이 곧 4.2 가 `WriteBatch` 를 고르며 정한
/// "도장이 찍히는 순간"이라, 통신이 끊긴 구장에서도 연출이 그 자리에서 선다).
/// 그래서 연출을 탭으로 건너뛰고 다른 탭으로 옮겨 가도([StampRevealOverlay] 는
/// `Stack` 으로 얹혀 있을 뿐 아래 화면을 걷어내지 않는다) 도장은 이미
/// 저장소에 있다 — `test/features/badges/stamp_reveal_test.dart`
/// 가 위젯을 그리기도 전에 그 사실을 확인한다.
///
/// **한 번에 하나씩, 놓치지 않는다.** [StampCelebration] 의 상태는 큐다 —
/// 더블헤더처럼 한 세션에서 두 번 찍히면 첫 연출이 끝난(또는 건너뛴) 뒤
/// 둘째가 이어진다.
///
/// **등급 상승 판단에 별도 읽기가 없다.** [StampAwardResult.tierIncreased] 는
/// [StampAward.award] 가 이미 계산해 둔 값이라, 이 파일은 그 값 하나만 보고
/// 등급 상승 화면을 이어 붙일지를 정한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/user_data.dart';
import '../../content/content_providers.dart';
import '../../design/team_themes.dart';
import '../../design/tokens.dart';
import '../../ui/shared/stamp_badge.dart';
import 'board_cell_labels.dart';
import 'stamp_award.dart';

/// 아직 보여주지 못한 도장 연출의 줄 — 여러 연출을 순서대로, 하나도 잃지
/// 않고 보여준다(더블헤더처럼 한 세션에서 두 번 찍히는 경우).
final NotifierProvider<StampCelebration, List<StampAwardResult>>
stampCelebrationProvider =
    NotifierProvider<StampCelebration, List<StampAwardResult>>(
      StampCelebration.new,
    );

/// [stampCelebrationProvider] 의 상태를 바꾸는 자리 — 큐에 더하고, 지금 보여
/// 주고 있는 것을 앞에서부터 하나씩 뺀다.
class StampCelebration extends Notifier<List<StampAwardResult>> {
  @override
  List<StampAwardResult> build() => const [];

  /// 새 연출을 줄 끝에 더한다.
  void show(StampAwardResult result) => state = [...state, result];

  /// 지금 보여주고 있는 연출을 치운다 — 다 본 것과 탭으로 건너뛴 것이 같은
  /// 길을 지난다(둘 다 이미 확정된 데이터를 다시 건드리지 않는다).
  void dismissCurrent() {
    if (state.isEmpty) return;
    state = state.skip(1).toList();
  }
}

/// [child] 위에 도장 연출을 얹는 자리.
///
/// `MainTabsRoot` 가 `StadiumVisitTrigger` 와 함께 골격을 감싼다 — 어느
/// 탭을 보고 있어도 연출이 뜨지만, 판정 트리거의 계약대로 사람이 보통 보고
/// 있는 화면은 홈이다(4.1). `Stack` 으로 얹을 뿐 [child] 를 대신하지 않으므로,
/// 연출을 닫으면 아래 화면이 보고 있던 그 **상태** 그대로 돌아온다.
///
/// **연출이 떠 있는 동안에는 아래 화면이 눌리지 않는다** — [StampReveal] 이
/// `SizedBox.expand` + `HitTestBehavior.opaque` 로 하단 탭 바까지 덮기
/// 때문이다. 탭을 옮기려면 두 번 눌러야 한다(첫 번째는 연출을 닫는 데
/// 쓰인다): 실측으로 못 박은 자리는
/// `test/features/badges/phase4_journey_probe_test.dart` 의 "연출이 떠 있는
/// 동안 첫 탭은 연출을 닫는 데 쓰인다"다. 탭 한 번이면 언제든 닫히므로 그
/// 한 번을 막지 않고 그대로 둔다(4.4 의 재량 안이다).
class StampRevealOverlay extends ConsumerWidget {
  const StampRevealOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(stampCelebrationProvider);
    final current = queue.isEmpty ? null : queue.first;
    final teams = contentDataOf(ref.watch(teamsProvider));

    return Stack(
      children: [
        child,
        if (current != null)
          StampReveal(
            // 값이 아니라 **인스턴스**로 갈아 끼운다 — 같은 칸에 같은 등급으로
            // 두 번 찍혀도([StampAwardResult] 가 `==`/`hashCode` 를 덮어쓰지
            // 않는 까닭이다) 다른 사건이라 애니메이션이 처음부터 다시 돈다.
            key: ObjectKey(current),
            result: current,
            teamLabel: boardCellLabels(teams)[current.cellId],
            onDone: () =>
                ref.read(stampCelebrationProvider.notifier).dismissCurrent(),
          ),
      ],
    );
  }
}

/// 연출 그 자체 — [MotionTokens.stamp] 로 배지가 찍히고, [result.tierIncreased]
/// 면 등급 이름이 이어 뜬다. 화면 아무 곳이나 누르면 그 자리에서 곧바로
/// 닫힌다(연출을 건너뛰어도 [result] 가 가리키는 도장은 이미 확정된 데이터다).
class StampReveal extends StatefulWidget {
  const StampReveal({
    super.key,
    required this.result,
    required this.onDone,
    this.teamLabel,
  });

  /// 이번에 찍힌 도장의 결과 — 연출 수치를 뺀 모든 내용이 여기서 온다.
  final StampAwardResult result;

  /// 연출을 닫을 때(다 봤을 때·탭으로 건너뛸 때 모두) 한 번 불린다.
  final VoidCallback onDone;

  /// 칸에 적을 팀 약칭 — 콘텐츠를 못 얻은 실행에서는 null(글자 없이 색·링만).
  final String? teamLabel;

  /// 찍히는 배지에 적용되는 확대 변형 — 시험이 진행도를 읽는다.
  static const Key badgeTransformKey = Key('stamp-reveal-badge-transform');

  /// 등급 상승 문구 — 시험이 등급 상승 갈래의 유무를 확인한다.
  static const Key tierUpKey = Key('stamp-reveal-tier-up');

  @override
  State<StampReveal> createState() => _StampRevealState();
}

class _StampRevealState extends State<StampReveal>
    with TickerProviderStateMixin {
  late final AnimationController _stampController;
  late final Animation<double> _stampScale;

  // 등급이 오를 때만 만든다 — 오르지 않는 도장에는 존재하지 않는 채로 둔다
  // (연출 자체가 없다는 뜻이라, null 을 "아직 안 만들었다"로 겸용하지 않는다).
  AnimationController? _tierController;
  Animation<double>? _tierOpacity;

  /// 찍힘이 끝나 등급 상승 위젯을 트리에 실제로 얹었는가.
  ///
  /// [_tierController] 를 만들어 두는 것과 그 문구를 **트리에 얹는 것**을
  /// 나눈다 — 얹어만 두고 투명도만 0으로 시작하면 "찍힘이 끝난 뒤 이어
  /// 붙는다"는 계약이 위젯 존재만으로는 확인되지 않는다. 이 플래그가 서야
  /// 비로소 build() 가 등급 상승 위젯을 넣는다.
  bool _tierRevealStarted = false;

  @override
  void initState() {
    super.initState();
    _stampController = AnimationController(
      vsync: this,
      duration: MotionTokens.stamp.duration,
    )..addStatusListener(_onStampStatusChanged);
    _stampScale = CurvedAnimation(
      parent: _stampController,
      curve: MotionTokens.stamp.curve,
    );

    if (widget.result.tierIncreased) {
      final tierController = AnimationController(
        vsync: this,
        duration: MotionTokens.base,
      );
      _tierController = tierController;
      // `standard`(easeOutCubic)는 넘치지 않는다 — Opacity 는 0..1 을
      // 벗어나면 assert 로 던지므로, 넘칠 수 있는 stamp 커브를 여기 쓰지 않는다.
      _tierOpacity = CurvedAnimation(
        parent: tierController,
        curve: MotionTokens.standard,
      );
    }

    _stampController.forward();
  }

  /// 찍힘이 다 끝나면 등급 상승 문구를 이어 붙인다 — 두 연출이 겹치지 않고
  /// **이어진다**는 계약("등급이 오르는 도장이면 등급 상승이 이어서 보인다")
  /// 을 여기서 지킨다.
  void _onStampStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final tierController = _tierController;
    if (tierController == null) return;
    setState(() => _tierRevealStarted = true);
    tierController.forward();
  }

  @override
  void dispose() {
    _stampController.dispose();
    _tierController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final style = BadgeTierTokens.byTier[result.tier]!;
    final theme = TeamThemes.byId[boardCellTeamId(result.cellId)]!;

    // `Positioned.fill` 대신 쓰는 것은 이 위젯이 `Stack` 밖(예: 시험의
    // 최소 host)에서도 그대로 서야 하기 때문이다 — `Positioned` 는 반드시
    // `Stack` 의 자식이어야 하고, 아니면 "Incorrect use of
    // ParentDataWidget" 로 즉시 던진다.
    return SizedBox.expand(
      child: GestureDetector(
        // 스크림 어디를 눌러도 닫힌다 — 배경이 비어 보이는 자리(투명 영역)
        // 까지 눌리게 해서 "화면을 벗어나도"의 가장 쉬운 형태(탭으로 닫기)를
        // 어디서나 받아 준다.
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDone,
        child: ColoredBox(
          color: ColorTokens.overlayScrim,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  key: StampReveal.badgeTransformKey,
                  scale: _stampScale,
                  child: StampBadge(
                    theme: theme,
                    stamps: result.count,
                    label: widget.teamLabel,
                    size: BadgeTokens.revealCellSize,
                    semanticLabel:
                        '${widget.teamLabel ?? ''} ${style.label} 도장'.trim(),
                  ),
                ),
                if (_tierRevealStarted) ...[
                  const SizedBox(height: SpaceTokens.lg),
                  FadeTransition(
                    key: StampReveal.tierUpKey,
                    opacity: _tierOpacity!,
                    child: Text(
                      '등급 상승! ${style.label}',
                      textAlign: TextAlign.center,
                      style: TextTokens.title.copyWith(
                        color: ColorTokens.textInverse,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: SpaceTokens.xl),
                Text(
                  '화면을 눌러 닫기',
                  style: TextTokens.caption.copyWith(
                    color: ColorTokens.textInverse,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
