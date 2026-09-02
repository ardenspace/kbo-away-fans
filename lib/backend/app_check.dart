/// App Check — 백엔드가 **이 앱의 빌드**가 건 호출만 받게 한다.
///
/// 이 겹이 필요한 자리는 커스텀 토큰 함수(`kakaoCustomToken`)다. 그 함수는
/// 로그인 **전에** 불리므로 호출자 인증을 요구할 수 없고(요구할 자격 증명이
/// 바로 그 함수가 발급하려는 것이다), 그래서 URL 만 알면 누구나 부를 수 있다.
/// 부르는 것 자체가 카카오 API 왕복과 함수 실행 시간이 되므로, 남이 반복해서
/// 부르면 그대로 요금이 된다. 실제 브레이크는 `maxInstances: 10` 하나뿐이고
/// (예산은 알림일 뿐 지출을 막지 않는다), App Check 이 그 앞에 한 겹을 더한다.
/// 함수 쪽 강제는 `functions/index.js` 의 `enforceAppCheck: true` 다 — 클라이언트
/// 배선만 하고 강제를 켜지 않으면 아무것도 막지 않으므로 둘은 같은 단계에서
/// 함께 선다.
///
/// **증명 제공자는 빌드 모드로 갈린다.** 디버그 빌드는 기기마다 콘솔에 등록하는
/// 디버그 토큰을 쓴다(실기기·시뮬레이터·에뮬레이터 모두). 릴리스 빌드는
/// 안드로이드 Play Integrity, iOS DeviceCheck 다. 릴리스에서 디버그 제공자를
/// 쓰면 앱에 박힌 토큰 하나로 강제가 무력해지고, 디버그에서 실제 제공자를 쓰면
/// 서명·등록이 갖춰지지 않은 개발 빌드가 로그인부터 막힌다.
library;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// App Check 배선 — `main` 이 1회 호출한다.
class BackendAppCheck {
  BackendAppCheck._();

  static bool _activated = false;

  /// 이 실행에서 App Check 이 실제로 켜졌는가 (진단·테스트용).
  static bool get isActivated => _activated;

  /// App Check 을 켠다.
  ///
  /// 분석 래퍼·인증 구현과 같은 모양이다: 설정 파일이 없거나 초기화가 실패하면
  /// 예외를 삼키고 켜지지 않은 채 넘어간다. 여기서 드러나게 실패시키지 않는
  /// 것은, 설정이 없는 실행은 어차피 인증이 `firebase-unconfigured` 로 드러나게
  /// 실패해서 **같은 사실이 이미 한 번 말해지기** 때문이다. 두 번 말하면 앱이
  /// 뜨지도 않는다.
  ///
  /// 인증보다 **먼저** 불러야 한다. App Check 토큰은 활성화된 뒤에 나가는
  /// 호출에만 붙으므로, 커스텀 토큰 함수를 부르기 전에 켜져 있어야 한다.
  static Future<void> ensureInitialized() async {
    if (_activated) return;
    try {
      // 인증 쪽과 같은 이유로 여기서도 초기화를 보장한다 — 호출 순서가 어떻든
      // 이 줄 뒤에는 앱이 서 있다 (`initializeApp` 은 두 번 불러도 같다).
      await Firebase.initializeApp();
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
      _activated = true;
    } catch (_) {
      // 설정 없는 클론·초기화 실패 — 켜지 않고 넘어간다.
    }
  }
}
