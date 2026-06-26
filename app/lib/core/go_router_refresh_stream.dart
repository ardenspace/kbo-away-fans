import 'dart:async';

import 'package:flutter/foundation.dart';

/// 임의의 `Stream` 을 go_router 의 `refreshListenable` 로 쓰기 위한 어댑터.
///
/// 스트림이 발화할 때마다 `notifyListeners()` → go_router 가 redirect 를 재평가한다.
/// (auth 상태 스트림을 라우터 게이트에 연결하는 표준 패턴, 신규 dependency 없음.)
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
