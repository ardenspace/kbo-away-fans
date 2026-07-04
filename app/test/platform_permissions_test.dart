import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// task-1.2 수용기준: 플랫폼 위치 권한 선언 검증.
/// 포그라운드 온리 — 백그라운드 위치 권한은 선언 금지 (보안 제약).
void main() {
  test('iOS Info.plist 에 NSLocationWhenInUseUsageDescription 이 있다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
    // 키 다음에 비어 있지 않은 설명 문자열이 있어야 한다.
    final match = RegExp(
      r'<key>NSLocationWhenInUseUsageDescription</key>\s*<string>([^<]+)</string>',
    ).firstMatch(plist);
    expect(match, isNotNull, reason: '사용 목적 설명 문자열이 있어야 한다');
    expect(match!.group(1)!.trim(), isNotEmpty);
  });

  test('iOS 백그라운드 위치 권한은 선언하지 않는다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('NSLocationAlwaysAndWhenInUseUsageDescription')));
    expect(plist, isNot(contains('NSLocationAlwaysUsageDescription')));
    expect(plist, isNot(contains('UIBackgroundModes')));
  });

  test('AndroidManifest 에 FINE + COARSE 위치 권한이 있다', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      contains('android.permission.ACCESS_FINE_LOCATION'),
    );
    expect(
      manifest,
      contains('android.permission.ACCESS_COARSE_LOCATION'),
    );
  });

  test('Android 백그라운드 위치 권한은 선언하지 않는다', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      manifest,
      isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')),
    );
  });
}
