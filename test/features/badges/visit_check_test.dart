/// Step 4.1 boundary tests — 구장 방문 판정.
///
/// 계약이 이름 지은 다섯 갈래를 그대로 잰다:
///   1. 반경 안 (+ 시간 창 안 + 그날 경기 있음) → 방문
///   2. 반경 밖 → 방문 아님
///   3. 시간 창 밖 → 방문 아님
///   4. 그날 경기 없음 → 방문 아님
///   5. 위치 권한 없음 → **판정을 시도하지 않고** 이유가 남는다
///
/// 그리고 계약의 나머지 두 문장도 여기서 잰다:
///   - "판정에 쓰인 좌표는 어디에도 저장되지 않고 서버로 가지 않는다" —
///     판정 결과가 좌표를 들고 나오지 않는다는 것을 값으로 확인한다(코드
///     구조 쪽 보증은 `lib/location/visit_check.dart` 문서 참조).
///   - "홈·원정을 구분하지 않는다" — 후보를 짓는 자리가 팀으로 거르지 않는다.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/badges/stadium_visit.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';

/// 잠실야구장 좌표(stadiums.json 과 같은 값의 근사) — 반경 계산의 기준점.
const double _jamsilLat = 37.5121;
const double _jamsilLng = 127.0719;

/// 위도 1도는 어디서나 약 111.32km — 정북으로 [meters] 만큼 옮긴 지점.
DeviceFix _northOf(double meters) =>
    DeviceFix(lat: _jamsilLat + meters / 111320.0, lng: _jamsilLng);

/// 오늘(KST) 잠실 18:30 경기 하나.
StadiumVisitCandidate _jamsilTonight({String gameId = 'g-jamsil'}) =>
    StadiumVisitCandidate(
      gameId: gameId,
      stadiumId: 'jamsil',
      startsAt: DateTime.parse('2026-08-25T18:30:00+09:00'),
      lat: _jamsilLat,
      lng: _jamsilLng,
    );

/// 게이트웨이·좌표 읽기를 기록하는 대역으로 지은 판정기.
///
/// [fixReads] 가 0 이라는 단언이 "판정을 시도하지 않았다"를 재는 자리다 —
/// 결과의 이유만 보면 좌표를 읽고 나서 버린 실행과 구분되지 않는다.
class _RecordingChecker {
  _RecordingChecker({
    this.permission = LocationPermissionStatus.granted,
    this.fix,
  });

  final LocationPermissionStatus permission;
  final DeviceFix? fix;

  int permissionReads = 0;
  int fixReads = 0;

  StadiumVisitChecker build() => StadiumVisitChecker(
    readPermission: () async {
      permissionReads++;
      return permission;
    },
    readFix: () async {
      fixReads++;
      return fix;
    },
  );
}

/// 테스트용 경기 픽스처 (next_away_game_test.dart 와 같은 모양).
Game _game({
  required String id,
  required String date,
  String startTime = '18:30',
  required String home,
  required String away,
  required String stadium,
  GameStatus status = GameStatus.scheduled,
  int? homeScore,
  int? awayScore,
  GameResult? result,
}) => Game(
  id: id,
  date: date,
  startTime: startTime,
  homeTeamId: home,
  awayTeamId: away,
  stadiumId: stadium,
  status: status,
  homeScore: homeScore,
  awayScore: awayScore,
  result: result,
);

Stadium _stadium(String id, double lat, double lng, List<String> homeTeams) =>
    Stadium(
      id: id,
      name: id,
      city: id,
      lat: lat,
      lng: lng,
      homeTeams: homeTeams,
    );

