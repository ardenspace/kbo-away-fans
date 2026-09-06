/// Step 5.2 순수 로직 시험 — [currentLocationVisible]·[currentLocationLabel].
///
/// 화면에 실제로 뜨는지는 `home_screen_test.dart` 가 재고, 여기서는 방문
/// 판정 여섯 갈래(null + 다섯 이유)를 가시성·문구로 접는 규칙만 촘촘히
/// 잰다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/current_location.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

void main() {
  late StadiumsDocument stadiumsDoc;

  setUpAll(() {
    stadiumsDoc = StadiumsDocument.fromJson(
      _readJson('content-pipeline/data/stadiums.json'),
    );
  });

  test('방문이 확정되면 그 구장 이름 + "근처예요"', () {
    final label = currentLocationLabel(
      visit: const StadiumVisitResult.visited(
        stadiumId: 'jamsil',
        gameId: '2026-08-25-jamsil-lg-doosan',
      ),
      stadiums: stadiumsDoc,
    );
    expect(label, '잠실야구장 근처예요');
  });

  test('구장 문서를 못 얻었으면 이름 대신 id 를 그대로 쓴다', () {
    final label = currentLocationLabel(
      visit: const StadiumVisitResult.visited(
        stadiumId: 'jamsil',
        gameId: '2026-08-25-jamsil-lg-doosan',
      ),
      stadiums: null,
    );
    expect(label, 'jamsil 근처예요');
  });

  test('아직 판정이 없으면(null) 일반 문구', () {
    expect(
      currentLocationLabel(visit: null, stadiums: stadiumsDoc),
      kCurrentLocationGenericLabel,
    );
  });

  for (final reason in [
    StadiumVisitReason.permissionMissing,
    StadiumVisitReason.noGameToday,
    StadiumVisitReason.locationUnavailable,
    StadiumVisitReason.outsideRadius,
    StadiumVisitReason.outsideTimeWindow,
  ]) {
    test('방문이 아닌 판정(${reason.name})도 일반 문구', () {
      expect(
        currentLocationLabel(
          visit: StadiumVisitResult.rejected(reason),
          stadiums: stadiumsDoc,
        ),
        kCurrentLocationGenericLabel,
      );
    });
  }

  group('currentLocationVisible', () {
    test('null(아직 판정 없음)은 접는다', () {
      expect(currentLocationVisible(null), isFalse);
    });

    test('permissionMissing 은 접는다 — 권한이 없다는 뜻', () {
      expect(
        currentLocationVisible(
          const StadiumVisitResult.rejected(
            StadiumVisitReason.permissionMissing,
          ),
        ),
        isFalse,
      );
    });

    test('noGameToday 는 기본값(권한 답 없음)으로는 접는다', () {
      expect(
        currentLocationVisible(
          const StadiumVisitResult.rejected(StadiumVisitReason.noGameToday),
        ),
        isFalse,
      );
    });

    group('noGameToday + noGameTodayPermission (계약 위반 시정)', () {
      // 권한이 있으면 오늘 경기가 없는 날에도 위치 자리가 떠야 한다
      // (acceptance 첫 문장). judgeStadiumVisit 이 noGameToday 갈래에서는
      // 권한 자체를 묻지 않으므로, 그 답은 이 매개변수로 밖에서 받는다.
      const rejected = StadiumVisitResult.rejected(
        StadiumVisitReason.noGameToday,
      );

      test('권한이 granted 면 그린다', () {
        expect(
          currentLocationVisible(
            rejected,
            noGameTodayPermission: LocationPermissionStatus.granted,
          ),
          isTrue,
        );
      });

      test('권한이 denied 면 접는다', () {
        expect(
          currentLocationVisible(
            rejected,
            noGameTodayPermission: LocationPermissionStatus.denied,
          ),
          isFalse,
        );
      });

      test('권한이 permanentlyDenied 면 접는다', () {
        expect(
          currentLocationVisible(
            rejected,
            noGameTodayPermission: LocationPermissionStatus.permanentlyDenied,
          ),
          isFalse,
        );
      });

      test('아직 답이 없으면(null — provider 로딩 중) 접는다', () {
        expect(
          currentLocationVisible(rejected, noGameTodayPermission: null),
          isFalse,
        );
      });

      test('noGameToday 가 아닌 갈래에서는 noGameTodayPermission 이 granted 여도 영향이 없다', () {
        // 이미 그리는 갈래(outsideRadius)가 이 매개변수 때문에 접히지
        // 않는다는 것과, 이미 접는 갈래(permissionMissing)가 이 매개변수
        // 때문에 그려지지 않는다는 것을 함께 확인한다.
        expect(
          currentLocationVisible(
            const StadiumVisitResult.rejected(
              StadiumVisitReason.outsideRadius,
            ),
            noGameTodayPermission: LocationPermissionStatus.denied,
          ),
          isTrue,
        );
        expect(
          currentLocationVisible(
            const StadiumVisitResult.rejected(
              StadiumVisitReason.permissionMissing,
            ),
            noGameTodayPermission: LocationPermissionStatus.granted,
          ),
          isFalse,
        );
      });
    });

    for (final reason in [
      StadiumVisitReason.locationUnavailable,
      StadiumVisitReason.outsideRadius,
      StadiumVisitReason.outsideTimeWindow,
    ]) {
      test('${reason.name} 은 그린다 — 권한을 이미 확인한 판정', () {
        expect(
          currentLocationVisible(StadiumVisitResult.rejected(reason)),
          isTrue,
        );
      });
    }

    test('visited 는 그린다', () {
      expect(
        currentLocationVisible(
          const StadiumVisitResult.visited(
            stadiumId: 'jamsil',
            gameId: 'g1',
          ),
        ),
        isTrue,
      );
    });
  });
}
