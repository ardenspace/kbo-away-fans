/// 저장소의 **두 쪽이 같은 값이어야 하는 자리**를 대조한다 — 앱 키 세 자리를
/// `kakao_app_key_sync_test.dart` 가 맞춰 보는 것과 같은 종류의 시험이다.
///
/// 여기서 재는 것은 셋이다.
///
/// 1. **호출 좌표** — Dart 쪽 `kKakaoFunctionRegion`·`kKakaoCustomTokenCallable`
///    이 `functions/index.js` 의 리전·export 이름과 같은가. 두 값은 서로 다른
///    언어의 서로 다른 파일에 손으로 적혀 있고, 어긋나면 호출이 **존재하지 않는
///    함수**로 나가 `not-found` 로 실패한다. 그 증상은 실기기에서만 보인다 —
///    `flutter test`·`flutter analyze`·`npm --prefix functions test` 가 전부
///    초록불인 채로 카카오 로그인만 죽는다.
///
/// 2. **App Check 배선의 존재와 순서** — `main` 이 `BackendAppCheck` 을 인증보다
///    **먼저** 켜는가. App Check 토큰은 활성화된 뒤에 나가는 호출에만 붙으므로
///    순서가 뒤집히거나 줄이 사라지면 커스텀 토큰 함수 호출에 토큰이 실리지
///    않고, 함수는 `enforceAppCheck: true` 라 그 호출을 전부 거절한다. 배선의
///    **동작**은 `app_check_activation_test.dart` 가 재지만, `main` 이 그것을
///    실제로 부르는지는 거기서 잴 수 없다.
///
/// 3. **업로드 payload 의 손으로 옮겨 적은 사본** —
///    `firebase/test/probe-2-4-app-payload.test.mjs` 의
///    `newUserProfilePayload`/`patchPayload` 는 `NewUserProfile.toData()`·
///    `UserProfilePatch.toData()` 를 JS 로 다시 적은 것이다. 그 탐침이 재는
///    것은 "앱이 실제로 보내는 모양이 규칙을 통과하는가"인데, Dart 쪽이 필드를
///    더하거나 이름을 바꿔도 사본은 옛 모양을 계속 통과시켜 탐침이 **옛 앱**을
///    검사하게 된다. 그 어긋남은 실기기에서 규칙 거부로만 드러나므로 두 쪽의
///    키와 서버 시각 필드를 여기서 대조한다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth_kakao.dart';
import 'package:kbo_away_fans/backend/user_data.dart';

