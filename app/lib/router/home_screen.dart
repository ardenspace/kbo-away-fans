import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KBO 원정팬')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('응원팀을 설정하고 원정을 떠나세요 ⚾'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/schedule'),
              child: const Text('원정 일정 보기'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/stamp'),
              child: const Text('내 스탬프'),
            ),
          ],
        ),
      ),
    );
  }
}