void main() {
  // 기준 시각: 2026-08-25(화) 잠실 18:30 경기의 1시간 전.
  final duringPregame = DateTime.parse('2026-08-25T17:30:00+09:00');

  group('judgeStadiumVisit — 다섯 갈래', () {
    test('1) 반경 안 · 시간 창 안 · 그날 경기 있음 → 방문', () {
      final result = judgeStadiumVisit(
        permission: LocationPermissionStatus.granted,
        candidates: [_jamsilTonight()],
        now: duringPregame,
        fix: _northOf(50),
      );

      expect(result.reason, StadiumVisitReason.visited);
      expect(result.isVisit, isTrue);
      // 4.2 가 칸을 가르려면 구장과 경기를 알아야 한다 (잠실은 두 칸).
      expect(result.stadiumId, 'jamsil');
      expect(result.gameId, 'g-jamsil');
    });

    test('2) 반경 밖이면 방문이 아니다', () {
      final result = judgeStadiumVisit(
        permission: LocationPermissionStatus.granted,
        candidates: [_jamsilTonight()],
        now: duringPregame,
        fix: _northOf(kStadiumVisitRadiusMeters + 200),
      );

      expect(result.reason, StadiumVisitReason.outsideRadius);
      expect(result.isVisit, isFalse);
      expect(result.stadiumId, isNull);
    });

    test('3) 시간 창 밖이면 방문이 아니다 (반경 안이어도)', () {
      final beforeWindow = DateTime.parse(
        '2026-08-25T18:30:00+09:00',
      ).subtract(kVisitWindowBeforeStart + const Duration(minutes: 1));
      final afterWindow = DateTime.parse(
        '2026-08-25T18:30:00+09:00',
      ).add(kVisitWindowAfterStart + const Duration(minutes: 1));

      for (final now in [beforeWindow, afterWindow]) {
        final result = judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: [_jamsilTonight()],
          now: now,
          fix: _northOf(50),
        );
        expect(
          result.reason,
          StadiumVisitReason.outsideTimeWindow,
          reason: '$now 는 시간 창 밖이다',
        );
      }
    });

    test('4) 그날 그 구장에 경기가 없으면 방문이 아니다', () {
      // 후보는 있으나 전부 다른 날짜 — 구장 한복판에 서 있어도 도장은 없다.
      final tomorrow = StadiumVisitCandidate(
        gameId: 'g-tomorrow',
        stadiumId: 'jamsil',
        startsAt: DateTime.parse('2026-08-26T18:30:00+09:00'),
        lat: _jamsilLat,
        lng: _jamsilLng,
      );

      final result = judgeStadiumVisit(
        permission: LocationPermissionStatus.granted,
        candidates: [tomorrow],
        now: duringPregame,
        fix: _northOf(0),
      );

      expect(result.reason, StadiumVisitReason.noGameToday);
    });

    test('5) 위치 권한이 없으면 방문이 아니고 이유가 남는다', () {
      for (final permission in [
        LocationPermissionStatus.denied,
        LocationPermissionStatus.permanentlyDenied,
      ]) {
        final result = judgeStadiumVisit(
          permission: permission,
          candidates: [_jamsilTonight()],
          now: duringPregame,
          fix: _northOf(0),
        );
        expect(result.reason, StadiumVisitReason.permissionMissing);
      }
    });
  });

  group('judgeStadiumVisit — 경계와 나머지 갈래', () {
    test('반경 경계는 포함이다', () {
      // 경계 바로 안(=1m 안쪽)은 방문, 바로 밖은 방문 아님.
      expect(
        judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: [_jamsilTonight()],
          now: duringPregame,
          fix: _northOf(kStadiumVisitRadiusMeters - 1),
        ).reason,
        StadiumVisitReason.visited,
      );
      expect(
        judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: [_jamsilTonight()],
          now: duringPregame,
          fix: _northOf(kStadiumVisitRadiusMeters + 1),
        ).reason,
        StadiumVisitReason.outsideRadius,
      );
    });

    test('시간 창 양 끝은 포함이다', () {
      final start = DateTime.parse('2026-08-25T18:30:00+09:00');
      for (final now in [
        start.subtract(kVisitWindowBeforeStart),
        start.add(kVisitWindowAfterStart),
      ]) {
        expect(
          judgeStadiumVisit(
            permission: LocationPermissionStatus.granted,
            candidates: [_jamsilTonight()],
            now: now,
            fix: _northOf(0),
          ).reason,
          StadiumVisitReason.visited,
          reason: '$now 는 창의 끝이라 포함이다',
        );
      }
    });

    test('좌표를 얻지 못하면 판정하지 않고 그 이유가 남는다', () {
      final result = judgeStadiumVisit(
        permission: LocationPermissionStatus.granted,
        candidates: [_jamsilTonight()],
        now: duringPregame,
        fix: null,
      );

      expect(result.reason, StadiumVisitReason.locationUnavailable);
    });

    test('더블헤더에서는 지금 창 안인 경기가 잡힌다', () {
      final first = StadiumVisitCandidate(
        gameId: 'g-1',
        stadiumId: 'jamsil',
        startsAt: DateTime.parse('2026-08-25T11:00:00+09:00'),
        lat: _jamsilLat,
        lng: _jamsilLng,
      );
      final second = _jamsilTonight(gameId: 'g-2');

      // 11:00 경기의 창은 16:00 에 닫히고, 18:30 경기의 창은 15:30 에 열린다.
      final result = judgeStadiumVisit(
        permission: LocationPermissionStatus.granted,
        candidates: [first, second],
        now: DateTime.parse('2026-08-25T17:00:00+09:00'),
        fix: _northOf(0),
      );

      expect(result.gameId, 'g-2');
    });

    test('가까운 구장이 여럿이면 지금 창 안인 구장이 잡힌다', () {
      // 같은 날 두 구장 — 하나는 창 밖, 하나는 창 안. 순서에 기대지 않는다.
      final closed = StadiumVisitCandidate(
        gameId: 'g-closed',
        stadiumId: 'gocheok',
        startsAt: DateTime.parse('2026-08-25T05:00:00+09:00'),
        lat: _jamsilLat,
        lng: _jamsilLng,
      );

      final result = judgeStadiumVisit(
        permission: LocationPermissionStatus.granted,
        candidates: [closed, _jamsilTonight()],
        now: duringPregame,
        fix: _northOf(0),
      );

      expect(result.stadiumId, 'jamsil');
    });
  });

  group('StadiumVisitChecker — 좌표를 언제 읽는가', () {
    test('권한이 없으면 좌표를 한 번도 읽지 않는다', () async {
      final recorder = _RecordingChecker(
        permission: LocationPermissionStatus.denied,
        fix: _northOf(0),
      );

      final result = await recorder.build().check(
        candidates: [_jamsilTonight()],
        now: duringPregame,
      );

      expect(result.reason, StadiumVisitReason.permissionMissing);
      expect(recorder.permissionReads, 1);
      expect(recorder.fixReads, 0, reason: '판정을 시도하지 않는다');
    });

    test('그날 경기가 없으면 권한도 좌표도 묻지 않는다', () async {
      final recorder = _RecordingChecker(fix: _northOf(0));

      final result = await recorder.build().check(
        candidates: const [],
        now: duringPregame,
      );

      expect(result.reason, StadiumVisitReason.noGameToday);
      expect(recorder.permissionReads, 0, reason: '판정할 것이 없는 날이다');
      expect(recorder.fixReads, 0);
    });

    test('경기 없는 날의 답은 순수 판정 함수의 답과 같다', () async {
      // 판정기가 이 한 갈래만 판정 함수를 거치지 않고 답하므로, 두 자리가
      // 어긋나지 않는다는 것을 값으로 못 박는다.
      final fromChecker = await _RecordingChecker(
        permission: LocationPermissionStatus.denied,
      ).build().check(candidates: const [], now: duringPregame);

      for (final permission in LocationPermissionStatus.values) {
        expect(
          judgeStadiumVisit(
            permission: permission,
            candidates: const [],
            now: duringPregame,
            fix: null,
          ).reason,
          fromChecker.reason,
        );
      }
    });

    test('그날 경기가 있고 권한이 있을 때만 좌표를 한 번 읽는다', () async {
      final recorder = _RecordingChecker(fix: _northOf(0));

      final result = await recorder.build().check(
        candidates: [_jamsilTonight()],
        now: duringPregame,
      );

      expect(result.isVisit, isTrue);
      expect(recorder.fixReads, 1);
    });
  });

  group('판정 결과는 좌표를 들고 나오지 않는다', () {
    test('결과에는 구장 id·경기 id·이유만 있다', () {
      final result = judgeStadiumVisit(
        permission: LocationPermissionStatus.granted,
        candidates: [_jamsilTonight()],
        now: duringPregame,
        fix: _northOf(37),
      );

      // 값으로 재는 자리 — 결과를 문자열로 펼쳐도 위도·경도의 자릿수가 없다.
      final printed = result.toString();
      expect(printed, contains('jamsil'));
      expect(printed, isNot(contains('37.5')));
      expect(printed, isNot(contains('127.0')));
    });
  });

  group('buildStadiumVisitCandidates — 홈·원정을 구분하지 않는다', () {
    final stadiums = StadiumsDocument(
      stadiums: [
        _stadium('jamsil', _jamsilLat, _jamsilLng, const ['lg', 'doosan']),
        _stadium('sajik', 35.1940, 129.0615, const ['lotte']),
      ],
    );

    test('내 팀이 뛰지 않는 경기도 후보다 — 그 구장에 있었는지만 본다', () {
      final schedule = ScheduleDocument(
        generatedAt: DateTime.utc(2026),
        games: [
          _game(
            id: 'g-jamsil',
            date: '2026-08-25',
            home: 'lg',
            away: 'doosan',
            stadium: 'jamsil',
          ),
        ],
      );

      final candidates = buildStadiumVisitCandidates(
        schedule: schedule,
        stadiums: stadiums,
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.stadiumId, 'jamsil');
      expect(
        judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: candidates,
          now: duringPregame,
          fix: _northOf(0),
        ).reason,
        StadiumVisitReason.visited,
      );
    });

    test('취소된 경기는 후보가 아니다 — 그날 그 구장에 경기가 없다', () {
      final schedule = ScheduleDocument(
        generatedAt: DateTime.utc(2026),
        games: [
          _game(
            id: 'g-rain',
            date: '2026-08-25',
            home: 'lg',
            away: 'doosan',
            stadium: 'jamsil',
            status: GameStatus.rainCanceled,
          ),
        ],
      );

      final candidates = buildStadiumVisitCandidates(
        schedule: schedule,
        stadiums: stadiums,
      );

      expect(candidates, isEmpty);
    });

    test('끝난 경기는 후보로 남는다 — 경기 뒤에 앱을 여는 사람이 있다', () {
      final schedule = ScheduleDocument(
        generatedAt: DateTime.utc(2026),
        games: [
          _game(
            id: 'g-done',
            date: '2026-08-25',
            home: 'lg',
            away: 'doosan',
            stadium: 'jamsil',
            status: GameStatus.finished,
            homeScore: 5,
            awayScore: 3,
            result: GameResult.homeWin,
          ),
        ],
      );

      final candidates = buildStadiumVisitCandidates(
        schedule: schedule,
        stadiums: stadiums,
      );

      expect(candidates.single.gameId, 'g-done');
      expect(
        candidates.single.startsAt,
        DateTime.parse('2026-08-25T18:30:00+09:00'),
      );
    });

    test('구장 문서에 없는 구장 id 는 조용히 건너뛴다', () {
      final schedule = ScheduleDocument(
        generatedAt: DateTime.utc(2026),
        games: [
          _game(
            id: 'g-unknown',
            date: '2026-08-25',
            home: 'kia',
            away: 'lotte',
            stadium: 'gwangju',
          ),
        ],
      );

      expect(
        buildStadiumVisitCandidates(schedule: schedule, stadiums: stadiums),
        isEmpty,
      );
    });
  });

  group('StadiumVisitTrigger — 앱이 열려 있을 때 판정이 실제로 돈다', () {
    final stadiums = StadiumsDocument(
      stadiums: [
        _stadium('jamsil', _jamsilLat, _jamsilLng, const ['lg', 'doosan']),
      ],
    );
    final schedule = ScheduleDocument(
      generatedAt: DateTime.utc(2026),
      games: [
        _game(
          id: 'g-jamsil',
          date: '2026-08-25',
          home: 'lg',
          away: 'doosan',
          stadium: 'jamsil',
        ),
      ],
    );

    /// 콘텐츠 4종·시계·판정기를 갈아 끼운 채 트리거만 띄운다.
    Future<ProviderContainer> pumpTrigger(
      WidgetTester tester, {
      required _RecordingChecker recorder,
      bool scheduleUnavailable = false,
    }) async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => duringPregame),
          stadiumsProvider.overrideWith(
            (ref) async => ContentFresh(stadiums),
          ),
          scheduleProvider.overrideWith(
            (ref) async => scheduleUnavailable
                ? const ContentUnavailable<ScheduleDocument>(
                    ContentIssue(ContentIssueKind.network, '테스트'),
                  )
                : ContentFresh(schedule),
          ),
          stadiumVisitCheckerProvider.overrideWithValue(recorder.build()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: StadiumVisitTrigger(child: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('첫 프레임에 판정이 돌고 결과가 남는다', (tester) async {
      final recorder = _RecordingChecker(fix: _northOf(0));
      final container = await pumpTrigger(tester, recorder: recorder);

      final result = container.read(stadiumVisitProvider);
      expect(result, isNotNull);
      expect(result!.isVisit, isTrue);
      expect(result.stadiumId, 'jamsil');
      expect(recorder.fixReads, 1);
    });

    testWidgets('포그라운드 복귀마다 다시 돈다', (tester) async {
      final recorder = _RecordingChecker(fix: _northOf(0));
      await pumpTrigger(tester, recorder: recorder);
      expect(recorder.fixReads, 1);

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(recorder.fixReads, 2, reason: '구장에 도착해 앱을 다시 켠 실행');
    });

    testWidgets('일정을 읽지 못한 실행에서는 판정하지 않고 상태가 비어 있다', (tester) async {
      final recorder = _RecordingChecker(fix: _northOf(0));
      final container = await pumpTrigger(
        tester,
        recorder: recorder,
        scheduleUnavailable: true,
      );

      expect(
        container.read(stadiumVisitProvider),
        isNull,
        reason: '"경기가 없다"와 "일정을 못 읽었다"를 같이 적지 않는다',
      );
      expect(recorder.permissionReads, 0);
      expect(recorder.fixReads, 0);
    });
  });
}
