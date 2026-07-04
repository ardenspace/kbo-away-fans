/// task 2.1 — 지도 마커 모델: 잠실 병합 + 방문 플래그 순수 함수 테스트 (R9).
///
/// 네이티브·키 의존 없음 — 구장 목록·스탬프 목록을 주입한 순수 Dart 단위 테스트.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/map/map_domain.dart';
import 'package:kbo_away_fans/features/stamp/stamp_models.dart';

const _jamsilLat = 37.5122;
const _jamsilLng = 127.0717;

StampStadium _stadium({
  required String id,
  required String name,
  required double lat,
  required double lng,
  required String teamId,
  required String teamAbbr,
  int stampRadiusM = 500,
}) => StampStadium(
  id: id,
  name: name,
  lat: lat,
  lng: lng,
  stampRadiusM: stampRadiusM,
  teamId: teamId,
  teamAbbr: teamAbbr,
);

/// 잠실 두 행 — 동일 좌표, name·team 만 다름 (seed 구조와 동일).
StampStadium _jamsilOb() => _stadium(
  id: 'stadium-jamsil-ob',
  name: '잠실야구장',
  lat: _jamsilLat,
  lng: _jamsilLng,
  teamId: 'team-ob',
  teamAbbr: 'OB',
);
StampStadium _jamsilLg() => _stadium(
  id: 'stadium-jamsil-lg',
  name: '잠실야구장 (LG)',
  lat: _jamsilLat,
  lng: _jamsilLng,
  teamId: 'team-lg',
  teamAbbr: 'LG',
);

/// 잠실 외 8구장 (좌표 서로 다름) — 잠실 2행과 합쳐 10구장.
List<StampStadium> _otherEight() => [
  _stadium(id: 's-suwon', name: '수원KT위즈파크', lat: 37.2997, lng: 127.0098, teamId: 't-kt', teamAbbr: 'KT'),
  _stadium(id: 's-gocheok', name: '고척스카이돔', lat: 37.4982, lng: 126.8672, teamId: 't-kw', teamAbbr: 'KW'),
  _stadium(id: 's-incheon', name: '인천SSG랜더스필드', lat: 37.4370, lng: 126.6932, teamId: 't-ss', teamAbbr: 'SK'),
  _stadium(id: 's-daejeon', name: '대전한화생명볼파크', lat: 36.3170, lng: 127.4290, teamId: 't-hh', teamAbbr: 'HH'),
  _stadium(id: 's-daegu', name: '대구삼성라이온즈파크', lat: 35.8410, lng: 128.6816, teamId: 't-sl', teamAbbr: 'SS'),
  _stadium(id: 's-gwangju', name: '광주기아챔피언스필드', lat: 35.1682, lng: 126.8886, teamId: 't-ht', teamAbbr: 'HT'),
  _stadium(id: 's-busan', name: '사직야구장', lat: 35.1940, lng: 129.0615, teamId: 't-lt', teamAbbr: 'LT'),
  _stadium(id: 's-changwon', name: 'NC파크', lat: 35.2225, lng: 128.5823, teamId: 't-nc', teamAbbr: 'NC'),
];

/// 전체 10구장 (잠실 2행 포함).
List<StampStadium> _tenStadiums() => [_jamsilOb(), _jamsilLg(), ..._otherEight()];

Stamp _stamp(String stadiumId) => Stamp(
  id: 'stamp-$stadiumId',
  userId: 'user-1',
  stadiumId: stadiumId,
  lat: 0,
  lng: 0,
  stampedAt: DateTime.utc(2026, 7, 4),
);

/// stamped_at 을 지정하는 스탬프 — 경로 시퀀스(정렬) 테스트용.
/// lat/lng=0 은 의도적: 경로 좌표는 stamp 가 아닌 stadium.lat/lng 에서 온다.
Stamp _stampAt(String stadiumId, DateTime stampedAt) => Stamp(
  id: 'stamp-$stadiumId-${stampedAt.microsecondsSinceEpoch}',
  userId: 'user-1',
  stadiumId: stadiumId,
  lat: 0,
  lng: 0,
  stampedAt: stampedAt,
);

