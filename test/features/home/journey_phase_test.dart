import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/home/journey_phase.dart';

void main() {
  final startsAt = DateTime.parse('2026-09-13T18:30:00+09:00');
  final endsAt = DateTime.parse('2026-09-13T22:00:00+09:00');

  JourneyPhase phase({
    DateTime? now,
    DateTime? start,
    DateTime? end,
    bool? cancelled,
    bool? nearby,
    bool? moving,
  }) => resolveJourneyPhase(
    JourneyPhaseSignals(
      now: now,
      gameStartsAt: start,
      gameEndsAt: end,
      cancelled: cancelled,
      nearby: nearby,
      moving: moving,
    ),
  );

  group('시간 경계', () {
    test('시작 전은 preGame이고 시작 시각부터 live다', () {
      expect(
        phase(
          now: startsAt.subtract(const Duration(microseconds: 1)),
          start: startsAt,
          end: endsAt,
        ),
        JourneyPhase.preGame,
      );
      expect(
        phase(now: startsAt, start: startsAt, end: endsAt),
        JourneyPhase.live,
      );
    });

    test('종료 직전은 live이고 종료 시각부터 postGame이다', () {
      expect(
        phase(
          now: endsAt.subtract(const Duration(microseconds: 1)),
          start: startsAt,
          end: endsAt,
        ),
        JourneyPhase.live,
      );
      expect(
        phase(now: endsAt, start: startsAt, end: endsAt),
        JourneyPhase.postGame,
      );
    });
  });

  group('우선순위', () {
    test('cancelled가 모든 신호보다 우선한다', () {
      expect(
        phase(
          now: startsAt,
          start: startsAt,
          end: endsAt,
          cancelled: true,
          nearby: true,
          moving: true,
        ),
        JourneyPhase.cancelled,
      );
    });

    test('live가 nearby와 moving보다 우선한다', () {
      expect(
        phase(
          now: startsAt,
          start: startsAt,
          end: endsAt,
          nearby: true,
          moving: true,
        ),
        JourneyPhase.live,
      );
    });

    test('nearby가 moving과 postGame보다 우선한다', () {
      expect(
        phase(
          now: endsAt,
          start: startsAt,
          end: endsAt,
          nearby: true,
          moving: true,
        ),
        JourneyPhase.nearby,
      );
    });

    test('moving이 postGame보다 우선한다', () {
      expect(
        phase(now: endsAt, start: startsAt, end: endsAt, moving: true),
        JourneyPhase.moving,
      );
    });
  });

  group('결측과 잘못된 시간', () {
    test('신호가 없으면 idle이다', () {
      expect(phase(), JourneyPhase.idle);
    });

    test('시간 입력이 일부만 있으면 idle이다', () {
      expect(phase(now: startsAt, start: startsAt), JourneyPhase.idle);
      expect(phase(now: startsAt, end: endsAt), JourneyPhase.idle);
      expect(phase(start: startsAt, end: endsAt), JourneyPhase.idle);
    });

    test('종료가 시작보다 이르면 idle이다', () {
      expect(
        phase(now: startsAt, start: endsAt, end: startsAt),
        JourneyPhase.idle,
      );
    });

    test('알 수 없는 bool 신호는 활성 신호로 추측하지 않는다', () {
      expect(
        phase(
          now: startsAt.subtract(const Duration(hours: 1)),
          start: startsAt,
          end: endsAt,
          cancelled: null,
          nearby: null,
          moving: null,
        ),
        JourneyPhase.preGame,
      );
    });
  });
}
