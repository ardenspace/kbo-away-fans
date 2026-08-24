/// 긁기 카드 랜덤 장소 선택 (step 3.2) — 순수 로직.
///
/// ScratchCard(공유 컴포넌트)는 긁기 제스처·연출만 알고,
/// "현재 필터 풀에서 무엇을 숨길지"는 이 함수가 정한다.
library;

import 'dart:math';

import '../../content/models.dart';

/// [pool] (현재 필터 조건을 통과한 장소들)에서 하나를 균등 랜덤으로 고른다.
///
/// - [pool] 이 비어 있으면 null — 화면은 이때 ScratchCard 를 렌더하지 않는다.
/// - [random] 주입으로 선택이 테스트에서 결정적이 된다.
/// - 재긁기도 같은 풀에서 다시 뽑는다: 다른 장소가 나올 수 *있다*만 보장하며
///   직전 장소의 재등장을 막지 않는다.
Place? pickScratchPlace(List<Place> pool, Random random) {
  if (pool.isEmpty) return null;
  return pool[random.nextInt(pool.length)];
}
