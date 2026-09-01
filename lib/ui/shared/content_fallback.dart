import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 콘텐츠·사용자 데이터를 못 얻은 자리의 단일 얼굴 — 로딩 스피너, 또는
/// 실패 안내 + 재시도.
///
/// 화면마다 같은 모양을 손으로 다시 짜면 문구와 간격이 조금씩 갈리고,
/// "다시 시도"가 어떤 화면에는 없다는 것도 눈에 띄지 않는다. 실패 안내와
/// 로딩을 한 위젯이 들고 [loading] 으로 갈라 두면 두 상태가 항상 짝으로 붙는다.
///
/// 재시도 경로가 없는 자리(되돌릴 방법이 없는 실패)는 [onRetry] 를 비워 둔다 —
/// 그러면 버튼 자체가 서지 않아, 눌러도 아무 일이 없는 버튼이 생기지 않는다.
class ContentFallback extends StatelessWidget {
  const ContentFallback({
    super.key,
    required this.loading,
    this.title = defaultTitle,
    this.message = defaultMessage,
    this.onRetry,
  });

  /// 실패 안내의 기본 제목 — 무엇을 못 얻었는지 아는 화면은 직접 넘긴다.
  static const String defaultTitle = '내용을 불러오지 못했어요';

  /// 실패 안내의 기본 설명. 대부분의 실패가 네트워크라 이 문구가 기본이다.
  static const String defaultMessage = '네트워크를 확인하고 다시 시도해 주세요.';

  /// 재시도 버튼의 문구 — 화면마다 다르게 부르지 않는다.
  static const String retryLabel = '다시 시도';

  /// 아직 기다리는 중이면 true (스피너), 실패로 끝났으면 false (안내).
  final bool loading;

  /// 실패 안내의 제목.
  final String title;

  /// 실패 안내의 설명 한 줄.
  final String message;

  /// 재시도 경로. null 이면 버튼을 두지 않는다.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextTokens.title),
          const SizedBox(height: SpaceTokens.sm),
          Text(message, style: TextTokens.bodyMuted),
          if (onRetry != null) ...[
            const SizedBox(height: SpaceTokens.md),
            FilledButton(
              onPressed: onRetry,
              child: Text(
                retryLabel,
                style: TextTokens.inheritColor(TextTokens.label),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
