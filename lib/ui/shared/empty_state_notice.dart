import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 목록이 정상적으로 비어 있는 자리의 단일 얼굴 — 제목 + 설명 한 줄.
///
/// [ContentFallback] 과는 다른 상태를 잰다: 그것은 "못 얻었다"(로딩·오류)이고
/// 이것은 "얻었는데 하나도 없다"이다. 좋아요 탭의 빈 좋아요 목록
/// (`LikesTabScreen`)과 추천 탭의 필터 0건(`StadiumPlacesScreen`)이 구조는
/// 같지만 뜻이 다른 두 상태라, 공유하는 것은 구조([title]+[message] 배치)
/// 이지 문구가 아니다 — 문구는 호출부가 각자 준다.
class EmptyStateNotice extends StatelessWidget {
  const EmptyStateNotice({super.key, required this.title, required this.message});

  /// 빈 상태 제목.
  final String title;

  /// 빈 상태 설명 한 줄.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextTokens.sectionTitle),
          const SizedBox(height: SpaceTokens.sm),
          Text(message, style: TextTokens.bodyMuted),
        ],
      ),
    );
  }
}