void main() {
  group('마커 병합 — 동일 좌표(잠실 두 행)는 마커 1개 (R9)', () {
    test('10구장 → 마커 9개', () {
      final markers = buildMapMarkers(stadiums: _tenStadiums(), stamps: const []);
      expect(markers, hasLength(9));
    });

    test('병합 잠실 마커 표시명은 "잠실야구장" — 합성 "(LG)" 노출 안 됨', () {
      final markers = buildMapMarkers(
        stadiums: [_jamsilLg(), _jamsilOb()],
        stamps: const [],
      );
      expect(markers, hasLength(1));
      expect(markers.single.name, '잠실야구장');
    });
  });

  group('방문 플래그 (R9)', () {
    test('잠실 두 칸 중 OB 만 방문 — 병합 마커 isVisited=true', () {
      final markers = buildMapMarkers(
        stadiums: _tenStadiums(),
        stamps: [_stamp('stadium-jamsil-ob')],
      );
      final jamsil = markers.firstWhere((m) => m.name == '잠실야구장');
      expect(jamsil.isVisited, isTrue);
    });

    test('잠실 두 칸 중 LG 만 방문 — 병합 마커 isVisited=true', () {
      final markers = buildMapMarkers(
        stadiums: _tenStadiums(),
        stamps: [_stamp('stadium-jamsil-lg')],
      );
      final jamsil = markers.firstWhere((m) => m.name == '잠실야구장');
      expect(jamsil.isVisited, isTrue);
    });

    test('잠실 두 칸 모두 미방문 — isVisited=false', () {
      final markers = buildMapMarkers(stadiums: _tenStadiums(), stamps: const []);
      final jamsil = markers.firstWhere((m) => m.name == '잠실야구장');
      expect(jamsil.isVisited, isFalse);
    });
  });

  group('잠실 외 구장은 1:1 매핑 + 방문 플래그 (R9)', () {
    test('스탬프 있는 구장만 isVisited=true', () {
      final markers = buildMapMarkers(
        stadiums: _tenStadiums(),
        stamps: [_stamp('s-suwon')],
      );
      expect(markers.firstWhere((m) => m.id == 's-suwon').isVisited, isTrue);
      expect(markers.firstWhere((m) => m.id == 's-busan').isVisited, isFalse);
    });

    test('잠실 외 8구장은 좌표·이름이 1:1 로 보존된다', () {
      final markers = buildMapMarkers(stadiums: _tenStadiums(), stamps: const []);
      final suwon = markers.firstWhere((m) => m.id == 's-suwon');
      expect(suwon.name, '수원KT위즈파크');
      expect(suwon.lat, 37.2997);
      expect(suwon.lng, 127.0098);
    });
  });

  group('경로 좌표 시퀀스 (R10)', () {
    test('stamped_at 오름차순으로 정렬된 구장 좌표 시퀀스', () {
      // 입력은 시간 역순으로 섞어 넣는다 — 방문일자 오름차순 재정렬을 검증.
      final route = buildStadiumRouteSequence(
        stadiums: _tenStadiums(),
        stamps: [
          _stampAt('s-busan', DateTime.utc(2026, 5, 3)),
          _stampAt('s-suwon', DateTime.utc(2026, 5, 1)),
          _stampAt('s-daegu', DateTime.utc(2026, 5, 2)),
        ],
      );
      expect(route, [
        (37.2997, 127.0098), // 수원 (5/1)
        (35.8410, 128.6816), // 대구 (5/2)
        (35.1940, 129.0615), // 부산 (5/3)
      ]);
    });

    test('좌표는 stamp 가 아닌 stadium.lat/lng 에서 온다', () {
      // _stampAt 의 lat/lng 는 0 — 그대로 나오면 안 된다.
      final route = buildStadiumRouteSequence(
        stadiums: _tenStadiums(),
        stamps: [
          _stampAt('s-suwon', DateTime.utc(2026, 5, 1)),
          _stampAt('s-daegu', DateTime.utc(2026, 5, 2)),
        ],
      );
      expect(route, [(37.2997, 127.0098), (35.8410, 128.6816)]);
    });

    test('연속 동일 좌표(잠실 두 칸 연속 방문)는 중복 제거된다', () {
      final route = buildStadiumRouteSequence(
        stadiums: _tenStadiums(),
        stamps: [
          _stampAt('s-suwon', DateTime.utc(2026, 5, 1)),
          _stampAt('stadium-jamsil-ob', DateTime.utc(2026, 5, 2)),
          _stampAt('stadium-jamsil-lg', DateTime.utc(2026, 5, 3)),
        ],
      );
      // 수원 → 잠실 → (잠실 중복 제거) : 길이 2.
      expect(route, [(37.2997, 127.0098), (_jamsilLat, _jamsilLng)]);
    });

    test('비연속으로 다시 같은 좌표(A→B→A)는 유지된다', () {
      // 수원 좌표를 공유하는 두 번째 행을 추가해 A→B→A 를 만든다.
      final stadiums = [
        ..._tenStadiums(),
        _stadium(
          id: 's-suwon2',
          name: '수원 임시',
          lat: 37.2997,
          lng: 127.0098,
          teamId: 't-kt',
          teamAbbr: 'KT',
        ),
      ];
      final route = buildStadiumRouteSequence(
        stadiums: stadiums,
        stamps: [
          _stampAt('s-suwon', DateTime.utc(2026, 5, 1)),
          _stampAt('s-daegu', DateTime.utc(2026, 5, 2)),
          _stampAt('s-suwon2', DateTime.utc(2026, 5, 3)),
        ],
      );
      // s-suwon2 는 수원과 같은 좌표지만 대구를 사이에 두므로 유지.
      expect(route, [
        (37.2997, 127.0098),
        (35.8410, 128.6816),
        (37.2997, 127.0098),
      ]);
    });

    test('방문 0칸 → 빈 시퀀스 ("경로 없음")', () {
      final route = buildStadiumRouteSequence(
        stadiums: _tenStadiums(),
        stamps: const [],
      );
      expect(route, isEmpty);
    });

    test('방문 1칸 → 길이<2 시퀀스 ("경로 없음")', () {
      final route = buildStadiumRouteSequence(
        stadiums: _tenStadiums(),
        stamps: [_stampAt('s-suwon', DateTime.utc(2026, 5, 1))],
      );
      expect(route.length, lessThan(2));
    });

    test('잠실 두 칸만 연속 방문 → dedup 후 길이1 → "경로 없음"', () {
      final route = buildStadiumRouteSequence(
        stadiums: _tenStadiums(),
        stamps: [
          _stampAt('stadium-jamsil-ob', DateTime.utc(2026, 5, 1)),
          _stampAt('stadium-jamsil-lg', DateTime.utc(2026, 5, 2)),
        ],
      );
      expect(route.length, lessThan(2));
    });
  });
}
