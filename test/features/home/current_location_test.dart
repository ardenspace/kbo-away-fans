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

    test('noGameToday 는 접는다 — 권한조차 묻지 않은 판정', () {
      expect(
        currentLocationVisible(
          const StadiumVisitResult.rejected(StadiumVisitReason.noGameToday),
        ),
        isFalse,
      );
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
