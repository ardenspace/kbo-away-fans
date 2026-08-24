import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/analytics.dart';
import 'app.dart';
import 'ui/shared/stadium_map_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 네이버 지도 SDK — 클라이언트 ID(--dart-define=NAVER_MAP_CLIENT_ID) 가
  // 없으면 조용히 건너뛰고 지도는 자리 표시 폴백으로 렌더된다.
  await StadiumMapView.ensureInitialized();
  // Firebase Analytics — 설정 파일이 없거나 초기화가 실패하면
  // 조용히 no-op 모드로 남는다 (이벤트는 버려지고 앱은 정상 동작).
  await FirebaseAnalyticsClient.instance.ensureInitialized();
  runApp(const ProviderScope(child: KboAwayFansApp()));
}
