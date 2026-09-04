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
///   - "판정에 쓰인 좌표는 어디에도 저장되지 않고 서버로 가지 않는다" — 두
///     자리에서 잰다. (a) 판정 결과가 좌표를 들고 나오지 않는다는 것을 값으로
///     확인하고, 그 타입이 **값을 두는 자리 집합 자체**를 소스 텍스트로 못
///     박는다(문자열 시험 하나만으로는 결과 타입에 좌표 필드를 더하는 변이가
///     그대로 통과한다 — `.wellbegun/decisions.md` 2026-09-04 `[S]`).
///     (b) 좌표를 얻는 통로가 `lib/location/` 안에서만 보인다는 것
///     (`visit_check.dart` 첫 문단의 겹 1)을 같은 방식으로 소스에서 잰다 —
///     round 3 이전에는 그 겹을 재는 검사도 시험도 하나도 없었다.
///   - "홈·원정을 구분하지 않는다" — 후보를 짓는 자리가 팀으로 거르지 않는다.
///
/// 그리고 계약 Goal 의 "앱이 열려 있을 때 위치를 한 번 받는다"는 트리거 위젯
/// 자체가 아니라 **그 위젯이 앱 골격에 매달려 있는지**로 잰다(마지막 케이스).
///
/// **짝 파일:** `test/location/stadium_visit_fix_contract_test.dart` 는 실
/// 측위 함수와 권한 조회를 플랫폼 인터페이스로 재고,
/// `test/probe/coord_oracle_probe_test.dart` 는 이 판정 API 가 신탁으로 쓰이는
/// **알려진 성질**을 값으로 붙잡아 둔다(초록불인 것이 맞다 —
/// `.wellbegun/decisions.md` 2026-09-04 `[L]`).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/badges/stadium_visit.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';

/// 잠실야구장 좌표(stadiums.json 과 같은 값의 근사) — 반경 계산의 기준점.
const double _jamsilLat = 37.5121;
const double _jamsilLng = 127.0719;

/// 골격 시험이 쓰는 계정 — 로그인한 사람만 판정 트리거에 닿는다.
const String _uid = 'google-uid';

/// 이 시험이 보지 않는 콘텐츠 문서를 "못 읽었다"로 채우는 값.
const ContentIssue _fixture = ContentIssue(ContentIssueKind.network, 'fixture');

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
    this.fixGate,
  });

  final LocationPermissionStatus permission;
  final DeviceFix? fix;

  /// 있으면 측위가 이 신호를 기다린다 — 판정이 **도는 중**인 상태를 만들어
  /// 겹침 방지를 잴 수 있게 한다.
  final Completer<void>? fixGate;

  int permissionReads = 0;
  int fixReads = 0;

  StadiumVisitChecker build() => StadiumVisitChecker(
    readPermission: () async {
      permissionReads++;
      return permission;
    },
    readFix: () async {
      fixReads++;
      await fixGate?.future;
      return fix;
    },
  );
}

/// 소스 텍스트에서 클래스 [name] 의 몸통을 잘라 온다 — 중괄호를 세는 거친
/// 파서다(계약을 소스로 대조하는 `test/cross_layer_seams_test.dart` 의 선례와
/// 같은 방식이고, 파싱이 어긋나면 조용히 통과하는 대신 빨간불이 된다).
String _classBody(String source, String name) {
  final head = source.indexOf('class $name {');
  expect(head, isNonNegative, reason: '$name 을 소스에서 찾지 못했다');
  final open = source.indexOf('{', head);
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('$name 의 닫는 중괄호를 찾지 못했다');
}

/// 클래스 몸통이 **선언한 값 자리**를 이름→선언 앞부분 표로 편다.
///
/// 두 칸 들여쓴 줄 중 이름 뒤에 `;` 나 `=` 가 오는 것만 보므로, 메서드·생성자
/// (이름 뒤에 `(` 가 온다)와 메서드 안의 지역 변수(더 깊이 들여쓴다)는 섞이지
/// 않는다. 표에 담는 값이 타입만이 아니라 **수식어까지**(`static`·`final`·
/// `var`·`get`) 인 것이 옛 `^  final (.+) (\w+);$` 정규식과 다른 점이다:
/// 그 정규식은 `final` 로 시작하지 않는 선언을 아예 보지 못해서
/// `static DeviceFix? lastSpot;` 한 줄이 파수꾼과 훅을 함께 통과했고, 그 필드는
/// `StadiumVisitResult.lastSpot!.lat` 으로 라이브러리 밖에서 읽혔다
/// (4.1 round 3 지휘자 재현 — 경계 시험 30개·`check-no-location-upload.sh`
/// 전부 초록불이었다).
Map<String, String> _declaredStorage(String body) => {
  for (final match in RegExp(
    r'^  ((?:static |late |final |const |var |covariant )*'
    r'[A-Za-z_][A-Za-z0-9_<>?,.() ]*?) (\w+) *(?:;|=)',
    multiLine: true,
  ).allMatches(body))
    match.group(2)!: match.group(1)!,
};

