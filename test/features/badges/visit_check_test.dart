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
///   - "홈·원정을 구분하지 않는다" — 두 자리에서 잰다. 후보를 짓는 자리가
///     팀으로 거르지 않는다는 것을 **응원 팀이 어느 쪽도 아닌 경기**와
///     **응원 팀의 원정 경기**로 재고, 짝으로 후보 타입의 **필드 집합
///     자체**를 소스로 못 박는다(팀 id 가 아예 없다는 것이 그 계약이다).
///
/// **이 파일의 소스 대조 파수꾼들이 무엇을 약속하는가.** 이것들은 소스
/// 텍스트를 본다. 그래서 막는 것은 **실수와 무심코**이고, 작정하고 패턴을
/// 비켜 가는 표기는 막지 못한다 — 그 성질과 실측 예, 그리고 새 표기 우회를
/// 찾았을 때 무엇이 고칠 값어치가 있고 무엇이 이미 인정된 범위인지는
/// `lib/location/visit_check.dart` 첫 문단에 적혀 있다. 파수꾼을 고치기
/// 전에 그 문단을 먼저 읽을 것.
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

/// 사직야구장 좌표(같은 근사) — "내 팀이 뛰지 않는 경기"·"원정 경기"를 잠실과
/// **다른 구장**에서 재는 자리다. 잠실 하나로는 그 둘을 지을 수 없다:
/// `homeTeams` 가 `['lg','doosan']` 이라 잠실 경기는 언제나 두 홈 팀의 것이다.
const double _sajikLat = 35.1940;
const double _sajikLng = 129.0615;

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

/// 클래스 몸통을 **문장 단위**로 끊어 돌려준다 — 들여쓰기를 보지 않는다.
///
/// 주석과 문자열을 걷어 내고, 괄호·대괄호 밖의 중괄호로 깊이를 세고, 깊이 0
/// 에서 괄호 밖의 `;` 를 만날 때 문장 하나를 끊는다. 메서드 몸통을 여는 `{`
/// 는 깊이를 올리고 모아 둔 것을 버리므로, 그 안의 지역 변수는 여기 오지
/// 않는다. `({required this.x})` 처럼 **괄호 안의** 중괄호는 깊이를 바꾸지
/// 않아서 생성자 하나가 문장 하나로 남는다.
///
/// `check-no-location-upload.sh` 의 검사 4) 가 쓰는 것과 같은 방식이고, 까닭도
/// 같다: 표기가 아니라 구조로 자리를 정해야 들여쓰기를 바꾸는 것만으로 파수꾼
/// 을 지나가지 못한다.
List<String> _classLevelStatements(String body) {
  final out = <String>[];
  final buf = StringBuffer();
  var depth = 0; // 클래스 몸통 안이 0, 메서드 몸통 안이 1 이상
  var paren = 0;
  String? quote;

  void keep(String c) {
    if (depth == 0) buf.write(c);
  }

  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && i + 1 < body.length && body[i + 1] == '/') {
      while (i < body.length && body[i] != '\n') {
        i++;
      }
      keep(' ');
      continue;
    }
    if (c == '/' && i + 1 < body.length && body[i + 1] == '*') {
      i += 2;
      while (i + 1 < body.length && !(body[i] == '*' && body[i + 1] == '/')) {
        i++;
      }
      i++;
      keep(' ');
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      keep(c);
      continue;
    }
    if (c == '(' || c == '[') {
      paren++;
      keep(c);
      continue;
    }
    if (c == ')' || c == ']') {
      paren--;
      keep(c);
      continue;
    }
    if (c == '{') {
      if (paren == 0) {
        depth++;
        buf.clear();
      } else {
        keep(c);
      }
      continue;
    }
    if (c == '}') {
      if (paren == 0) {
        if (depth > 0) depth--;
        buf.clear();
      } else {
        keep(c);
      }
      continue;
    }
    if (c == ';' && paren == 0) {
      if (depth == 0) {
        final stmt = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
        if (stmt.isNotEmpty) out.add('$stmt;');
      }
      buf.clear();
      continue;
    }
    keep(c);
  }
  return out;
}

