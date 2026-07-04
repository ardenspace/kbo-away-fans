/// task 1.4 — 근접 판정·거리 계산·잠실 칸 배정 도메인 순수 함수 테스트 (R1·R2·R13).
///
/// 실기기·시계·플러그인 의존 없음 — 좌표·기준 시각·경기 팀 목록 전부 주입.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/stamp/stamp_domain.dart';
import 'package:kbo_away_fans/features/stamp/stamp_models.dart';

const _jamsilLat = 37.5122;
const _jamsilLng = 127.0717;

StampStadium _stadium({
  String id = 'stadium-jamsil-ob',
  String name = '잠실야구장',
  double lat = _jamsilLat,
  double lng = _jamsilLng,
  int stampRadiusM = 500,
  String teamId = 'team-ob',
  String teamAbbr = 'OB',
}) => StampStadium(
  id: id,
  name: name,
  lat: lat,
  lng: lng,
  stampRadiusM: stampRadiusM,
  teamId: teamId,
  teamAbbr: teamAbbr,
);

/// 잠실 두 행 — 동일 좌표, name 만 다름 (seed 데이터와 동일 구조).
StampStadium _jamsilOb() => _stadium();
StampStadium _jamsilLg() => _stadium(
  id: 'stadium-jamsil-lg',
  name: '잠실야구장 (LG)',
  teamId: 'team-lg',
  teamAbbr: 'LG',
);
StampStadium _suwonKt() => _stadium(
  id: 'stadium-suwon',
  name: '수원KT위즈파크',
  lat: 37.2997,
  lng: 127.0098,
  teamId: 'team-kt',
  teamAbbr: 'KT',
);

