/// 카카오 네이티브 앱 키가 **세 자리에서 같은 값**인지 대조한다.
///
/// 이 키는 감출 값이 아니라 저장소에 그대로 두는 값이고
/// (`.wellbegun/decisions.md` 의 [S] 줄 — 감출지 말지를 "이 값이 바이너리에
/// 실려 나가는가"로 가른다), 대신 소비처가 셋이다:
///
///   1. `lib/backend/auth_kakao.dart` 의 `kKakaoNativeAppKey` (`KakaoSdk.init`)
///   2. `android/app/src/main/AndroidManifest.xml` 의 리다이렉트 스킴
///   3. `ios/Runner/Info.plist` 의 `CFBundleURLTypes`
///
/// 셋이 어긋나면 카카오가 인증을 마치고 앱으로 **돌아오는 길**을 잃는다. 그
/// 증상은 빌드에도 analyze 에도 잡히지 않고 실기기에서 로그인 화면이 멈추는
/// 모양으로만 나타나므로, 값을 바꾸는 사람이 세 파일을 함께 고쳤는지를 여기서
/// 잰다. 저장소에 값을 두기로 한 판단이 감당해야 하는 몫이 이 대조다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth_kakao.dart';

/// 카카오 SDK 가 쓰는 리다이렉트 스킴 — `KakaoSdk.customScheme` 의 기본 규칙.
String get _expectedScheme => 'kakao$kKakaoNativeAppKey';

void main() {
  test('안드로이드 매니페스트의 리다이렉트 스킴이 앱 키와 같다', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    final activity = RegExp(
      r'<activity[^>]*com\.kakao\.sdk\.flutter\.auth\.AuthCodeHandlerActivity[\s\S]*?</activity>',
    ).firstMatch(manifest);
    expect(
      activity,
      isNotNull,
      reason:
          '카카오가 돌아올 액티비티(AuthCodeHandlerActivity)의 인텐트 필터가 없으면 '
          '로그인이 끝나고도 앱으로 돌아오지 못한다',
    );

    final scheme = RegExp(
      r'android:scheme="([^"]*)"',
    ).firstMatch(activity![0]!)?.group(1);
    expect(scheme, _expectedScheme);

    expect(
      activity[0]!.contains('android:host="oauth"'),
      isTrue,
      reason: '카카오 SDK 는 `kakao{키}://oauth` 로 돌아온다',
    );
  });

  test('iOS Info.plist 의 URL 스킴이 앱 키와 같다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    final entry = RegExp(
      r'<string>kakao-sign-in</string>[\s\S]*?<key>CFBundleURLSchemes</key>\s*<array>\s*<string>([^<]*)</string>',
    ).firstMatch(plist);
    expect(
      entry,
      isNotNull,
      reason: 'CFBundleURLTypes 에 kakao-sign-in 항목이 없으면 iOS 에서 돌아오는 길이 없다',
    );
    expect(entry!.group(1), _expectedScheme);
  });

  test('iOS 가 카카오톡을 조회할 수 있어야 한다 (LSApplicationQueriesSchemes)', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final queries = RegExp(
      r'<key>LSApplicationQueriesSchemes</key>\s*<array>([\s\S]*?)</array>',
    ).firstMatch(plist);

    expect(queries, isNotNull);
    expect(
      queries!.group(1)!.contains('<string>kakaokompassauth</string>'),
      isTrue,
      reason:
          '이 스킴이 없으면 `isKakaoTalkInstalled()` 가 언제나 false 를 답해서 '
          '카카오톡이 깔린 기기도 웹 로그인으로 돌아간다',
    );
  });
}