/// 클래스 몸통이 **선언한 값 자리**를 이름→선언 앞부분 표로 편다.
///
/// 이름 뒤에 `;` 나 `=` 가 오는 문장만 보므로, 메서드·생성자(이름 뒤에 `(` 가
/// 온다)와 메서드 안의 지역 변수는 섞이지 않는다. 표에 담는 값이 타입만이
/// 아니라 **수식어까지**(`static`·`final`·`var`·`get`) 인 것이 옛
/// `^  final (.+) (\w+);$` 정규식과 다른 점이다: 그 정규식은 `final` 로
/// 시작하지 않는 선언을 아예 보지 못해서 `static DeviceFix? lastSpot;` 한 줄이
/// 파수꾼과 훅을 함께 통과했고, 그 필드는 `StadiumVisitResult.lastSpot!.lat`
/// 으로 라이브러리 밖에서 읽혔다 (4.1 round 3 지휘자 재현 — 경계 시험 30개·
/// `check-no-location-upload.sh` 전부 초록불이었다).
///
/// **round 6 이 고친 것은 이 표가 `^  `(두 칸 들여쓰기)에 못 박혀 있었다는
/// 것이다.** `StadiumVisitResult` 에 `final DeviceFix? at;` 를 **네 칸**
/// 들여쓰고 생성자에 `this.at` 을 더하면 그 필드가 이 표에 아예 들어오지
/// 않아서, 훅 4종·`flutter analyze`·시험 665개가 전부 초록불인 채로 실 좌표가
/// 라이브러리 밖에서 읽혔다(round 6 의 검증자 재현). 겹 4 의 훅은 같은
/// 라운드에 이미 줄에서 문장으로 옮겼는데 이 파수꾼만 줄에 남아 있어서, 겹 4
/// 와 겹 5 의 세기가 어긋나 있었다. 이제 [_classLevelStatements] 가 구조로
/// 자리를 정하므로 네 칸이든 여덟 칸이든 탭이든 한 줄이든 같은 자리로 온다.
///
/// **이것이 표기 우회를 없애 주지는 않는다.** 이 함수는 여전히 소스 텍스트를
/// 보고, 문자열·주석을 걷어 내는 방식도 거친 파서다 — `visit_check.dart` 첫
/// 문단의 "이 파수꾼들이 막는 것" 문단이 그 세기를 적어 둔다. 다만 파서가
/// 어긋나면 표가 기대와 달라져 **빨간불**이 된다(조용히 통과하지 않는다).
Map<String, String> _declaredStorage(String body) {
  final decl = RegExp(
    r'^((?:@[A-Za-z_$][A-Za-z0-9_$]*(?:\([^)]*\))? )*'
    r'(?:static |late |final |const |var |covariant )*'
    r'[A-Za-z_][A-Za-z0-9_<>?,.() ]*?) (\w+) *(?:;|=)',
  );
  return {
    for (final stmt in _classLevelStatements(body))
      if (decl.firstMatch(stmt) case final match?)
        match.group(2)!: match.group(1)!,
  };
}

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

