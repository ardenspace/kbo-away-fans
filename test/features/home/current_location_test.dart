/// Step 5.2 순수 로직 시험 — [currentLocationVisible]·[currentLocationLabel]·
/// [currentLocationIsFresh]·[currentLocationNeedsPermissionAnswer].
///
/// 화면에 실제로 뜨는지는 `home_screen_test.dart` 가 재고, 여기서는 방문
/// 판정 여섯 갈래(null + 다섯 이유)를 가시성·문구로 접는 규칙과, 그 판정을
/// **지금**이라고 말해도 되는지를 가르는 규칙만 촘촘히 잰다.
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

  const visited = StadiumVisitResult.visited(
    stadiumId: 'jamsil',
    gameId: '2026-08-25-jamsil-lg-doosan',
  );

  test('방문이 확정되고 그 판정이 아직 새것이면 그 구장 이름 + "근처예요"', () {
    final label = currentLocationLabel(
      visit: visited,
      stadiums: stadiumsDoc,
      fresh: true,
    );
    expect(label, '잠실야구장 근처예요');
  });

  test('방문이 확정됐어도 판정이 오래됐으면 구장 이름을 쓰지 않는다', () {
    // (A) 를 닫는 못 — 도장을 받은 뒤 재판정 게이트가 닫혀 있는 동안 사람이
    // 구장을 떠나도 판정은 그대로다. 그 값을 "현재 위치"로 세우면 홈 상단이
    // 이미 떠난 구장을 가리킨다(phase 5 통합 검증의 REJECT 사유).
    expect(
      currentLocationLabel(
        visit: visited,
        stadiums: stadiumsDoc,
        fresh: false,
      ),
      kCurrentLocationGenericLabel,
    );
  });

  test('구장 문서를 못 얻었으면 이름 대신 id 를 그대로 쓴다', () {
    final label = currentLocationLabel(
      visit: visited,
      stadiums: null,
      fresh: true,
    );
    expect(label, 'jamsil 근처예요');
  });

  test('아직 판정이 없으면(null) 일반 문구', () {
    expect(
      currentLocationLabel(visit: null, stadiums: stadiumsDoc, fresh: true),
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
          fresh: true,
        ),
        kCurrentLocationGenericLabel,
      );
    });
  }

  group('currentLocationVisible', () {
    test('null 이고 트리거가 아직 돌지도 않았으면 접는다', () {
      expect(currentLocationVisible(null), isFalse);
      expect(
        currentLocationVisible(
          null,
          askedPermission: LocationPermissionStatus.granted,
        ),
        isFalse,
        reason: '판정을 시도조차 하지 않은 실행은 홈이 아직 아무것도 말할 수 없다',
      );
    });

    group('null + 트리거는 돌았음 (콘텐츠를 못 얻어 판정하지 못한 실행)', () {
      // 통합 검증 탐침 E 가 잰 자리 — 일정 문서를 못 얻으면 판정이 아예 돌지
      // 못해 결과가 null 로 남는데, 그때 권한이 있는 사람의 위치 자리까지
      // 통째로 접히면 권한을 거부한 사람의 화면과 구분되지 않는다.
      test('권한이 granted 면 그린다', () {
        expect(
          currentLocationVisible(
            null,
            judgmentAttempted: true,
            askedPermission: LocationPermissionStatus.granted,
          ),
          isTrue,
        );
      });

      test('권한이 denied 거나 아직 답이 없으면 접는다', () {
        expect(
          currentLocationVisible(
            null,
            judgmentAttempted: true,
            askedPermission: LocationPermissionStatus.denied,
          ),
          isFalse,
        );
        expect(
          currentLocationVisible(null, judgmentAttempted: true),
          isFalse,
        );
      });
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

    group('noGameToday + askedPermission (계약 위반 시정)', () {
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
            askedPermission: LocationPermissionStatus.granted,
          ),
          isTrue,
        );
      });

      test('권한이 denied 면 접는다', () {
        expect(
          currentLocationVisible(
            rejected,
            askedPermission: LocationPermissionStatus.denied,
          ),
          isFalse,
        );
      });

      test('권한이 permanentlyDenied 면 접는다', () {
        expect(
          currentLocationVisible(
            rejected,
            askedPermission: LocationPermissionStatus.permanentlyDenied,
          ),
          isFalse,
        );
      });

      test('아직 답이 없으면(null — provider 로딩 중) 접는다', () {
        expect(
          currentLocationVisible(rejected, askedPermission: null),
          isFalse,
        );
      });

      test('noGameToday 가 아닌 갈래에서는 askedPermission 이 granted 여도 영향이 없다', () {
        // 이미 그리는 갈래(outsideRadius)가 이 매개변수 때문에 접히지
        // 않는다는 것과, 이미 접는 갈래(permissionMissing)가 이 매개변수
        // 때문에 그려지지 않는다는 것을 함께 확인한다.
        expect(
          currentLocationVisible(
            const StadiumVisitResult.rejected(
              StadiumVisitReason.outsideRadius,
            ),
            askedPermission: LocationPermissionStatus.denied,
          ),
          isTrue,
        );
        expect(
          currentLocationVisible(
            const StadiumVisitResult.rejected(
              StadiumVisitReason.permissionMissing,
            ),
            askedPermission: LocationPermissionStatus.granted,
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

  group('currentLocationIsFresh', () {
    final judgedAt = DateTime.parse('2026-08-29T19:00:00+09:00');

    test('판정이 없었으면(마지막 시도가 건너뛰어졌으면) 새것이 아니다', () {
      expect(
        currentLocationIsFresh(judgedAt: null, now: judgedAt),
        isFalse,
      );
    });

    test('막 난 판정은 새것이다', () {
      expect(currentLocationIsFresh(judgedAt: judgedAt, now: judgedAt), isTrue);
    });

    test('상한 그대로는 아직 새것이다 (경계는 포함)', () {
      expect(
        currentLocationIsFresh(
          judgedAt: judgedAt,
          now: judgedAt.add(kCurrentLocationFreshness),
        ),
        isTrue,
      );
    });

    test('상한을 1초라도 넘기면 새것이 아니다', () {
      expect(
        currentLocationIsFresh(
          judgedAt: judgedAt,
          now: judgedAt.add(kCurrentLocationFreshness).add(
            const Duration(seconds: 1),
          ),
        ),
        isFalse,
      );
    });

    test('구장을 떠난 두 시간 뒤는 새것이 아니다 (REJECT 사유의 그 시각)', () {
      expect(
        currentLocationIsFresh(
          judgedAt: judgedAt,
          now: DateTime.parse('2026-08-29T21:30:00+09:00'),
        ),
        isFalse,
      );
    });

    test('시계가 뒤로 뛴 실행도 새것으로 보지 않는다', () {
      expect(
        currentLocationIsFresh(
          judgedAt: judgedAt,
          now: judgedAt.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });
  });

  group('currentLocationNeedsPermissionAnswer', () {
    test('판정이 없고 트리거도 안 돌았으면 묻지 않는다', () {
      expect(
        currentLocationNeedsPermissionAnswer(null, judgmentAttempted: false),
        isFalse,
      );
    });

    test('판정이 없는데 트리거는 돌았으면 묻는다', () {
      expect(
        currentLocationNeedsPermissionAnswer(null, judgmentAttempted: true),
        isTrue,
      );
    });

    test('noGameToday 면 묻는다', () {
      expect(
        currentLocationNeedsPermissionAnswer(
          const StadiumVisitResult.rejected(StadiumVisitReason.noGameToday),
          judgmentAttempted: true,
        ),
        isTrue,
      );
    });

    for (final reason in [
      StadiumVisitReason.permissionMissing,
      StadiumVisitReason.locationUnavailable,
      StadiumVisitReason.outsideRadius,
      StadiumVisitReason.outsideTimeWindow,
    ]) {
      test('${reason.name} 은 판정이 이미 답했으므로 묻지 않는다', () {
        expect(
          currentLocationNeedsPermissionAnswer(
            StadiumVisitResult.rejected(reason),
            judgmentAttempted: true,
          ),
          isFalse,
        );
      });
    }

    test('visited 도 묻지 않는다', () {
      expect(
        currentLocationNeedsPermissionAnswer(
          const StadiumVisitResult.visited(stadiumId: 'jamsil', gameId: 'g1'),
          judgmentAttempted: true,
        ),
        isFalse,
      );
    });
  });
}
