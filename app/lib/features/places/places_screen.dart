import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'planb_place.dart';
import 'places_provider.dart';
import 'restaurant.dart';

/// 맛집·플랜B — `/places/:stadiumId`. 탭 2개. `?tab=planb` 로 플랜B 초기선택(task-013 딥링크).
class PlacesScreen extends StatelessWidget {
  const PlacesScreen({super.key, required this.stadiumId, this.initialTab});

  final String stadiumId;
  final String? initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab == 'planb' ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('주변 맛집·플랜B'),
          bottom: const TabBar(tabs: [Tab(text: '맛집'), Tab(text: '플랜B')]),
        ),
        body: TabBarView(
          children: [
            _RestaurantsTab(stadiumId: stadiumId),
            _PlanbTab(stadiumId: stadiumId),
          ],
        ),
      ),
    );
  }
}

class _RestaurantsTab extends ConsumerWidget {
  const _RestaurantsTab({required this.stadiumId});

  final String stadiumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(restaurantsProvider(stadiumId));
    return _PlacesList(
      async: async,
      onRefresh: () => ref.invalidate(restaurantsProvider(stadiumId)),
      emptyText: '등록된 맛집이 아직 없어요',
      itemBuilder: (r) => _RestaurantCard(restaurant: r),
    );
  }
}

class _PlanbTab extends ConsumerWidget {
  const _PlanbTab({required this.stadiumId});

  final String stadiumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(planbPlacesProvider(stadiumId));
    return _PlacesList(
      async: async,
      onRefresh: () => ref.invalidate(planbPlacesProvider(stadiumId)),
      emptyText: '등록된 플랜B가 아직 없어요',
      itemBuilder: (p) => _PlanbCard(place: p),
    );
  }
}

/// 로딩/에러+재시도/빈목록/리스트 + 당겨서새로고침 공통 셸.
class _PlacesList<T> extends StatelessWidget {
  const _PlacesList({
    required this.async,
    required this.onRefresh,
    required this.emptyText,
    required this.itemBuilder,
  });

  final AsyncValue<List<T>> async;
  final VoidCallback onRefresh;
  final String emptyText;
  final Widget Function(T) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Centered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('불러오지 못했어요', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRefresh, child: const Text('다시 시도')),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) return _Centered(child: Text(emptyText));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => itemBuilder(list[i]),
          );
        },
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PickBadge(pickType: restaurant.pickType),
                const SizedBox(width: 8),
                Expanded(child: Text(restaurant.name, style: theme.textTheme.titleMedium)),
              ],
            ),
            if (restaurant.category != null) ...[
              const SizedBox(height: 4),
              Text(restaurant.category!, style: theme.textTheme.bodySmall),
            ],
            if (restaurant.description != null) ...[
              const SizedBox(height: 8),
              Text(restaurant.description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: _SourceLink(url: restaurant.sourceUrl)),
          ],
        ),
      ),
    );
  }
}

class _PlanbCard extends StatelessWidget {
  const _PlanbCard({required this.place});

  final PlanbPlace place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(place.category, style: theme.textTheme.bodySmall),
            if (place.description != null) ...[
              const SizedBox(height: 8),
              Text(place.description!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: _SourceLink(url: place.sourceUrl)),
          ],
        ),
      ),
    );
  }
}

/// pick 근거 배지 — 선수/팬/에디터 색 구분.
class _PickBadge extends StatelessWidget {
  const _PickBadge({required this.pickType});

  final PickType pickType;

  static const _colors = {
    PickType.player: Color(0xFF1565C0),
    PickType.fan: Color(0xFF2E7D32),
    PickType.editor: Color(0xFF6A1B9A),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[pickType]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(
        pickType.label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 출처 외부 링크 — url_launcher 외부 브라우저. 실패 시 스낵바.
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    return TextButton.icon(
      icon: const Icon(Icons.open_in_new, size: 16),
      label: const Text('출처'),
      onPressed: () async {
        final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!ok) {
          messenger.showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
        }
      },
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ListView 로 감싸 빈/에러 상태에서도 당겨서새로고침이 먹게 한다.
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
          child: Center(child: child),
        ),
      ],
    );
  }
}