void main() {
  group('앱과 함수의 호출 좌표', () {
    final source = File('functions/index.js').readAsStringSync();

    test('리전이 함수 쪽 setGlobalOptions 와 같다', () {
      final region = RegExp(
        r"setGlobalOptions\(\s*\{[^}]*region:\s*'([^']*)'",
      ).firstMatch(source)?.group(1);

      expect(
        region,
        isNotNull,
        reason: 'functions/index.js 에서 setGlobalOptions 의 region 을 읽지 못했다',
      );
      expect(
        region,
        kKakaoFunctionRegion,
        reason:
            '두 값이 갈라지면 앱은 없는 함수를 부르고 `not-found` 로 실패한다 — '
            '리전을 옮길 때는 두 파일을 함께 고친다',
      );
    });

    test('callable 이름이 함수 쪽 export 와 같다', () {
      expect(
        source.contains('export const $kKakaoCustomTokenCallable = onCall('),
        isTrue,
        reason: 'functions/index.js 가 이 이름으로 export 하지 않으면 호출이 닿지 않는다',
      );
    });
  });

  group('App Check 배선', () {
    final main = File('lib/main.dart').readAsStringSync();

    test('main 이 App Check 을 켠다', () {
      expect(
        main.contains('BackendAppCheck.ensureInitialized()'),
        isTrue,
        reason:
            '이 줄이 사라져도 나머지 시험은 전부 통과한다 — 그리고 배포된 함수는 '
            '토큰 없는 호출을 전부 거절하므로 카카오 로그인이 통째로 막힌다',
      );
    });

    test('App Check 을 인증보다 먼저 켠다', () {
      final appCheck = main.indexOf('BackendAppCheck.ensureInitialized()');
      final auth = main.indexOf('FirebaseAuthService.ensureInitialized()');

      expect(appCheck, greaterThanOrEqualTo(0));
      expect(auth, greaterThanOrEqualTo(0));
      expect(
        appCheck,
        lessThan(auth),
        reason:
            'App Check 토큰은 활성화된 뒤에 나가는 호출에만 붙는다 — 순서가 뒤집히면 '
            '커스텀 토큰 함수 호출이 토큰 없이 나갈 수 있다',
      );
    });
  });

  group('앱의 업로드 payload 와 규칙 탐침의 사본', () {
    const probePath = 'firebase/test/probe-2-4-app-payload.test.mjs';
    final probe = File(probePath).readAsStringSync();

    /// 탐침이 손으로 적어 둔 payload 함수의 몸통을 꺼낸다.
    String bodyOf(String functionName) {
      final match = RegExp(
        'function $functionName\\([^)]*\\) \\{\\s*return \\{([\\s\\S]*?)\\n  \\};',
      ).firstMatch(probe);
      expect(
        match,
        isNotNull,
        reason: '$probePath 에서 $functionName 의 payload 를 읽지 못했다 — '
            '이름이나 모양이 바뀌었으면 이 대조도 함께 고친다',
      );
      return match!.group(1)!;
    }

    /// 몸통에 적힌 필드 이름들 (JS 의 축약 표기 `nickname,` 도 필드다).
    Set<String> keysOf(String body) =>
        RegExp(r'^\s*([A-Za-z_][\w]*)\s*(?::|,\s*$)', multiLine: true)
            .allMatches(body)
            .map((match) => match.group(1)!)
            .toSet();

    /// 그중 서버 시각 센티널로 적힌 것들.
    Set<String> serverTimesOf(String body) =>
        RegExp(r'^\s*([A-Za-z_][\w]*):\s*serverTimestamp\(\)', multiLine: true)
            .allMatches(body)
            .map((match) => match.group(1)!)
            .toSet();

    /// Dart 쪽 payload 에서 서버 시각으로 나가는 필드들.
    Set<String> serverTimeFields(Map<String, Object?> data) => data.entries
        .where((entry) => entry.value is ServerTimestamp)
        .map((entry) => entry.key)
        .toSet();

    test('첫 문서 payload 의 필드가 두 쪽에서 같다', () {
      final dart = const NewUserProfile(
        nickname: '원정러1234',
        favoriteTeamId: 'hanwha',
        profileThemeKey: 'hanwha',
      ).toData();
      final body = bodyOf('newUserProfilePayload');

      expect(
        keysOf(body),
        dart.keys.toSet(),
        reason: 'NewUserProfile.toData() 가 바뀌었는데 $probePath 의 사본이 옛 모양이다 — '
            '탐침이 옛 앱을 검사하게 된다',
      );
      expect(serverTimesOf(body), serverTimeFields(dart));
    });

    test('수정 payload 의 필드가 두 쪽에서 같다', () {
      final dart = const UserProfilePatch(
        favoriteTeamId: 'doosan',
        profileThemeKey: 'doosan',
      ).toData();
      final body = bodyOf('patchPayload');

      expect(
        keysOf(body),
        dart.keys.toSet(),
        reason: 'UserProfilePatch.toData() 가 바뀌었는데 $probePath 의 사본이 옛 모양이다',
      );
      expect(serverTimesOf(body), serverTimeFields(dart));
    });

    test('앱이 보낼 수 있는 모든 필드를 탐침이 한 번은 규칙에 통과시켜 본다', () {
      // 팀 변경만 재는 사본은 세 키밖에 모른다. 3.x 마이페이지가 여는 경로는
      // `nickname` 만 실은 수정이라, 그 필드가 탐침의 payload 어디에도 없으면
      // 규칙이 그것을 받아 주는지 아무도 재지 않은 채 배포된다.
      final everything = const UserProfilePatch(
        nickname: '바꾼닉',
        favoriteTeamId: 'kia',
        profileThemeKey: 'kia',
      ).toData();
      final known = keysOf(bodyOf('patchPayload'))
        ..addAll(keysOf(bodyOf('newUserProfilePayload')))
        ..addAll(keysOf(bodyOf('nicknamePatchPayload')));

      expect(everything.keys, everyElement(isIn(known)));
    });
  });
}
