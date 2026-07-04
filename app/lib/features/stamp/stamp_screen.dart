/// 스탬프북 화면 — 10칸 그리드 + 수집률 + 발급 버튼 (R6·R7·R14).
///
/// 렌더 소스는 오직 [stampbookProvider] (데이터 계층). 조회 중 로딩, 실패 시
/// 오류+재시도, 성공 시 그리드를 그린다. 하단 "도장 찍기" 는 발급 진행 중 비활성.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stamp_controller.dart';
import 'stampbook_widgets.dart';

class StampScreen extends ConsumerWidget {
  const StampScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 발급 성공 시 클라우드가 진실원천 — 스탬프북을 다시 조회한다 (R6).
    ref.listen(stampControllerProvider, (prev, next) {
      if (next is StampIssued || next is StampPartiallyIssued) {
        ref.invalidate(stampbookProvider);
      }
    });

    final book = ref.watch(stampbookProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('스탬프북')),
      body: Column(
        children: [
          Expanded(
            child: book.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) => StampbookError(
                onRetry: () => ref.invalidate(stampbookProvider),
              ),
              data: (view) => StampbookGrid(view: view),
            ),
          ),
          const SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: StampIssueButton(),
            ),
          ),
        ],
      ),
    );
  }
}

/// "도장 찍기" — 발급 진행 중(StampIssuing)엔 비활성 + 로딩 인디케이터 (R14).
/// 그 외 상태의 안내 문구는 버튼 위 인라인 상태 영역에 텍스트로 표시한다.
class StampIssueButton extends ConsumerWidget {
  const StampIssueButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stampControllerProvider);
    final busy = state.isBusy;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusText(state: state),
        if (busy) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed:
              busy ? null : () => ref.read(stampControllerProvider.notifier).issue(),
          child: const Text('도장 찍기'),
        ),
      ],
    );
  }
}

/// 발급 결과 안내 — 실패·거리·권한·중복·성공을 버튼 인접 인라인 텍스트로.
class _StatusText extends StatelessWidget {
  const _StatusText({required this.state});

  final StampIssueState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String? text, bool isError) = switch (state) {
      StampIssued() => ('도장을 찍었어요!', false),
      StampPartiallyIssued() => ('일부 칸만 발급됐어요. 다시 시도해 주세요.', true),
      StampDuplicated() => ('이미 도장을 찍은 구장이에요.', false),
      StampOutOfRangeState(:final message) => (message, true),
      StampPermissionRequired(:final message) => (message, true),
      StampFailed(:final message) => (message, true),
      StampIdle() || StampIssuing() => (null, false),
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: isError ? scheme.error : scheme.onSurface),
      ),
    );
  }
}
