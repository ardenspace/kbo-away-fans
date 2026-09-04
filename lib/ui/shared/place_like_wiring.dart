/// 장소 좋아요 토글 배선 — 추천 목록(`StadiumPlacesScreen`)과 좋아요 탭
/// (`LikesTabScreen`)이 똑같이 필요로 하는 세 가지를 한 구현으로 묶는다:
/// 실패 안내 문구, [likedPlaceIdsProvider] 를 향한 토글 호출, 실패를
/// 스낵바로 알리는 경로. 3.3 통합 검증에서 두 화면이 이 셋을 각자
/// 복제했던 것을 승격했다 — 4.x(도장 판·칸 상세)가 같은 배선을 세 번째로
/// 쓸 자리라 화면마다 손으로 다시 짜지 않는다.
///
/// 좋아요를 누르거나 취소했을 때 뜨는 **빈 상태 문구**는 여기 없다 — 그
/// 문구는 화면마다 뜻이 달라 공유 대상이 아니다([EmptyStateNotice] 참조).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/user_data.dart';
import '../../content/models.dart' show Place;

/// 좋아요 쓰기 실패 안내 — 두 화면이 같은 문구를 썼다.
const String kPlaceLikeFailureNotice = '좋아요를 반영하지 못했어요. 잠시 뒤 다시 시도해 주세요.';

/// 좋아요를 누르거나(true) 취소한다(false) — [likedPlaceIdsProvider] 하나만
/// 고친다. 그 provider 를 구독하는 화면은 성공한 뒤 집합이 바뀌면 다시
/// 그려져 해제한 장소가 목록에서 즉시 빠진다.
Future<void> togglePlaceLike(WidgetRef ref, Place place, bool liked) {
  return ref
      .read(likedPlaceIdsProvider.notifier)
      .toggle(
        place.id,
        LikeWrite(
          placeId: place.id,
          stadiumId: place.stadiumId,
          category: place.category,
        ),
        liked,
      );
}

/// 좋아요 쓰기 실패 안내 — [LikeButton] 이 되돌린 뒤에 부른다.
void notifyPlaceLikeFailed(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(const SnackBar(content: Text(kPlaceLikeFailureNotice)));
}
