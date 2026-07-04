/// task 1.7 — 도장 애니메이션 + 햅틱 순차 재생 위젯 테스트 (R8).
///
/// 발급 성공 상태(StampIssued/StampPartiallyIssued)가 방출되면, 발급된 칸마다
/// 도장 애니(=컨트롤러 forward)와 햅틱 플랫폼 채널이 각 1회, 칸 순서대로 순차
/// 재생되는지 검증한다. 실 Supabase·실기기 없음 — 데이터 fake + 컨트롤러 override.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/stamp/stamp_controller.dart';
import 'package:kbo_away_fans/features/stamp/stamp_models.dart';
import 'package:kbo_away_fans/features/stamp/stamp_repository.dart';
import 'package:kbo_away_fans/features/stamp/stadium_repository.dart';
import 'package:kbo_away_fans/features/stamp/stamp_screen.dart';
import 'package:kbo_away_fans/features/stamp/stamp_stamp_animation.dart';

import 'fakes.dart';

const _abbrs = ['OB', 'LG', 'KW', 'SK', 'LT', 'SS', 'HH', 'HT', 'NC', 'KT'];

List<StampStadium> _tenStadiums() => [
      for (var i = 0; i < _abbrs.length; i++)
        StampStadium(
          id: 'stadium-$i',
          name: 'stadium-$i',
          lat: 37.0 + i,
          lng: 127.0 + i,
          stampRadiusM: 500,
          teamId: 'team-$i',
          teamAbbr: _abbrs[i],
        ),
    ];

StampStadium _slot(String abbr) => StampStadium(
      id: 'stadium-$abbr',
      name: 'stadium-$abbr',
      lat: 37,
      lng: 127,
      stampRadiusM: 500,
      teamId: 'team-$abbr',
      teamAbbr: abbr,
    );

Stamp _stamp(String abbr) => Stamp(
      id: 'stamp-$abbr',
      userId: 'user-1',
      stadiumId: 'stadium-$abbr',
      lat: 37,
      lng: 127,
      stampedAt: DateTime(2026, 7, 4),
    );

/// build 은 유휴로 시작하고, 테스트가 emit 으로 성공 상태를 방출한다
/// (Idle→Issued 전이라야 화면의 ref.listen 이 발화한다).
class _EmitController extends StampController {
  @override
  StampIssueState build() => const StampIdle();

  void emit(StampIssueState next) => state = next;
}

/// 재생된 칸을 순서대로 기록하는 관측자 + 햅틱 채널 카운터를 세팅한다.
({List<String> played, List<String> haptics}) _install(WidgetTester tester) {
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add((call.arguments as String?) ?? 'vibrate');
      }
      return null;
    },
  );
  return (played: <String>[], haptics: haptics);
}

Widget _app({required void Function(StampStadium) observer}) {
  return ProviderScope(
    overrides: [
      stadiumRepositoryProvider
          .overrideWithValue(FakeStadiumRepository(stadiums: _tenStadiums())),
      stampRepositoryProvider.overrideWithValue(FakeStampRepository()),
      stampControllerProvider.overrideWith(_EmitController.new),
      stampCelebrationObserverProvider.overrideWithValue(observer),
    ],
    child: const MaterialApp(home: StampScreen()),
  );
}

_EmitController _controller(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(StampScreen)))
        .read(stampControllerProvider.notifier) as _EmitController;

void main() {
  testWidgets('단일 칸 발급 성공 → 애니 1회 + 햅틱 1회 (R8)', (tester) async {
    final rec = _install(tester);
    await tester.pumpWidget(_app(observer: (s) => rec.played.add(s.teamAbbr)));
    await tester.pumpAndSettle();

    _controller(tester).emit(
      StampIssued(stamps: [_stamp('OB')], slots: [_slot('OB')]),
    );
    await tester.pumpAndSettle();

    expect(rec.played, ['OB']);
    expect(rec.haptics.length, 1);
  });

  testWidgets('잠실 2칸 발급 → 애니·햅틱 각 2회, 칸 순서대로 순차 (R8)',
      (tester) async {
    final rec = _install(tester);
    await tester.pumpWidget(_app(observer: (s) => rec.played.add(s.teamAbbr)));
    await tester.pumpAndSettle();

    _controller(tester).emit(
      StampIssued(
        stamps: [_stamp('OB'), _stamp('LG')],
        slots: [_slot('OB'), _slot('LG')],
      ),
    );
    await tester.pumpAndSettle();

    expect(rec.played, ['OB', 'LG']); // 칸 순서대로 순차
    expect(rec.haptics.length, 2);
  });

  testWidgets('부분 성공 → 성공한 칸만 재생 (R8)', (tester) async {
    final rec = _install(tester);
    await tester.pumpWidget(_app(observer: (s) => rec.played.add(s.teamAbbr)));
    await tester.pumpAndSettle();

    _controller(tester).emit(
      StampPartiallyIssued(
        stamps: [_stamp('OB')],
        issuedSlots: [_slot('OB')],
        failedSlots: [_slot('LG')],
      ),
    );
    await tester.pumpAndSettle();

    expect(rec.played, ['OB']);
    expect(rec.haptics.length, 1);
  });

  test('외부 애니 에셋(Lottie/Rive) 의존 없음 — pubspec 단언 (R8)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
    // 패키지 이름 단위로 단언 (riverpod 의 'rive' 부분문자열 오탐 방지).
    expect(RegExp(r'\blottie\b').hasMatch(pubspec), isFalse);
    expect(RegExp(r'\brive\b').hasMatch(pubspec), isFalse);
  });
}