/// 소스의 **코드 줄**이 각각 어느 최상위 선언 안에 있는지를 이름으로 붙여
/// 돌려준다.
///
/// 열 0 에서 식별자로 시작하는 줄을 새 선언의 머리로 보고, 그 줄에서 `(` 나
/// `=` 앞에 오는 **첫** 식별자를 이름으로 잡는다: 측위 함수 선언 줄에서는
/// `_readDeviceFix` 를, provider 선언 줄에서는 `stadiumVisitCheckerProvider`
/// 를 잡는다. 마지막이 아니라 첫째인 것에 까닭이 있다: 표현식 본문 함수는
/// 머리 줄에 **부르는 이름까지** 함께 있어서, 마지막을 잡으면 공개 래퍼
/// 한 줄이 자기가 부르는 private 함수의 이름을 뒤집어쓰고 아래 단언을
/// 통과한다(실측 — 그 래퍼를 더한 변이가 마지막을 잡을 때 초록불이었다).
/// 열 0 의 `///`·`}`·닫는 괄호는 머리가 아니므로 앞 선언의 이름이 이어진다.
/// 주석 줄은 아예 빼고 돌려준다 — 이 파일의 주석은 규칙 자체를 서술하는
/// 자리라 그 이름들을 그대로 적는다.
List<({String owner, String line})> _byTopLevelOwner(String source) {
  final head = RegExp(r'^[A-Za-z_$]');
  final name = RegExp(r'([A-Za-z_$][A-Za-z0-9_$]*) *[(=]');
  final out = <({String owner, String line})>[];
  var owner = '(파일 최상위)';
  for (final line in source.split('\n')) {
    if (head.hasMatch(line)) {
      final matches = name.allMatches(line).toList();
      owner = matches.isEmpty ? line.trim() : matches.first.group(1)!;
    }
    if (line.trimLeft().startsWith('//')) continue;
    out.add((owner: owner, line: line));
  }
  return out;
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
    test('반경 경계는 포함이다 — 거리가 반경과 **같으면** 방문이다', () {
      // 왜 반경을 주입해서 재는가: 하버사인 거리는 부동소수라 "정확히 300m"인
      // 좌표를 만들 수 없다(거리 값들의 간격이 위도 한 ulp 가 만드는 변화보다
      // 훨씬 촘촘해서 어떤 좌표도 300.0 에 정확히 앉지 않는다). 그래서 좌표로
      // 경계를 맞추는 대신 반경을 거리와 같은 값으로 준다 — 구장 한복판은
      // 거리가 정확히 0.0 이므로 반경 0 이 곧 "경계 위"다. ±1m 로 재던 옛
      // 시험은 `<=` 를 `<` 로 바꾸는 변이를 그대로 통과시켰다.
      expect(
        judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: [_jamsilTonight()],
          now: duringPregame,
          fix: _northOf(0),
          radiusMeters: 0,
        ).reason,
        StadiumVisitReason.visited,
        reason: '거리 == 반경은 안이다 (<= 를 < 로 바꾸면 여기가 빨간불)',
      );
      expect(
        judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: [_jamsilTonight()],
          now: duringPregame,
          fix: _northOf(1),
          radiusMeters: 0,
        ).reason,
        StadiumVisitReason.outsideRadius,
        reason: '경계 밖으로 한 발짝만 나가도 밖이다',
      );
    });

    test('판정은 실 반경 상수를 쓴다 — 안은 방문, 밖은 방문 아님', () {
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

    test('시간 창은 KST 자정에서 잘리지 않는다', () {
      // 20:00 시작 경기의 창은 다음 날 01:00 까지다. 달력 날짜로 후보를
      // 거르면 자정을 넘긴 순간 창이 통째로 사라져, 창 안에 서 있는 사람이
      // `noGameToday` 를 받는다(늦은 시작·연장·더블헤더 2차전의 자리).
      final lateGame = StadiumVisitCandidate(
        gameId: 'g-late',
        stadiumId: 'jamsil',
        startsAt: DateTime.parse('2026-08-25T20:00:00+09:00'),
        lat: _jamsilLat,
        lng: _jamsilLng,
      );

      expect(
        judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: [lateGame],
          now: DateTime.parse('2026-08-26T00:30:00+09:00'),
          fix: _northOf(0),
        ).reason,
        StadiumVisitReason.visited,
        reason: '자정을 넘겼어도 경기 시각 기준 창 안이다',
      );

      // 창이 닫힌 뒤에는 판정할 경기가 없다 — 창을 넓힌 것이 아니라 날짜가
      // 자르지 않게 한 것이라는 짝 단언이다.
      expect(
        judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: [lateGame],
          now: DateTime.parse('2026-08-26T02:00:00+09:00'),
          fix: _northOf(0),
        ).reason,
        StadiumVisitReason.noGameToday,
      );
    });

    test('창이 자정을 넘어도 그날 낮은 여전히 창 밖이다', () {
      // 게이트가 창으로만 좁혀지면 `outsideTimeWindow` 가 영영 설 수 없다 —
      // 그 갈래가 살아 있다는 것을 다섯 갈래와 별개로 못 박는다.
      final lateGame = StadiumVisitCandidate(
        gameId: 'g-late',
        stadiumId: 'jamsil',
        startsAt: DateTime.parse('2026-08-25T20:00:00+09:00'),
        lat: _jamsilLat,
        lng: _jamsilLng,
      );

      expect(
        judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: [lateGame],
          now: DateTime.parse('2026-08-25T10:00:00+09:00'),
          fix: _northOf(0),
        ).reason,
        StadiumVisitReason.outsideTimeWindow,
      );
    });

    test('후보 게이트는 오늘 경기와 창이 지금을 덮는 경기를 함께 남긴다', () {
      final lateYesterday = StadiumVisitCandidate(
        gameId: 'g-late',
        stadiumId: 'jamsil',
        startsAt: DateTime.parse('2026-08-25T20:00:00+09:00'),
        lat: _jamsilLat,
        lng: _jamsilLng,
      );
      final todayNoon = StadiumVisitCandidate(
        gameId: 'g-noon',
        stadiumId: 'gocheok',
        startsAt: DateTime.parse('2026-08-26T14:00:00+09:00'),
        lat: _jamsilLat,
        lng: _jamsilLng,
      );
      final farAway = StadiumVisitCandidate(
        gameId: 'g-next-week',
        stadiumId: 'sajik',
        startsAt: DateTime.parse('2026-09-01T18:30:00+09:00'),
        lat: _jamsilLat,
        lng: _jamsilLng,
      );

      final kept = candidatesToJudge(
        [lateYesterday, todayNoon, farAway],
        DateTime.parse('2026-08-26T00:30:00+09:00'),
      ).map((candidate) => candidate.gameId).toList();

      expect(kept, ['g-late', 'g-noon']);
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

    // 위 시험은 `toString()` 만 본다. 그것 하나로는 결과 타입에 좌표 필드를
    // 더하고 판정에서 실어 보내는 변이가 그대로 통과한다(실측: 시험 22개와
    // 훅 2종 전부 초록불). 그래서 경계를 넘는 타입의 **필드 집합 자체**를
    // 소스에서 읽어 표와 대조한다 — `test/cross_layer_seams_test.dart` 가
    // `firestore.rules` 를 읽어 Dart 상수와 대조하는 것과 같은 방식이다.
    test('경계를 넘는 타입이 값을 두는 자리는 이 넷뿐이다 (소스 대조)', () {
      final body = _classBody(
        File('lib/location/visit_check.dart').readAsStringSync(),
        'StadiumVisitResult',
      );

      // 표에 `static` 필드와 게터까지 들어오는 것이 요점이다 — 인스턴스 필드만
      // 보던 옛 표는 `static DeviceFix? lastSpot;` 을 놓쳤고, 그 한 줄이 곧
      // 라이브러리 밖에서 읽히는 좌표 자리였다(`_declaredStorage` 문서 참조).
      expect(_declaredStorage(body), {
        'reason': 'final StadiumVisitReason',
        'stadiumId': 'final String?',
        'gameId': 'final String?',
        'isVisit': 'bool get',
      }, reason: '이 타입에 값 자리를 더하면 좌표가 계층 경계를 넘을 수 있다');
    });

    test('경계를 넘는 타입에는 좌표 어휘가 없다 (소스 대조)', () {
      final body = _classBody(
        File('lib/location/visit_check.dart').readAsStringSync(),
        'StadiumVisitResult',
      );

      // `check-no-location-upload.sh` 가 `lib/backend/` 에서 막는 것과 같은
      // 다섯 단어를, 이 폴더에서는 **경계를 넘는 타입 안에서만** 막는다
      // (폴더 전체에서는 좌표가 정당하다).
      expect(
        RegExp(r'\b(lat|lng|latitude|longitude|coord)\b').hasMatch(body),
        isFalse,
        reason: '결과 타입이 좌표를 이름으로도 들고 나가지 않는다',
      );
    });
  });

  // 겹 1("좌표를 얻는 통로가 이 라이브러리 안에서만 보인다")을 지키는 자리다.
  // 4.1 round 3 이전에는 이 겹을 재는 검사도 시험도 하나도 없어서,
  // `_readDeviceFix` 를 공개 함수로 개명하거나 `StadiumVisitChecker._readFix`
  // 를 public 으로 되돌려도 analyze·시험 657개·훅 4종이 전부 초록불이었다
  // (지휘자 재현 — 뒤엣것은 2026-09-04 `[M]` 이 결함으로 적어 고친 바로 그
  // 상태이고, 앞엣것은 2026-09-04 `[S]` 가 rejected 로 적어 둔 갈래다).
  //
  // **이 파수꾼이 재지 않는 것:** 새 private 통로를 더한 뒤 그 값을 다른
  // 공개 표면으로 실어 내보내는 조합. 그쪽은 결과 타입 파수꾼(위 group)과
  // `check-no-location-upload.sh` 의 검사 4)(값을 담아 둘 자리 금지)가 각각
  // 다른 각도에서 받는다.
  group('좌표를 얻는 통로는 이 라이브러리 안에서만 보인다 (겹 1, 소스 대조)', () {
    final source = File('lib/location/visit_check.dart').readAsStringSync();

    test('플러그인을 만지는 줄은 전부 private 선언 안에 있다', () {
      // 이 시험은 `geo.` 를 플러그인 호출의 표지로 쓴다 — 표지 자체가 살아
      // 있는지 먼저 못 박아 둔다(접두어가 바뀌면 아래 단언이 조용히 빈
      // 목록을 보게 된다).
      expect(
        source,
        contains("import 'package:geolocator/geolocator.dart' as geo;"),
        reason: 'geolocator 를 `geo` 로 들이는 줄이 이 파수꾼의 표지다',
      );

      final offenders = [
        for (final entry in _byTopLevelOwner(source))
          if (entry.line.contains('geo.') && !entry.owner.startsWith('_'))
            '${entry.owner}: ${entry.line.trim()}',
      ];

      expect(offenders, isEmpty, reason: '기기 좌표를 읽는 자리가 라이브러리 밖에서 불릴 수 있다');
    });

    test('그 통로를 이름으로 부르는 최상위 선언은 둘뿐이다', () {
      final owners = {
        for (final entry in _byTopLevelOwner(source))
          if (entry.line.contains('_readDeviceFix')) entry.owner,
      };

      // 선언 자신과, 그것을 판정기의 private 필드에 넣어 주는 provider.
      // 여기에 셋째가 생기면 그 자리가 곧 좌표를 얻는 새 통로다.
      expect(owners, {
        '_readDeviceFix',
        'stadiumVisitCheckerProvider',
      }, reason: '측위 함수를 들고 도는 자리가 늘면 통로가 늘어난다');
    });

    test('판정기가 그 통로를 쥐는 자리는 private 필드다 (소스 대조)', () {
      // `_readFix` 가 public 이면 `stadiumVisitCheckerProvider` 를 읽은 어느
      // feature 든 `ref.read(...).readFix()` 로 실 좌표를 얻는다.
      expect(
        _declaredStorage(_classBody(source, 'StadiumVisitChecker')),
        {
          'readPermission': 'final Future<LocationPermissionStatus> Function()',
          '_readFix': 'final DeviceFixReader',
        },
        reason: '판정기가 밖으로 내주는 것은 "판정을 한 번 돌린다"는 능력뿐이다',
      );
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

    /// 콘텐츠 4종·시계·판정기를 갈아 끼운 컨테이너.
    ProviderContainer buildContainer(
      _RecordingChecker recorder, {
      bool scheduleUnavailable = false,
    }) {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => duringPregame),
          stadiumsProvider.overrideWith((ref) async => ContentFresh(stadiums)),
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
      return container;
    }

    /// 그 컨테이너 위에 트리거만 띄운다.
    Future<ProviderContainer> pumpTrigger(
      WidgetTester tester, {
      required _RecordingChecker recorder,
      bool scheduleUnavailable = false,
    }) async {
      final container = buildContainer(
        recorder,
        scheduleUnavailable: scheduleUnavailable,
      );

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

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
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

    test('이미 도는 판정이 있으면 측위를 두 번 요청하지 않는다', () async {
      // 트리거가 둘(첫 프레임·포그라운드 복귀)이라 짧은 간격으로 두 번 불릴
      // 수 있다. 그때 OS 에 측위를 두 번 묻지 않는 것이 `_running` 의 존재
      // 이유인데, 그 줄을 지워도 저장소 전체가 초록불이었다(실측).
      final gate = Completer<void>();
      final recorder = _RecordingChecker(fix: _northOf(0), fixGate: gate);
      final notifier = buildContainer(
        recorder,
      ).read(stadiumVisitProvider.notifier);

      final first = notifier.run();
      // 첫 판정이 측위를 기다리는 자리에 실제로 설 때까지 이벤트 루프를 돌린다.
      for (var turn = 0; turn < 100 && recorder.fixReads == 0; turn++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(recorder.fixReads, 1, reason: '첫 판정이 측위 중이어야 겹침을 잰다');

      final second = notifier.run();
      gate.complete();
      await Future.wait([first, second]);

      expect(recorder.fixReads, 1, reason: '겹쳐 도는 판정은 측위를 다시 묻지 않는다');

      // 끝난 판정은 다음 트리거를 막지 않는다 — 겹침 방지가 영구 잠금이 아니다.
      await notifier.run();
      expect(recorder.fixReads, 2);
    });

    testWidgets('앱 골격(MainTabsRoot)이 그 트리거를 실제로 달고 있다', (tester) async {
      // 계약 Goal 의 "앱이 열려 있을 때 위치를 한 번 받는다"는 트리거 위젯이
      // 있는 것만으로는 참이 되지 않는다 — 그 위젯이 사람이 닿는 골격에
      // 매달려 있어야 참이다. 이 시험이 서기 전에는 `MainTabsRoot` 의
      // `StadiumVisitTrigger(child: _tabs())` 를 `_tabs()` 로 되돌려도
      // 저장소 전체 644개가 초록불이었다(실측).
      SharedPreferences.setMockInitialValues({});
      final auth = FakeAuthService(
        signedIn: const AuthUser(uid: _uid, email: 'a@b.c'),
      );
      final store = FakeUserDataStore();
      addTearDown(auth.dispose);
      addTearDown(store.dispose);
      await store.createProfile(
        _uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'lg',
          profileThemeKey: 'lg',
        ),
      );

      final recorder = _RecordingChecker(fix: _northOf(0));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            userDataStoreProvider.overrideWithValue(store),
            weatherEffectProvider.overrideWith(
              (ref, point) async => WeatherEffect.none,
            ),
            clockProvider.overrideWithValue(() => duringPregame),
            stadiumsProvider.overrideWith((ref) async => ContentFresh(stadiums)),
            scheduleProvider.overrideWith((ref) async => ContentFresh(schedule)),
            placesProvider.overrideWith(
              (ref) async => const ContentUnavailable<PlacesDocument>(_fixture),
            ),
            teamsProvider.overrideWith(
              (ref) async => const ContentUnavailable<TeamsDocument>(_fixture),
            ),
            stadiumVisitCheckerProvider.overrideWithValue(recorder.build()),
          ],
          child: const MaterialApp(home: MainTabsRoot()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(StadiumVisitTrigger),
        findsOneWidget,
        reason: '판정은 배지 탭이 아니라 앱을 여는 것 자체에 걸린다',
      );
      expect(recorder.fixReads, 1, reason: '골격이 뜨는 것만으로 판정이 한 번 돈다');
    });
  });
}
