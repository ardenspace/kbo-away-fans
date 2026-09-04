import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/content_fallback.dart';
import '../../ui/shared/stadium_picker.dart';
import '../home/next_away_game.dart';
import '../home/stadium_browse.dart';
import 'stadium_places_screen.dart';

/// 추천 탭(step 3.1)의 뿌리 화면 — 구장을 골라 그 구장의 추천 목록으로 들어간다.
///
/// 홈의 "구장 골라 구경하기"(step 4.3, [lib/features/home/home_screen.dart])와
/// 같은 탐색 진입이다. 다만 홈에서는 그 섹션이 하나의 목록 항목일 뿐이고 여기는
/// 탭 하나를 통째로 차지하므로, 이 화면은 구장 목록만 보여주는 얕은 뿌리다 —
/// 실제 추천 로직(카테고리 필터·긁기 카드·공유)은 전부 [StadiumPlacesScreen]
/// 이 이미 갖고 있어(사이클 1) 그대로 재사용하고 새로 짓지 않는다.
///
/// 구독하는 provider(`stadiumsProvider` 등)는 앱 전역에서 이미 로드하는
/// 것들이다 — [IndexedStack] 이 이 탭을 계속 살려 둬도 이 화면 때문에 늘어나는
/// 서버 요청은 없다.
class RecommendTabScreen extends ConsumerWidget {
  const RecommendTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stadiumsAsync = ref.watch(stadiumsProvider);
    final stadiumsDoc = contentDataOf(stadiumsAsync);
    final teamsDoc = contentDataOf(ref.watch(teamsProvider));
    final scheduleDoc = contentDataOf(ref.watch(scheduleProvider));
    final now = ref.watch(clockProvider)();

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(title: const Text('추천')),
      body: stadiumsDoc == null
          ? ContentFallback(
              loading: stadiumsAsync is AsyncLoading,
              onRetry: () => invalidateContent(ref),
            )
          : Padding(
              padding: const EdgeInsets.all(SpaceTokens.lg),
              child: StadiumPicker(
                stadiums: [
                  for (final stadium in stadiumsDoc.stadiums)
                    StadiumPickerItem(id: stadium.id, label: stadium.name),
                ],
                onSelected: (id) => _open(
                  context,
                  stadiumsDoc: stadiumsDoc,
                  teamsDoc: teamsDoc,
                  scheduleDoc: scheduleDoc,
                  now: now,
                  stadiumId: id,
                ),
              ),
            ),
    );
  }

  /// 선택 구장의 추천 목록으로 진입 — 테마 규칙은 홈의 탐색 진입과 같다
  /// ([browseThemeKeyForStadium]: 단일 홈팀이면 그 팀, 잠실처럼 둘이면 당일
  /// 경기의 홈팀, 없으면 중립).
  void _open(
    BuildContext context, {
    required StadiumsDocument stadiumsDoc,
    required TeamsDocument? teamsDoc,
    required ScheduleDocument? scheduleDoc,
    required DateTime now,
    required String stadiumId,
  }) {
    final stadium = stadiumsDoc.byId(stadiumId);
    final themeKey = stadium == null || teamsDoc == null
        ? null
        : browseThemeKeyForStadium(
            stadium: stadium,
            teams: teamsDoc,
            schedule: scheduleDoc,
            now: now,
          );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StadiumPlacesScreen(stadiumId: stadiumId, themeKey: themeKey),
      ),
    );
  }
}
