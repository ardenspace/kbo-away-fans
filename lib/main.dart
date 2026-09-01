import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/analytics.dart';
import 'app.dart';
import 'backend/auth_firebase.dart';
import 'ui/shared/stadium_map_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 네이버 지도 SDK — 클라이언트 ID(--dart-define=NAVER_MAP_CLIENT_ID) 가
  // 없으면 조용히 건너뛰고 지도는 자리 표시 폴백으로 렌더된다.
  await StadiumMapView.ensureInitialized();
  // Firebase Analytics — 설정 파일이 없거나 초기화가 실패하면
  // 조용히 no-op 모드로 남는다 (이벤트는 버려지고 앱은 정상 동작).
  await FirebaseAnalyticsClient.instance.ensureInitialized();
  // Firebase Auth — 여기서 미리 세워 두면 세션 복원(네이티브의 첫 인증 이벤트)
  // 을 기다리는 구간이 스플래시 뒤로 숨어, 로그인해 둔 사람의 콜드 스타트에서
  // 로그인 화면이 번쩍이지 않는다. 설정 파일이 없으면 연결하지 않고 넘어가고,
  // 그 실행에서는 로그인 화면이 안내와 함께 선다 (조용한 no-op 이 아니다).
  await FirebaseAuthService.ensureInitialized();
  runApp(const ProviderScope(child: KboAwayFansApp()));
}