void main() {
  group('하버사인 거리 (R1·R2 재료)', () {
    test('동일 좌표 — 0m', () {
      expect(
        haversineMeters(
          lat1: _jamsilLat,
          lng1: _jamsilLng,
          lat2: _jamsilLat,
          lng2: _jamsilLng,
        ),
        0,
      );
    });

    test('위도 0.01도 차 — R·Δφ ≈ 1111.95m', () {
      // 순수 위도 차이의 하버사인은 대원 거리 R·Δφ 와 일치한다 (R=6371km).
      final d = haversineMeters(lat1: 37.0, lng1: 127.0, lat2: 37.01, lng2: 127.0);
      expect(d, closeTo(6371000 * 0.01 * math.pi / 180, 0.5));
    });

    test('위도 60도에서 경도 0.01도 차 — cos(60°) 축척 ≈ 555.97m', () {
      final d = haversineMeters(lat1: 60.0, lng1: 127.0, lat2: 60.0, lng2: 127.01);
      expect(d, closeTo(555.97, 0.5));
    });

    test('인자 순서 대칭', () {
      final a = haversineMeters(lat1: 37.0, lng1: 127.0, lat2: 37.5, lng2: 127.3);
      final b = haversineMeters(lat1: 37.5, lng1: 127.3, lat2: 37.0, lng2: 127.0);
      expect(a, b);
    });
  });

  group('반경 내/밖 판정 — 경계값 포함 (R1·R2)', () {
    // 잠실 북쪽 0.004도 ≈ 444.78m — stamp_radius_m 500 안.
    const nearLat = _jamsilLat + 0.004;
    // 북쪽 0.005도 ≈ 555.97m — 500 밖.
    const farLat = _jamsilLat + 0.005;

    test('반경 500m 내 좌표 — true', () {
      expect(
        isWithinRadius(
          lat: nearLat,
          lng: _jamsilLng,
          stadiumLat: _jamsilLat,
          stadiumLng: _jamsilLng,
          radiusM: 500,
        ),
        isTrue,
      );
    });

    test('반경 500m 밖 좌표 — false', () {
      expect(
        isWithinRadius(
          lat: farLat,
          lng: _jamsilLng,
          stadiumLat: _jamsilLat,
          stadiumLng: _jamsilLng,
          radiusM: 500,
        ),
        isFalse,
      );
    });

    test('경계값 — 거리가 정확히 반경과 같으면 반경 내', () {
      final d = haversineMeters(
        lat1: nearLat,
        lng1: _jamsilLng,
        lat2: _jamsilLat,
        lng2: _jamsilLng,
      );
      expect(
        isWithinRadius(
          lat: nearLat,
          lng: _jamsilLng,
          stadiumLat: _jamsilLat,
          stadiumLng: _jamsilLng,
          radiusM: d,
        ),
        isTrue,
        reason: '거리 == 반경은 반경 내로 판정한다',
      );
    });

    test('경계값 — 반경이 거리보다 조금이라도 작으면 밖', () {
      final d = haversineMeters(
        lat1: nearLat,
        lng1: _jamsilLng,
        lat2: _jamsilLat,
        lng2: _jamsilLng,
      );
      expect(
        isWithinRadius(
          lat: nearLat,
          lng: _jamsilLng,
          stadiumLat: _jamsilLat,
          stadiumLng: _jamsilLng,
          radiusM: d.floorToDouble(),
        ),
        isFalse,
      );
      expect(
        isWithinRadius(
          lat: nearLat,
          lng: _jamsilLng,
          stadiumLat: _jamsilLat,
          stadiumLng: _jamsilLng,
          radiusM: d.ceilToDouble(),
        ),
        isTrue,
      );
    });

    test('거리 0 · 반경 0 — 반경 내', () {
      expect(
        isWithinRadius(
          lat: _jamsilLat,
          lng: _jamsilLng,
          stadiumLat: _jamsilLat,
          stadiumLng: _jamsilLng,
          radiusM: 0,
        ),
        isTrue,
      );
    });
  });

  group('가장 가까운 구장 + 거리 문자열 "N.Nkm" (R2)', () {
    test('여러 구장 중 최단 거리 구장을 고른다', () {
      // 수원 KT 위즈파크 북쪽 0.05도 (≈5.56km) — 잠실보다 수원이 가깝다.
      final nearest = nearestStadium(
        stadiums: [_jamsilOb(), _jamsilLg(), _suwonKt()],
        lat: 37.2997 + 0.05,
        lng: 127.0098,
      );
      expect(nearest, isNotNull);
      expect(nearest!.stadium.id, 'stadium-suwon');
    });

    test('거리 문자열 — km 소수 1자리 "N.Nkm"', () {
      // 0.05도 ≈ 5559.75m → "5.6km".
      final nearest = nearestStadium(
        stadiums: [_suwonKt()],
        lat: 37.2997 + 0.05,
        lng: 127.0098,
      );
      expect(nearest!.distanceText, '5.6km');
      expect(nearest.distanceMeters, closeTo(5559.75, 0.5));
    });

    test('formatDistanceKm — 소수 1자리 고정', () {
      expect(formatDistanceKm(5559.75), '5.6km');
      expect(formatDistanceKm(18234), '18.2km');
      expect(formatDistanceKm(80), '0.1km');
    });

    test('빈 구장 목록 — null', () {
      expect(nearestStadium(stadiums: [], lat: 37.0, lng: 127.0), isNull);
    });

    group('동일 좌표 동률(잠실 두 행) — name="잠실야구장" 행을 택한다', () {
      test('OB 행이 먼저 와도', () {
        final nearest = nearestStadium(
          stadiums: [_jamsilOb(), _jamsilLg()],
          lat: _jamsilLat + 0.1,
          lng: _jamsilLng,
        );
        expect(nearest!.stadium.name, '잠실야구장');
      });

      test('LG 행이 먼저 와도 — 합성 name "(LG)" 는 노출 안 된다', () {
        final nearest = nearestStadium(
          stadiums: [_jamsilLg(), _jamsilOb()],
          lat: _jamsilLat + 0.1,
          lng: _jamsilLng,
        );
        expect(nearest!.stadium.name, '잠실야구장');
      });
    });
  });

  group('KST 달력일 해석 — UTC 저장 좌표 역변환 (R13)', () {
    test('UTC 14:59 — 같은 KST 날짜 (23:59)', () {
      expect(
        kstDayOf(DateTime.utc(2026, 7, 4, 14, 59)),
        DateTime(2026, 7, 4),
      );
    });

    test('UTC 15:00 — KST 다음 날 자정 (달력일 경계)', () {
      expect(
        kstDayOf(DateTime.utc(2026, 7, 4, 15, 0)),
        DateTime(2026, 7, 5),
      );
    });

    test('UTC 자정 직전 — KST 는 같은 날 오전', () {
      expect(
        kstDayOf(DateTime.utc(2026, 7, 4, 0, 0)),
        DateTime(2026, 7, 4),
      );
    });
  });

  group('잠실 칸 배정 — 경기 팀 목록 ∩ {두산, LG} (R13)', () {
    test('두산 홈 경기 (OB vs HT) — 두산 칸만', () {
      expect(jamsilTargetSlotAbbrs({'OB', 'HT'}), {'OB'});
    });

    test('LG 홈 경기 (LG vs SS) — LG 칸만', () {
      expect(jamsilTargetSlotAbbrs({'LG', 'SS'}), {'LG'});
    });

    test('두산-LG 맞대결 — 두 칸 모두', () {
      expect(jamsilTargetSlotAbbrs({'OB', 'LG'}), {'OB', 'LG'});
    });

    test('무경기(빈 목록) — 두 칸 모두', () {
      expect(jamsilTargetSlotAbbrs(const {}), {'OB', 'LG'});
    });

    test('교집합 공집합 (잠실에 타 팀 경기만) — 두 칸 모두', () {
      expect(jamsilTargetSlotAbbrs({'KW', 'SS'}), {'OB', 'LG'});
    });
  });

  group('발급 대상 칸 결정 (R1·R13)', () {
    test('잠실 외 구장 — 반경 판정만으로 단일 칸', () {
      final slots = resolveTargetSlots(
        stadiumsInRadius: [_suwonKt()],
        jamsilGameTeamAbbrs: const {},
      );
      expect(slots.map((s) => s.id), ['stadium-suwon']);
    });

    test('잠실 두 행 + 두산 경기 — OB 칸만', () {
      final slots = resolveTargetSlots(
        stadiumsInRadius: [_jamsilOb(), _jamsilLg()],
        jamsilGameTeamAbbrs: {'OB', 'HT'},
      );
      expect(slots.map((s) => s.teamAbbr), ['OB']);
    });

    test('잠실 두 행 + LG 경기 — LG 칸만', () {
      final slots = resolveTargetSlots(
        stadiumsInRadius: [_jamsilOb(), _jamsilLg()],
        jamsilGameTeamAbbrs: {'LG', 'NC'},
      );
      expect(slots.map((s) => s.teamAbbr), ['LG']);
    });

    test('잠실 두 행 + 무경기 — 두 칸 모두', () {
      final slots = resolveTargetSlots(
        stadiumsInRadius: [_jamsilOb(), _jamsilLg()],
        jamsilGameTeamAbbrs: const {},
      );
      expect(slots.map((s) => s.teamAbbr).toSet(), {'OB', 'LG'});
    });
  });

  group('근접 판정 통합 — sealed StampProximity (R1·R2)', () {
    final all = [_jamsilOb(), _jamsilLg(), _suwonKt()];

    test('잠실 반경 내 — StampInRange 에 잠실 두 행만 담긴다', () {
      final result = evaluateStampProximity(
        stadiums: all,
        lat: _jamsilLat,
        lng: _jamsilLng,
      );
      expect(result, isA<StampInRange>());
      final inRange = result as StampInRange;
      expect(
        inRange.stadiumsInRadius.map((s) => s.teamAbbr).toSet(),
        {'OB', 'LG'},
      );
    });

    test('수원 반경 내 — 단일 구장', () {
      final result = evaluateStampProximity(
        stadiums: all,
        lat: 37.2997,
        lng: 127.0098,
      );
      final inRange = result as StampInRange;
      expect(inRange.stadiumsInRadius.map((s) => s.id), ['stadium-suwon']);
    });

    test('전 구장 반경 밖 — StampOutOfRange + 최근접 구장·거리 문자열', () {
      // 수원 KT 북쪽 0.05도 — 모든 반경(500m) 밖, 최근접은 수원.
      final result = evaluateStampProximity(
        stadiums: all,
        lat: 37.2997 + 0.05,
        lng: 127.0098,
      );
      expect(result, isA<StampOutOfRange>());
      final out = result as StampOutOfRange;
      expect(out.nearest.stadium.id, 'stadium-suwon');
      expect(out.nearest.distanceText, '5.6km');
    });

    test('반경 밖 + 잠실 동률 — 표시명은 "잠실야구장" (R2)', () {
      final result = evaluateStampProximity(
        stadiums: [_jamsilLg(), _jamsilOb()],
        lat: _jamsilLat + 0.1,
        lng: _jamsilLng,
      );
      final out = result as StampOutOfRange;
      expect(out.nearest.stadium.name, '잠실야구장');
    });

    test('빈 구장 목록 — ArgumentError', () {
      expect(
        () => evaluateStampProximity(stadiums: const [], lat: 37.0, lng: 127.0),
        throwsArgumentError,
      );
    });
  });
}