/// 최상위 선언 하나가 차지하는 줄들을 **하나로 이어 붙여 공백을 전부 지운**
/// 표로 편다 — 겹 1 파수꾼이 줄과 공백에 덜 민감해지는 자리다.
///
/// round 5 의 검증자가 뚫은 것이 정확히 그 민감함이었다. 옛 파수꾼은
/// `owned.line.contains('$prefix.')` 라서 별칭과 점이 **한 줄 안에 붙어**
/// 있을 때만 표지가 섰고, 아래가 훅 4종·시험 663개를 전부 통과했다(지휘자
/// 재현). 별칭과 점 사이에 공백 하나를 넣는 변종도 같았다.
///
/// ```dart
/// Future<DeviceFix?> readFixSplit() async {
///   final p = await geo
///       .Geolocator
///       .getCurrentPosition();
///   return DeviceFix(lat: p.latitude, lng: p.longitude);
/// }
/// ```
///
/// 그래서 표지를 줄이 아니라 **선언 단위**로 본다: 한 선언이 차지하는 줄을
/// 전부 이어 붙인 뒤, **점 둘레의 공백과 줄바꿈만 지우고** 나머지 공백은
/// 하나로 접는다. 그러면 위 표기도, 공백을 끼우는 표기도 같은 자리로 온다.
/// 점 둘레만 지우고 전부 지우지 않는 데는 까닭이 있다 — 전부 지우면
/// `await geo.` 가 `awaitgeo.` 가 되어 "별칭 앞에 식별자 문자가 오면 다른
/// 이름의 꼬리다"라는 표지 조건이 헛돌고, 그때 이 파수꾼은 조용히 아무것도
/// 잡지 못한다(실측으로 그 상태를 한 번 만들어 보고 고쳤다).
/// `import`·`export`·`part` 줄은 표에서 빼는데, 그 줄의 URI 안에 별칭과 같은
/// 글자가 들어 있으면 표지가 헛돌기 때문이다.
///
/// **이것이 표기 우회를 없애 주지는 않는다.** 텍스트를 보는 파수꾼에는
/// 언제나 다음 표기가 남는다 — `visit_check.dart` 첫 문단의 "이 파수꾼들이
/// 막는 것" 문단을 읽으십시오. 여기서 늘어난 것은 **실수로 지나갈 수 있는
/// 갈래**가 줄었다는 것뿐이다.
List<({String owner, String compact, String snippet})> _compactedDeclarations(
  String source,
) {
  final directive = RegExp(r'^\s*(import|export|part)\s');
  final out = <({String owner, String compact, String snippet})>[];
  var owner = '';
  var lines = <String>[];
  void flush() {
    if (lines.isEmpty) return;
    final snippet = lines.map((line) => line.trim()).where((l) => l.isNotEmpty).join(' ');
    out.add((
      owner: owner,
      compact: lines
          .join('\n')
          .replaceAll(RegExp(r'\s*\.\s*'), '.')
          .replaceAll(RegExp(r'\s+'), ' '),
      snippet: snippet.length <= 160 ? snippet : '${snippet.substring(0, 160)}…',
    ));
  }

  for (final entry in _byTopLevelOwner(source)) {
    if (entry.owner != owner) {
      flush();
      owner = entry.owner;
      lines = <String>[];
    }
    if (directive.hasMatch(entry.line)) continue;
    lines.add(entry.line);
  }
  flush();
  return out;
}

/// `lib/location/` 의 Dart 소스 전부를 경로→내용 표로 읽어 온다.
///
/// 겹 1 파수꾼이 **파일 하나가 아니라 폴더 전체**를 보게 하는 자리다. 5.2
/// (홈 상단 현재 위치)가 이 폴더에 파일을 하나 더 두면 그 파일도 같은 단언을
/// 지나야 한다 — round 4 이전에는 `visit_check.dart` 만 읽어서, 그 옆에 파일을
/// 하나 두는 것만으로 아래 단언 전부가 시야 밖이 되었다.
///
/// **하위 폴더까지 훑는다** (`recursive: true`). round 6 이전에는 한 겹만
/// 훑어서, 이 폴더에 하위 폴더가 생기는 순간 그 안의 파일이 이 파수꾼의 시야
/// 밖이었다 — 짝인 `check-no-location-upload.sh` 는 `find` 로 처음부터
/// 재귀적으로 보고 있었으므로(하위 폴더의 금지 import·`part`·저장소 필드가
/// 전부 exit 2 인 것을 실측했다) 그동안 훅과 이 파수꾼의 시야가 갈려 있었다.
/// 5.2 가 하위 폴더를 만들면 그 어긋남이 곧 구멍이 된다.
Map<String, String> _locationSources() {
  final files =
      Directory('lib/location')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  // `expect` 를 쓰지 않는 것은 이 함수가 group 몸통(테스트 밖)에서 불리기
  // 때문이다 — 거기서 부르면 OutsideTestException 으로 파일 로딩이 죽는다.
  if (files.isEmpty) {
    throw StateError('lib/location/ 에서 Dart 파일을 하나도 찾지 못했다');
  }
  return {for (final file in files) file.path: file.readAsStringSync()};
}

