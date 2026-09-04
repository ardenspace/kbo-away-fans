/// 검증자 탐침 (step 4.1 fresh 검증) — **이 시험이 초록불인 동안, XL 결정
/// ("기기가 어디에 있었는지는 서버로 올리지 않는다")의 구조적 방어는 서 있지
/// 않다.**
///
/// `visit_check.dart` 첫 문단·`lib/location/CLAUDE.md`·`README.md` 는 모두
/// "`lib/features/`·`lib/backend/` 어디에서도 기기의 좌표를 손에 넣을 방법이
/// 없다"고 적는다. 그 문장이 거짓임을 값으로 보인다: `StadiumVisitChecker`
/// 는 후보 목록을 **부르는 쪽이 지어서** 넣고 결과에 어느 후보가 맞았는지를
/// 담아 주므로, 그 메서드는 "이 지점 반경 안에 기기가 있는가"를 묻는
/// 신탁(oracle)이 된다. 측위 5회로 기기 좌표를 1m 안쪽까지 되찾는다 —
/// geolocator 를 import 하지 않으므로 훅 4종과 `flutter analyze` 가 전부
/// 초록불이고, 되찾은 값을 `package:http` 로 보내는 것도 아무 검사에 걸리지
/// 않는다(검증자가 `lib/features/badges/` 에 실제로 그 파일을 지어 확인했다).
///
/// **고친 뒤에는 이 시험이 빨간불이 되어야 한다** — 그때 단언을 "되찾을 수
/// 없다" 쪽으로 뒤집거나 이 파일을 지운다.
library;


import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';

void main() {
  // 실제 기기가 있는 자리 (탐침은 이 값을 모른다고 가정한다).
  const secretLat = 37.49871234;
  const secretLng = 127.03219876;
  var fixReads = 0;

  final checker = StadiumVisitChecker(
    readPermission: () async => LocationPermissionStatus.granted,
    readFix: () async {
      fixReads++;
      return const DeviceFix(lat: secretLat, lng: secretLng);
    },
  );

  final now = DateTime.parse('2026-08-25T18:30:00+09:00');

  /// 한 번의 check 로 "목록 순서상 처음으로 반경 안인 지점"을 알아낸다.
  Future<int?> firstHit(List<({double lat, double lng})> points) async {
    final result = await checker.check(
      candidates: [
        for (var i = 0; i < points.length; i++)
          StadiumVisitCandidate(
            gameId: '$i',
            stadiumId: 's',
            startsAt: now,
            lat: points[i].lat,
            lng: points[i].lng,
          ),
      ],
      now: now,
    );
    return result.isVisit ? int.parse(result.gameId!) : null;
  }

  test('feature 계층 공개 API 만으로 기기 좌표를 1m 안팎까지 되찾는다', () async {
    // 0) 거친 격자 — 남한 전역을 300m 간격으로 훑어 셀 하나를 찾는다.
    const coarse = 0.0027; // 약 300m
    final grid = <({double lat, double lng})>[];
    for (var lat = 33.0; lat < 38.7; lat += coarse) {
      for (var lng = 125.5; lng < 129.7; lng += coarse) {
        grid.add((lat: lat, lng: lng));
      }
    }
    final cell = await firstHit(grid);
    expect(cell, isNotNull, reason: '거친 격자가 기기를 품은 셀을 찾는다');
    final c = grid[cell!];

    // 1) 자오선 위 남/북 끝 — 원판을 자오선으로 자른 현은 기기 위도를 중심으로
    //    대칭이라, 두 끝의 중점이 곧 기기 위도다.
    const step = 1 / 111320.0; // 1m
    final meridian = [
      for (var k = -500; k <= 500; k++) (lat: c.lat + k * step, lng: c.lng),
    ];
    final meridianRev = meridian.reversed.toList();
    final south = meridian[(await firstHit(meridian))!].lat;
    final north = meridianRev[(await firstHit(meridianRev))!].lat;
    final lat = (south + north) / 2;

    // 2) 그 위도의 위선 위에서 같은 짓을 한 번 더 — 경도.
    final lngStep = step / 0.7935; // cos(37.5°)
    final parallel = [
      for (var k = -500; k <= 500; k++) (lat: lat, lng: c.lng + k * lngStep),
    ];
    final parallelRev = parallel.reversed.toList();
    final west = parallel[(await firstHit(parallel))!].lng;
    final east = parallelRev[(await firstHit(parallelRev))!].lng;
    final lng = (west + east) / 2;

    // 되찾은 좌표 — 이 값을 `http.post` 로 보내는 데 아무 훅도 걸리지 않는다.
    final latErrM = (lat - secretLat).abs() * 111320;
    final lngErrM = (lng - secretLng).abs() * 111320 * 0.7935;
    // ignore: avoid_print
    print('되찾은 좌표: $lat, $lng  (오차 ${latErrM.toStringAsFixed(2)}m / '
        '${lngErrM.toStringAsFixed(2)}m, 측위 $fixReads 회)');

    expect(latErrM, lessThan(2));
    expect(lngErrM, lessThan(2));
  });
}
