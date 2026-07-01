import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stadium.dart';
import 'stadium_provider.dart';

/// 구장 가이드 — 주차·좌석뷰·동선·편의점. `/stadium/:id` 로 진입(일정 카드 탭).
class StadiumScreen extends ConsumerWidget {
  const StadiumScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stadiumProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(async.value?.name ?? '구장 가이드')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(stadiumProvider(id)),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            onRetry: () => ref.invalidate(stadiumProvider(id)),
          ),
          data: (stadium) => _Guide(stadium: stadium),
        ),
      ),
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide({required this.stadium});

  final Stadium stadium;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${stadium.city} · ${stadium.address}', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        _Section(icon: Icons.local_parking, title: '주차', content: stadium.parkingInfo),
        _Section(icon: Icons.event_seat, title: '좌석뷰', content: stadium.seatingInfo),
        _Section(icon: Icons.directions_walk, title: '동선', content: stadium.routeInfo),
        _Section(icon: Icons.store, title: '편의점', content: stadium.convenienceInfo),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.content});

  final IconData icon;
  final String title;
  final String? content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = (content == null || content!.trim().isEmpty) ? null : content!.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text ?? '준비 중이에요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: text == null ? theme.disabledColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // ListView 로 감싸 에러 상태에서도 당겨서새로고침이 먹게 한다.
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
          child: Column(
            children: [
              const Text('구장 정보를 불러오지 못했어요', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ),
        ),
      ],
    );
  }
}
