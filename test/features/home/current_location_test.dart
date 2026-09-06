/// Step 5.2 순수 로직 시험 — [currentLocationVisible]·[currentLocationLabel]·
/// [currentLocationIsFresh]·[currentLocationNeedsPermissionAnswer].
///
/// 화면에 실제로 뜨는지는 `home_screen_test.dart` 가 재고, 여기서는 방문
/// 판정 여섯 갈래(null + 다섯 이유)를 가시성·문구로 접는 규칙과, 그 판정을
/// **지금**이라고 말해도 되는지를 가르는 규칙만 촘촘히 잰다.
///
/// 마지막 group 만 위젯 시험이다 — [currentLocationIsFresh] 가 재는 성질은
/// 순수 함수로 다 재어지지만, **그 함수가 실제로 다시 불리는 계기**는 함수
/// 바깥에 있어서 값으로 잴 수 없다. 그 계기를 두지 않아 홈이 옛 구장을 계속
/// 가리킨 것이 phase 5 통합 검증 round 2 의 REJECT 사유였다.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/home/current_location.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart'
    show clockProvider;
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';

/// 시나리오 도중에 앞으로 가는 시계.
class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

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
      expect(currentLocationVisible(null, lastRunJudged: false), isFalse);
      expect(
        currentLocationVisible(
          null,
          lastRunJudged: false,
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
            lastRunJudged: false,
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
            lastRunJudged: false,
            askedPermission: LocationPermissionStatus.denied,
          ),
          isFalse,
        );
        expect(
          currentLocationVisible(
            null,
            judgmentAttempted: true,
            lastRunJudged: false,
          ),
          isFalse,
        );
      });
    });

    group('마지막 시도가 판정까지 가지 못한 실행 (round 3 의 REJECT 를 닫는 못)', () {
      // 도장을 받고 나면 4.2 의 게이트가 시간 창이 닫힐 때까지 판정을 통째로
      // 건너뛴다. 그동안 손에 든 판정은 **권한이 있던 시절**의 답이라, 그
      // 안의 "권한이 있었다"를 지금으로 읽으면 OS 설정에서 권한을 끄고 돌아온
      // 사람의 홈 상단이 최대 다섯 시간 그대로 선다
      // (`phase5_integration_round3_probe_test.dart` 의 Q1 이 그 자리를 걷는다).
      for (final reason in [
        StadiumVisitReason.visited,
        StadiumVisitReason.locationUnavailable,
        StadiumVisitReason.outsideRadius,
        StadiumVisitReason.outsideTimeWindow,
      ]) {
        final visit = reason == StadiumVisitReason.visited
            ? visited
            : StadiumVisitResult.rejected(reason);

        test('${reason.name}: 권한을 다시 물어 denied 면 접는다', () {
          expect(
            currentLocationVisible(
              visit,
              judgmentAttempted: true,
              lastRunJudged: true,
              askedPermission: LocationPermissionStatus.denied,
            ),
            isTrue,
            reason: '그 판정이 마지막 실행의 답이면 권한을 이미 확인한 것이다',
          );
          expect(
            currentLocationVisible(
              visit,
              judgmentAttempted: true,
              lastRunJudged: false,
              askedPermission: LocationPermissionStatus.denied,
            ),
            isFalse,
            reason: '판정까지 가지 못한 실행 뒤에는 옛 판정이 권한을 말해 주지 못한다',
          );
        });

        test('${reason.name}: 권한이 그대로 granted 면 자리는 남는다', () {
          expect(
            currentLocationVisible(
              visit,
              judgmentAttempted: true,
              lastRunJudged: false,
              askedPermission: LocationPermissionStatus.granted,
            ),
            isTrue,
            reason: 'acceptance 첫 문장 — 권한이 있는 사람의 자리를 뺏지 않는다',
          );
        });

        test('${reason.name}: 아직 답이 없으면(조회 로딩 중) 접는다', () {
          expect(
            currentLocationVisible(
              visit,
              judgmentAttempted: true,
              lastRunJudged: false,
            ),
            isFalse,
          );
        });
      }

      test('permissionMissing 은 다시 물어 granted 를 받으면 그린다', () {
        // 판정을 못 한 실행 뒤라 옛 `permissionMissing` 도 옛 사실이다 —
        // 그사이 설정에서 권한을 켰다면 자리가 서야 한다(acceptance 첫 문장).
        expect(
          currentLocationVisible(
            const StadiumVisitResult.rejected(
              StadiumVisitReason.permissionMissing,
            ),
            judgmentAttempted: true,
            lastRunJudged: false,
            askedPermission: LocationPermissionStatus.granted,
          ),
          isTrue,
        );
      });
    });

    test('permissionMissing 은 접는다 — 권한이 없다는 뜻', () {
      expect(
        currentLocationVisible(
          const StadiumVisitResult.rejected(
            StadiumVisitReason.permissionMissing,
          ),
          judgmentAttempted: true,
          lastRunJudged: true,
        ),
        isFalse,
      );
    });

    test('noGameToday 는 기본값(권한 답 없음)으로는 접는다', () {
      expect(
        currentLocationVisible(
          const StadiumVisitResult.rejected(StadiumVisitReason.noGameToday),
          judgmentAttempted: true,
          lastRunJudged: true,
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
            judgmentAttempted: true,
            lastRunJudged: true,
            askedPermission: LocationPermissionStatus.granted,
          ),
          isTrue,
        );
      });

      test('권한이 denied 면 접는다', () {
        expect(
          currentLocationVisible(
            rejected,
            judgmentAttempted: true,
            lastRunJudged: true,
            askedPermission: LocationPermissionStatus.denied,
          ),
          isFalse,
        );
      });

      test('권한이 permanentlyDenied 면 접는다', () {
        expect(
          currentLocationVisible(
            rejected,
            judgmentAttempted: true,
            lastRunJudged: true,
            askedPermission: LocationPermissionStatus.permanentlyDenied,
          ),
          isFalse,
        );
      });

      test('아직 답이 없으면(null — provider 로딩 중) 접는다', () {
        expect(
          currentLocationVisible(
            rejected,
            judgmentAttempted: true,
            lastRunJudged: true,
            askedPermission: null,
          ),
          isFalse,
        );
      });

      test('noGameToday 가 아닌 갈래에서는 askedPermission 이 granted 여도 영향이 없다', () {
        // 이미 그리는 갈래(outsideRadius)가 이 매개변수 때문에 접히지
        // 않는다는 것과, 이미 접는 갈래(permissionMissing)가 이 매개변수
        // 때문에 그려지지 않는다는 것을 함께 확인한다. (마지막 실행이
        // 판정까지 갔을 때의 이야기다 — 그렇지 않은 갈래는 위 group 이 잰다.)
        expect(
          currentLocationVisible(
            const StadiumVisitResult.rejected(
              StadiumVisitReason.outsideRadius,
            ),
            judgmentAttempted: true,
            lastRunJudged: true,
            askedPermission: LocationPermissionStatus.denied,
          ),
          isTrue,
        );
        expect(
          currentLocationVisible(
            const StadiumVisitResult.rejected(
              StadiumVisitReason.permissionMissing,
            ),
            judgmentAttempted: true,
            lastRunJudged: true,
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
          currentLocationVisible(
            StadiumVisitResult.rejected(reason),
            judgmentAttempted: true,
            lastRunJudged: true,
          ),
          isTrue,
        );
      });
    }

    test('visited 는 그린다', () {
      expect(
        currentLocationVisible(
          visited,
          judgmentAttempted: true,
          lastRunJudged: true,
        ),
        isTrue,
      );
    });
  });

  // 두 함수는 **같은 갈래**를 갈라야 한다: 물어야 하는 갈래에서 자리를 정하는
  // 것이 다시 물은 답이고, 물을 까닭이 없는 갈래에서는 그 답이 늘 null 이다.
  // 한쪽만 고치면 자리가 영영 접히거나(물어야 하는데 안 묻는다) 물을 까닭
  // 없는 조회가 생긴다 — 그 어긋남을 값으로 붙잡아 두는 자리다.
  group('두 함수의 갈래가 어긋나지 않는다', () {
    final visits = <StadiumVisitResult?>[
      null,
      visited,
      for (final reason in StadiumVisitReason.values)
        if (reason != StadiumVisitReason.visited)
          StadiumVisitResult.rejected(reason),
    ];

    for (final visit in visits) {
      for (final attempted in [true, false]) {
        for (final judged in [true, false]) {
          final name =
              '${visit?.reason.name ?? 'null'} '
              '(attempted: $attempted, judged: $judged)';
          test(name, () {
            final needs = currentLocationNeedsPermissionAnswer(
              visit,
              judgmentAttempted: attempted,
              lastRunJudged: judged,
            );
            bool visible(LocationPermissionStatus? asked) =>
                currentLocationVisible(
                  visit,
                  judgmentAttempted: attempted,
                  lastRunJudged: judged,
                  askedPermission: asked,
                );

            if (needs) {
              expect(
                visible(LocationPermissionStatus.granted),
                isTrue,
                reason: '물어야 하는 갈래에서는 다시 물은 답이 자리를 정한다',
              );
              expect(visible(LocationPermissionStatus.denied), isFalse);
              expect(
                visible(null),
                isFalse,
                reason: '아직 모르는데 그리지 않는다',
              );
            } else {
              expect(
                visible(LocationPermissionStatus.granted),
                visible(LocationPermissionStatus.denied),
                reason: '물을 까닭이 없는 갈래에서는 그 답이 자리를 바꾸지 못한다',
              );
              expect(
                visible(null),
                visible(LocationPermissionStatus.granted),
                reason: '같은 까닭 — 그 갈래에서 부르는 쪽은 늘 null 을 넘긴다',
              );
            }
          });
        }
      }
    }
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
        currentLocationNeedsPermissionAnswer(
          null,
          judgmentAttempted: false,
          lastRunJudged: false,
        ),
        isFalse,
      );
    });

    test('판정이 없는데 트리거는 돌았으면 묻는다', () {
      expect(
        currentLocationNeedsPermissionAnswer(
          null,
          judgmentAttempted: true,
          lastRunJudged: false,
        ),
        isTrue,
      );
    });

    test('noGameToday 면 묻는다', () {
      expect(
        currentLocationNeedsPermissionAnswer(
          const StadiumVisitResult.rejected(StadiumVisitReason.noGameToday),
          judgmentAttempted: true,
          lastRunJudged: true,
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
            lastRunJudged: true,
          ),
          isFalse,
        );
      });

      test('${reason.name} 도 마지막 시도가 판정까지 못 갔으면 묻는다', () {
        // 그 판정은 이 실행의 답이 아니다 — 4.2 의 게이트가 닫혔거나
        // 콘텐츠를 못 얻은 실행 뒤라, 권한을 다시 물어야만 알 수 있다.
        expect(
          currentLocationNeedsPermissionAnswer(
            StadiumVisitResult.rejected(reason),
            judgmentAttempted: true,
            lastRunJudged: false,
          ),
          isTrue,
        );
      });
    }

    test('visited 도 묻지 않는다', () {
      expect(
        currentLocationNeedsPermissionAnswer(
          visited,
          judgmentAttempted: true,
          lastRunJudged: true,
        ),
        isFalse,
      );
    });

    test('visited 도 마지막 시도가 판정까지 못 갔으면 묻는다 — round 3 의 그 갈래', () {
      expect(
        currentLocationNeedsPermissionAnswer(
          visited,
          judgmentAttempted: true,
          lastRunJudged: false,
        ),
        isTrue,
      );
    });
  });

  group('나이를 다시 재는 계기 (CurrentLocationRow)', () {
    // **왜 여기에 위젯 시험이 있는가.** 위 순수 함수 시험들은 "판정이 낡으면
    // 구장 이름을 쓰지 않는다"를 값으로 다 재지만, 그 함수가 **언제 다시
    // 불리는지**는 함수 밖의 일이다. round 1 은 성질만 세우고 계기를 두지
    // 않아서, 홈이 다시 서지 않는 실행(앱을 포그라운드에 둔 채 구장을 떠난
    // 사람)에서 옛 구장 이름이 두 시간 반 동안 그대로 섰다. 아래 둘이 그
    // 계기를 각각 못 박는다 — 하나라도 지우면 빨간불이다.
    const t0 = '2026-08-29T19:00:00+09:00';

    Future<ValueNotifier<bool>> pumpRow(
      WidgetTester tester, {
      required _Clock clock,
      required DateTime judgedAt,
      bool visible = true,
    }) async {
      final on = ValueNotifier<bool>(visible);
      addTearDown(on.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [clockProvider.overrideWithValue(clock.call)],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: on,
                builder: (context, enabled, child) => TickerMode(
                  // 탭 골격(`main_tab_scaffold.dart`)이 보이지 않는 탭에
                  // 씌우는 것과 같은 신호다.
                  enabled: enabled,
                  child: CurrentLocationRow(
                    visit: visited,
                    stadiums: stadiumsDoc,
                    judgedAt: judgedAt,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return on;
    }

    testWidgets('시각이 흐르는 것만으로 구장 이름이 내려온다 — 아무도 아무 일을 하지 않아도', (
      tester,
    ) async {
      final clock = _Clock(DateTime.parse(t0));
      await pumpRow(tester, clock: clock, judgedAt: clock.now);
      expect(find.text('잠실야구장 근처예요'), findsOneWidget);

      // 사람은 아무것도 하지 않았다 — 탭도 옮기지 않았고 앱을 배경으로
      // 보내지도 않았다. 흐른 것은 시각뿐이다.
      clock.now = clock.now.add(const Duration(minutes: 16));
      await tester.pump(const Duration(minutes: 16));

      expect(
        find.text('잠실야구장 근처예요'),
        findsNothing,
        reason: 'kCurrentLocationFreshness(15분)를 넘긴 판정을 "지금"이라고 말하지 않는다',
      );
      expect(find.text(kCurrentLocationGenericLabel), findsOneWidget);
    });

    testWidgets('보이지 않는 동안에는 재지 않고, 다시 보이는 순간 그 자리에서 잰다', (
      tester,
    ) async {
      final clock = _Clock(DateTime.parse(t0));
      final on = await pumpRow(tester, clock: clock, judgedAt: clock.now);
      expect(find.text('잠실야구장 근처예요'), findsOneWidget);

      // 다른 탭으로 옮겼다 — 이 자리를 볼 사람이 없는 동안에는 타이머를
      // 두지 않는다(그래서 시각이 흘러도 문구가 그대로다).
      on.value = false;
      await tester.pump();
      clock.now = clock.now.add(const Duration(minutes: 16));
      await tester.pump(const Duration(minutes: 16));
      expect(find.text('잠실야구장 근처예요'), findsOneWidget);

      // 홈 탭으로 돌아왔다 — 그 순간 나이를 새로 잰다.
      on.value = true;
      await tester.pump();
      expect(
        find.text('잠실야구장 근처예요'),
        findsNothing,
        reason: '탭 골격이 IndexedStack 이라 홈은 다시 서지 않는다 — 이 계기가 없으면 옛 구장이 남는다',
      );
      expect(find.text(kCurrentLocationGenericLabel), findsOneWidget);
    });
  });
}