/// 이 폴더가 `geolocator` 를 들이는 **모든 별칭**.
///
/// 별칭이 없는 import(`import 'package:geolocator/geolocator.dart';`)는
/// `Geolocator` 를 접두어 없이 세워 이 파수꾼의 표지 자체를 지우므로, 그런
/// import 가 하나라도 있으면 여기서 바로 빨간불이 된다. `deferred as` 도 같은
/// 모양으로 받는다.
Set<String> _geolocatorPrefixes(Map<String, String> sources) {
  final directive = RegExp(
    '''^import\\s+['"]package:geolocator/[^'"]*['"]([^;]*);''',
    multiLine: true,
  );
  final alias = RegExp(r'(?:\bdeferred\b\s+)?\bas\s+([A-Za-z_$][A-Za-z0-9_$]*)');
  final prefixes = <String>{};
  for (final entry in sources.entries) {
    for (final match in directive.allMatches(entry.value)) {
      final tail = alias.firstMatch(match.group(1)!);
      expect(
        tail,
        isNotNull,
        reason:
            '${entry.key} 이 geolocator 를 별칭 없이 들인다 — `Geolocator` 가 접두어 없이 서면 이 파수꾼의 표지가 지워진다',
      );
      prefixes.add(tail!.group(1)!);
    }
  }
  return prefixes;
}

/// 밖에서 값을 건네받는 두 서명 — 이 둘을 지나서만 좌표가 이 계층에 들어온다.
///
/// 문자열로 두는 것은 파수꾼이 재는 것이 **서명의 모양 그대로**이기 때문이다:
/// 인자가 하나 더 생기면 그 인자가 곧 좌표의 출구다.
const String _checkSignature =
    '  Future<StadiumVisitResult> check({\n'
    '    required List<StadiumVisitCandidate> candidates,\n'
    '    required DateTime now,\n'
    '  }) async {\n';

const String _judgeSignature =
    'StadiumVisitResult judgeStadiumVisit({\n'
    '  required LocationPermissionStatus permission,\n'
    '  required List<StadiumVisitCandidate> candidates,\n'
    '  required DateTime now,\n'
    '  required DeviceFix? fix,\n'
    '  double radiusMeters = kStadiumVisitRadiusMeters,\n'
    '}) {\n';

/// [needle] 이 나타나는 파일과 **횟수**를 표로 돌려준다 (0 인 파일은 빼고).
///
/// `contains` 하나로는 "폴더 어딘가에 있다"만 알 수 있어서, 사본이 하나 더
/// 서는 것도 자리가 통째로 옮겨지는 것도 보이지 않는다.
Map<String, int> _occurrences(Map<String, String> sources, String needle) {
  final out = <String, int>{};
  for (final entry in sources.entries) {
    var count = 0;
    var at = entry.value.indexOf(needle);
    while (at >= 0) {
      count++;
      at = entry.value.indexOf(needle, at + needle.length);
    }
    if (count > 0) out[entry.key] = count;
  }
  return out;
}

