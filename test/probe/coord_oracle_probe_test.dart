/// 판정 API 의 **알려진 성질**을 값으로 붙잡아 두는 탐침 (step 4.1).
///
/// **이 시험이 초록불인 것은 결함이 아니다.** `.wellbegun/decisions.md`
/// 2026-09-04 `[L]` 이 기록한 성질을 그대로 재고 있고, 그 결정이 이 앱의
/// 약속을 "구조적으로 불가능하다"에서 **"앱의 코드가 좌표를 서버로 보내지
/// 않으며, 그렇게 하려면 눈에 띄는 의도적 변경이 필요하다"**로 낮춰 썼다.
/// 그러니 여기서 멈추지 말고 그 결정 줄과 `lib/location/visit_check.dart` 첫
/// 문단("하지 않는 약속")으로 이어 읽을 것.
///
/// 재는 성질: `StadiumVisitChecker.check` 는 후보 목록을 **부르는 쪽이
/// 지어서** 넣고 결과에 어느 후보가 맞았는지를 담아 주므로, "이 지점 반경
/// 안에 기기가 있는가"를 묻는 신탁(oracle)이다. 자오선·위선 위에 후보를
/// 늘어놓고 정순·역순으로 물으면 원판의 양 끝이 나오고 그 중점이 곧 기기
/// 좌표라, 측위 다섯 번이면 1m 안쪽까지 되찾는다. `geolocator` 를 import
/// 하지 않으므로 import 경계 훅도 이 코드를 보지 못한다.
///
/// **왜 지우지 않는가.** 이 파일이 없으면 다음 사람이 첫 문단의 "하지 않는
/// 약속"을 서술로만 읽고, 신탁을 없앴다고 믿는 변경(후보 개수 상한 같은 것)을
/// 넣으면서 절대문을 다시 써 넣게 된다. 이 시험은 그 믿음이 참인지 값으로
/// 답한다 — 언젠가 이 성질이 실제로 사라진다면 **그때** 이 시험이 빨간불이
/// 되고, 그 자리가 곧 약속을 다시 쓸 근거가 생기는 자리다.
///
/// **자리에 대해.** `test/probe/` 에 그대로 둔다 — 위 `[L]` 결정 줄이 이
/// 경로를 이름으로 부르고 있어서, 옮기면 그 줄이 없는 파일을 가리키게 된다.
/// 이 폴더의 짝은 `test/features/badges/visit_check_test.dart`(경계 시험)이고,
/// 그 파일 머리가 이쪽을 가리킨다.
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

    // 되찾은 좌표. 이 값을 `lib/location/` 안에서 보내려 하면 이제
    // `check-no-location-upload.sh` 가 네트워크 패키지 import 에서 막지만,
    // 신탁을 부르는 쪽인 `lib/features/` 에서는 막는 검사가 없다 — 그것이
    // 이 앱이 "구조적으로 불가능하다"를 약속하지 않는 까닭이다.
    final latErrM = (lat - secretLat).abs() * 111320;
    final lngErrM = (lng - secretLng).abs() * 111320 * 0.7935;
    // ignore: avoid_print
    print('되찾은 좌표: $lat, $lng  (오차 ${latErrM.toStringAsFixed(2)}m / '
        '${lngErrM.toStringAsFixed(2)}m, 측위 $fixReads 회)');

    expect(latErrM, lessThan(2));
    expect(lngErrM, lessThan(2));
  });
}