/// [head] 로 시작하는 선언을 가진 **유일한** 파일의 내용을 돌려준다.
///
/// 겹 1 파수꾼이 파일 이름에 못 박히지 않게 하는 자리다. 5.2 가 이 폴더에
/// 파일을 하나 더 두고 판정기를 그쪽으로 옮기면, 이름을 적어 둔 파수꾼은
/// 조용히 옛 자리를 보거나 죽는다. 둘이 되면(사본이 하나 더 서면) 여기서
/// 빨간불이다.
String _sourceDeclaring(Map<String, String> sources, String head) {
  final owners = [
    for (final entry in sources.entries)
      if (entry.value.contains(head)) entry.key,
  ];
  expect(
    owners,
    hasLength(1),
    reason: '`$head` 을 선언하는 파일은 이 폴더에 하나여야 한다',
  );
  return sources[owners.single]!;
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
  //
  // round 4 가 이 파수꾼의 시야를 두 번 넓혔다. (a) 보는 자리가
  // `visit_check.dart` **파일 하나**여서, `lib/location/` 에 파일이 하나 더
  // 생기는 순간(5.2 가 그 자리다) 시야 밖이었다 — 이제 폴더 전체를 본다.
  // (b) 재는 것이 `geo.` 라는 **별칭 하나**여서, 기존 import 를 그대로 두고
  // `import 'package:geolocator/geolocator.dart' as gps;` 를 하나 더 들인 뒤
  // 공개 함수에서 `gps.Geolocator.getCurrentPosition()` 을 부르면 아무것도
  // 보지 못했다(round 4 지휘자 재현 — 훅 4종·시험 전부 초록불) — 이제
  // 이 폴더가 geolocator 를 들이는 **모든** 별칭을 소스에서 읽어 쓴다.
  //
  // round 5 가 두 곳을 더 고쳤고, 그 둘의 실측과 한계는 `_compactedDeclarations`
  // 문서와 `visit_check.dart` 첫 문단의 겹 1 에 적혀 있다: 표지를 줄이 아니라
  // **선언 단위**로 보게 한 것(별칭과 점 사이의 줄바꿈·공백을 지운 뒤 찾는다)
  // 과, 조건을 "private 선언이면 된다"에서 "`_readDeviceFix` 하나여야 한다"로
  // 좁힌 것이다(앞엣것이 검증자가 뚫은 자리, 뒤엣것은 private 헬퍼 하나를 더
  // 두고 공개 함수가 그것을 부르는 두 걸음짜리 갈래를 닫는다).
  // 짝으로 `part` 지시자도 여기서 잰다: Dart 의 `_` 는 파일이 아니라
  // 라이브러리 가시성이라, part 파일 하나면 `_readDeviceFix` 가 공개 이름으로
  // 다시 나갈 수 있는데 그 파일은 geolocator 를 import 하지 않아 겹 2 의
  // 훅에도 걸리지 않는다.
  group('좌표를 얻는 통로는 이 라이브러리 안에서만 보인다 (겹 1, 소스 대조)', () {
    final locationSources = _locationSources();

    test('이 폴더는 part 파일을 쓰지 않는다 (파일 하나가 라이브러리 하나다)', () {
      expect(
        locationSources.keys,
        contains('lib/location/visit_check.dart'),
        reason: '폴더 훑기가 판정 파일 자체를 놓치면 아래 단언들이 조용히 빈 목록을 본다',
      );

      final offenders = [
        for (final entry in locationSources.entries)
          for (final line in entry.value.split('\n'))
            if (RegExp(r'''^\s*part\s+('|"|of\s)''').hasMatch(line))
              '${entry.key}: ${line.trim()}',
      ];

      expect(
        offenders,
        isEmpty,
        reason: 'part 파일은 같은 라이브러리 안에 들어와 `_` 통로를 공개 이름으로 다시 내보낼 수 있다',
      );
    });

    test('플러그인을 만지는 최상위 선언은 _readDeviceFix 하나뿐이다 (폴더 전체)', () {
      // 이 파수꾼의 표지는 별칭 **하나**가 아니라 이 폴더가 geolocator 를
      // 들이는 별칭 **전부**다. 표지가 살아 있는지 먼저 못 박아 둔다(하나도
      // 못 찾으면 아래 단언이 조용히 빈 목록을 보게 된다).
      final prefixes = _geolocatorPrefixes(locationSources);
      expect(
        prefixes,
        isNotEmpty,
        reason: 'geolocator 를 별칭으로 들이는 줄이 이 파수꾼의 표지다',
      );

      // 별칭 앞에 식별자 문자가 오면 다른 이름의 꼬리다 — 별칭 자체일 때만
      // 표지로 센다.
      final markers = {
        for (final prefix in prefixes)
          prefix: RegExp('(?<![A-Za-z0-9_\\\$])${RegExp.escape(prefix)}\\.'),
      };

      // **"private 안에 있으면 된다"가 아니라 "이 이름 하나여야 한다"로
      // 좁힌 것이 round 5 의 변화다.** 앞엣것으로는 private 헬퍼를 하나 더
      // 두고(`_wrap`) 그것을 공개 함수가 부르는 두 걸음짜리 갈래가 통째로
      // 열려 있었다. 이제 그 첫 걸음에서 걸리고, 둘째 걸음은 아래
      // "_readDeviceFix 를 부르는 최상위 선언은 둘뿐" 파수꾼이 받는다.
      final offenders = [
        for (final entry in locationSources.entries)
          for (final decl in _compactedDeclarations(entry.value))
            for (final prefix in prefixes)
              if (markers[prefix]!.hasMatch(decl.compact) &&
                  decl.owner != '_readDeviceFix')
                '${entry.key} — ${decl.owner}: ${decl.snippet}',
      ];

      expect(
        offenders,
        isEmpty,
        reason: '기기 좌표를 읽는 자리는 _readDeviceFix 하나여야 한다',
      );
    });

    test('그 통로를 이름으로 부르는 최상위 선언은 둘뿐이다 (폴더 전체)', () {
      final owners = {
        for (final entry in locationSources.entries)
          for (final owned in _byTopLevelOwner(entry.value))
            if (owned.line.contains('_readDeviceFix'))
              '${entry.key} — ${owned.owner}',
      };

      // 선언 자신과, 그것을 판정기의 private 필드에 넣어 주는 provider.
      // 여기에 셋째가 생기면 그 자리가 곧 좌표를 얻는 새 통로다.
      expect(owners, {
        'lib/location/visit_check.dart — _readDeviceFix',
        'lib/location/visit_check.dart — stadiumVisitCheckerProvider',
      }, reason: '측위 함수를 들고 도는 자리가 늘면 통로가 늘어난다');
    });

    // round 4 가 세운 파수꾼이다. 위 셋은 좌표를 **얻는** 자리만 보고 있어서,
    // 좌표를 **건네받는 자리를 부르는 쪽이 끼워 넣는** 갈래가 통째로 열려
    // 있었다: `check` 에 `void Function(String)? spy` 인자를 하나 더하고
    // `spy?.call('${fix.lat},${fix.lng}')` 한 줄을 넣으면, 그 판정기를 읽는
    // 어느 feature 든(그쪽은 backend·analytics·http 를 전부 쓸 수 있다) 실
    // 좌표를 그대로 받아 간다 — 훅 4종·시험 34개가 전부 초록불이었다
    // (round 4 구현자 재현). 같은 모양의 사촌이 둘 더 있다:
    // 공개 메서드를 하나 더해 `_readFix()` 를 그대로 부르기, 그리고 순수 판정
    // 함수에 같은 인자를 더해 `check` 에서 넘겨주기.
    //
    // 그래서 **밖에서 값을 건네받거나 밖으로 내주는 서명 자체**를 소스로 못
    // 박는다. 좌표는 이 두 서명을 지나서만 이 라이브러리에 들어오고, 통로를
    // 쥔 `_readFix` 는 아래 세 줄에서만 이름으로 불린다.
    test('좌표 통로를 이름으로 쓰는 줄은 이 셋뿐이다 (폴더 전체, 소스 대조)', () {
      final lines = [
        for (final entry in locationSources.entries)
          for (final owned in _byTopLevelOwner(entry.value))
            if (owned.line.contains('_readFix'))
              '${entry.key}: ${owned.line.trim()}',
      ];

      expect(lines, [
        'lib/location/visit_check.dart: }) : _readFix = readFix;',
        'lib/location/visit_check.dart: final DeviceFixReader _readFix;',
        'lib/location/visit_check.dart: fix: await _readFix(),',
      ], reason: '통로를 부르는 줄이 늘거나 모양이 바뀌면 그 자리가 곧 좌표를 붙잡는 자리다');
    });

    test('실 좌표를 보는 두 서명이 그대로다 (폴더 전체, 소스 대조)', () {
      // 부르는 쪽이 무언가를 **끼워 넣을 수 있는** 자리는 이 둘뿐이다:
      // 판정기의 유일한 공개 메서드와, 그것이 좌표를 넣어 부르는 순수 판정
      // 함수. 여기에 인자가 하나 더 생기면 그 인자가 곧 좌표의 출구다.
      //
      // 폴더 전체에서 **정확히 한 번씩** 선다는 것까지 잰다. 파일 하나만
      // 보던 옛 판은 그 서명이 다른 파일로 옮겨지면 조용히 아무것도 찾지
      // 못했고(파일 이름이 어긋나면 `!` 에서 죽지만, 5.2 가 판정을 옮기는
      // 갈래는 그 이름을 함께 바꾼다), 같은 서명의 사본이 폴더 어딘가에 하나
      // 더 서는 것도 보지 못했다.
      expect(
        _occurrences(locationSources, _checkSignature),
        {'lib/location/visit_check.dart': 1},
        reason: '판정기가 밖에 내미는 것은 "판정을 한 번 돌린다"는 능력뿐이다',
      );
      expect(
        _occurrences(locationSources, _judgeSignature),
        {'lib/location/visit_check.dart': 1},
        reason: '순수 판정 함수는 좌표를 받아 결과만 돌려준다 — 받아 갈 자리를 더 두지 않는다',
      );
    });

    test('판정기가 그 통로를 쥐는 자리는 private 필드다 (폴더 전체, 소스 대조)', () {
      // `_readFix` 가 public 이면 `stadiumVisitCheckerProvider` 를 읽은 어느
      // feature 든 `ref.read(...).readFix()` 로 실 좌표를 얻는다.
      //
      // 클래스를 **폴더에서** 찾는다(그 클래스를 선언하는 파일이 정확히
      // 하나라는 것까지 [_sourceDeclaring] 이 잰다) — 옛 판은
      // `visit_check.dart` 하나에 못 박혀 있었다.
      expect(
        _declaredStorage(
          _classBody(
            _sourceDeclaring(locationSources, 'class StadiumVisitChecker {'),
            'StadiumVisitChecker',
          ),
        ),
        {
          'readPermission': 'final Future<LocationPermissionStatus> Function()',
          '_readFix': 'final DeviceFixReader',
        },
        reason: '판정기가 밖으로 내주는 것은 "판정을 한 번 돌린다"는 능력뿐이다',
      );
    });

    // round 7 이 세운 파수꾼이다. 위 다섯은 좌표를 **얻는 자리가 어디인지**
    // 만 보고 있어서, **그 자리 안에서 좌표에 무엇을 하는지**는 아무 시험도
    // 보지 않았다. round 7 의 검증자가 정확히 그 틈으로 실 좌표를 내보냈다:
    // 최상위에 `void Function(double, double)? coordSink;` 를 하나 두고
    // 이 함수 몸통에 `coordSink?.call(position.latitude, position.longitude);`
    // 한 줄을 더한 뒤, 폴더 밖의 feature 파일이 그 자리를 `http.post` 로
    // 채웠다. 첫 줄은 이제 훅의 검사 4) 가 이름 목록으로 받지만(그 갈래는
    // 그쪽 실측에 있다), 둘째 줄이 들어간 **몸통 자체**는 여전히 아무도 보고
    // 있지 않았다.
    //
    // **이 파수꾼이 재는 성질:** 기기에서 온 좌표를 만지는 줄이 이 함수의
    // 몸통에 있는 이 목록 그대로다 — 플러그인을 부르고, 그 값으로
    // [DeviceFix] 를 하나 지어 돌려주고, 무엇이 오든 null 로 접는 것.
    // 여기에 줄이 하나 늘거나 모양이 바뀌면 빨간불이다.
    //
    // **재지 않는 것:** 이것은 소스 텍스트 대조라 같은 일을 하는 다른 표기를
    // 막지 못한다(`visit_check.dart` 첫 문단의 "이 파수꾼들이 막는 것"과 같은
    // 세기다). 그리고 주석은 [_byTopLevelOwner] 가 걷어 내므로 이 목록에
    // 오지 않는다 — 주석을 고치는 것은 여기서 빨간불이 되지 않는다.
    test('측위 함수의 몸통이 그대로다 (폴더 전체, 소스 대조)', () {
      final body = [
        for (final entry in locationSources.entries)
          for (final owned in _byTopLevelOwner(entry.value))
            if (owned.owner == '_readDeviceFix' && owned.line.trim().isNotEmpty)
              owned.line,
      ];

      expect(body, [
        'Future<DeviceFix?> _readDeviceFix() async {',
        '  try {',
        '    final position = await geo.Geolocator.getCurrentPosition(',
        '      locationSettings: const geo.LocationSettings(',
        '        accuracy: geo.LocationAccuracy.high,',
        '        timeLimit: kLocationFixTimeout,',
        '      ),',
        '    ).timeout(kLocationFixTimeout);',
        '    return DeviceFix(lat: position.latitude, lng: position.longitude);',
        '  } catch (_) {',
        '    return null;',
        '  }',
        '}',
      ], reason: '좌표가 태어나는 자리에 줄이 하나 늘면 그 줄이 곧 좌표의 출구다');
    });
  });

  group('buildStadiumVisitCandidates — 홈·원정을 구분하지 않는다', () {
    final stadiums = StadiumsDocument(
      stadiums: [
        _stadium('jamsil', _jamsilLat, _jamsilLng, const ['lg', 'doosan']),
        _stadium('sajik', _sajikLat, _sajikLng, const ['lotte']),
      ],
    );

    // round 5 의 검증자가 이 group 의 픽스처를 짚었다: 유일한 경기가 잠실의
    // `lg` 대 `doosan` 이었고 잠실의 `homeTeams` 가 그 둘이라, 시험 이름이
    // 말하는 "내 팀이 뛰지 않는 경기"도 "원정 경기"도 픽스처 안에 없었다.
    // 계약은 타입 구조로 서 있었지만(후보 타입에 팀 id 가 아예 없다) 그
    // 시험이 재는 것은 그 문장이 아니었다. 이제 셋으로 나눠 잰다: 응원 팀이
    // 어느 쪽도 아닌 경기 · 응원 팀의 원정 경기 · 후보 타입의 필드 집합.
    test('내 팀이 뛰지 않는 경기도 후보다 — 그 구장에 있었는지만 본다', () {
      // 응원 팀을 `lg` 로 두면 이 경기(사직의 `lotte` 대 `kt`)에는 그 팀이
      // 어느 쪽으로도 없다.
      final schedule = ScheduleDocument(
        generatedAt: DateTime.utc(2026),
        games: [
          _game(
            id: 'g-sajik',
            date: '2026-08-25',
            home: 'lotte',
            away: 'kt',
            stadium: 'sajik',
          ),
        ],
      );

      final candidates = buildStadiumVisitCandidates(
        schedule: schedule,
        stadiums: stadiums,
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.stadiumId, 'sajik');
      expect(candidates.single.gameId, 'g-sajik');

      final result = judgeStadiumVisit(
        permission: LocationPermissionStatus.granted,
        candidates: candidates,
        now: duringPregame,
        fix: const DeviceFix(lat: _sajikLat, lng: _sajikLng),
      );
      expect(result.reason, StadiumVisitReason.visited);
      expect(result.stadiumId, 'sajik');
    });

    test('원정 경기도 홈 경기와 똑같이 후보다 — 둘을 가르는 값이 없다', () {
      // `lg` 를 응원 팀으로 보면 앞엣것은 홈 경기, 뒤엣것은 원정 경기다.
      final schedule = ScheduleDocument(
        generatedAt: DateTime.utc(2026),
        games: [
          _game(
            id: 'g-home',
            date: '2026-08-25',
            home: 'lg',
            away: 'doosan',
            stadium: 'jamsil',
          ),
          _game(
            id: 'g-away',
            date: '2026-08-25',
            home: 'lotte',
            away: 'lg',
            stadium: 'sajik',
          ),
        ],
      );

      final candidates = buildStadiumVisitCandidates(
        schedule: schedule,
        stadiums: stadiums,
      );

      expect(
        candidates.map((c) => c.gameId),
        ['g-home', 'g-away'],
        reason: '홈이든 원정이든 후보에서 빠지지 않는다',
      );

      // 그리고 그 구장에 있었는지만 본다 — 둘 다 같은 이유로 방문이 된다.
      for (final probe in [
        (const DeviceFix(lat: _jamsilLat, lng: _jamsilLng), 'jamsil', 'g-home'),
        (const DeviceFix(lat: _sajikLat, lng: _sajikLng), 'sajik', 'g-away'),
      ]) {
        final result = judgeStadiumVisit(
          permission: LocationPermissionStatus.granted,
          candidates: candidates,
          now: duringPregame,
          fix: probe.$1,
        );
        expect(result.reason, StadiumVisitReason.visited);
        expect(result.stadiumId, probe.$2);
        expect(result.gameId, probe.$3);
      }
    });

    // 위 두 시험은 **값**으로 잰다. 그것만으로는 후보 타입에 팀 id 를 하나
    // 더하는 변이가 그대로 통과한다 — round 5 의 검증자가 재현했다:
    // `final String? homeTeamId = null;` 한 줄을 [StadiumVisitCandidate] 에
    // 더해도 `flutter analyze`·훅 4종·시험 663개가 전부 초록불이었다.
    // 결과 타입([StadiumVisitResult])에는 필드 집합 파수꾼이 있는데 후보
    // 타입에는 없었던 것이 그 까닭이다. 같은 방식으로 못 박는다.
    test('후보 타입이 값을 두는 자리는 이 다섯뿐이다 (소스 대조)', () {
      final body = _classBody(
        File('lib/location/visit_check.dart').readAsStringSync(),
        'StadiumVisitCandidate',
      );

      expect(_declaredStorage(body), {
        'gameId': 'final String',
        'stadiumId': 'final String',
        'startsAt': 'final DateTime',
        'lat': 'final double',
        'lng': 'final double',
      }, reason: '후보 타입에 팀 id 가 아예 없는 것이 "홈·원정을 구분하지 않는다"의 계약이다');
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
