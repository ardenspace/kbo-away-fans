import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics/analytics.dart';
import 'app.dart';
import 'backend/app_check.dart';
import 'backend/auth_firebase.dart';
import 'ui/shared/stadium_map_view.dart';

/// 스플래시가 걷히기까지 사람이 기다리는 시간의 상한.
///
/// [_initBackends] 의 초기화들은 전부 플랫폼 채널을 건드리고, 그중 셋(분석·App
/// Check·인증)은 **같은** `Firebase.initializeApp()` 을 기다린다. 그 채널이
/// 답하지 않는 실행에서 그 await 는 끝나지 않는다 — 오류가 아니라 침묵이라
/// 각자의 try/catch 가 닿지 못하는 자리다. 그동안 사람이 보는 것은 스플래시
/// 하나뿐이고, 빠져나갈 길은 앱을 다시 켜는 것뿐이다.
///
/// 그래서 이 저장소가 네 자리에 세워 둔 규칙이 여기에도 그대로 선다: **사람이
/// 보는 화면을 붙잡는 기다림에는 상한이 있다**
/// (`backend/app_check.dart` 의 `kAppCheckActivationTimeout`,
/// `backend/user_data_firestore.dart` 의 `kProfileServerConfirmGrace`,
/// `features/team_select/selected_team.dart` 의 `kCachedTeamReadTimeout`,
/// `location/location.dart` 의 `kLocationPermissionTimeout`).
///
/// **상한을 초기화마다 걸지 않고 부팅 전체에 하나로 거는** 까닭은, 이 값이 재는
/// 것이 초기화 하나하나의 길이가 아니라 **스플래시가 걷히지 않는 총 시간**이기
/// 때문이다. 넷에 각각 5초를 걸면 한 실행에서 사람이 앉아 있는 시간이 그 합이
/// 된다. App Check 쪽 상한이 그래도 따로 남아 있는 것은 그쪽 호출자가 둘이라서다
/// — 카카오 로그인 경로도 교환 직전에 같은 함수를 부르고, 거기서 붙잡히는 것은
/// 스플래시가 아니라 잠긴 로그인 버튼이다.
///
/// **상한을 넘긴 실행에서도 앱은 뜬다 — Firebase 가 서지 않은 채로.** 그 실행의
/// `FirebaseAuthService.instance` 는 `firebase-unconfigured` 로 던지고,
/// `authStateProvider` 가 오류 상태가 되어 루트 게이트는 **이미 있는 갈래**를
/// 그린다: 로그인 화면 + "로그인 상태를 확인하지 못했어요" 안내(`app.dart` 의
/// `RootGate`). 설정 파일이 없는 클론이 뜨는 모양과 같다. 새 갈래를 열지 않는
/// 것은 사람이 보는 사실이 같기 때문이다 — 어느 쪽이든 이 실행에서는 로그인할
/// 수 없고, 그것이 안내로 말해진다. 말없이 로그인 화면만 세우지 않는 까닭은
/// 1.6 이 정한 그대로다(조용한 no-op 은 설정 실수를 숨긴다).
///
/// 잘려도 시도는 남아 돌고 있다 — 플랫폼 채널에는 취소할 길이 없다. 늦게 끝난
/// App Check 활성화는 그대로 켜지고, 카카오 로그인 경로가 교환 직전에 다시 부를
/// 때 그 결과를 쓴다.
const Duration kBootInitTimeout = Duration(seconds: 5);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 부팅 전체가 [kBootInitTimeout] 아래 있다 — 넘으면 선 것만 가지고 앱을
  // 띄운다. 여기서 던지지 않는 것은 초기화 넷이 모두 실패를 스스로 삼키는
  // 자리이기 때문이고, 잘린 실행도 그 "실패한 실행"과 같은 모양으로 뜬다.
  await _initBackends().timeout(kBootInitTimeout, onTimeout: () {});
  runApp(const ProviderScope(child: KboAwayFansApp()));
}

/// `runApp` 앞에 서야 하는 초기화들 — 통째로 [kBootInitTimeout] 의 상한 아래 있다.
Future<void> _initBackends() async {
  // 네이버 지도 SDK — 클라이언트 ID(--dart-define=NAVER_MAP_CLIENT_ID) 가
  // 없으면 조용히 건너뛰고 지도는 자리 표시 폴백으로 렌더된다.
  await StadiumMapView.ensureInitialized();
  // Firebase Analytics — 설정 파일이 없거나 초기화가 실패하면
  // 조용히 no-op 모드로 남는다 (이벤트는 버려지고 앱은 정상 동작).
  await FirebaseAnalyticsClient.instance.ensureInitialized();
  // App Check — 백엔드가 이 앱의 빌드가 건 호출만 받게 한다. 인증보다 **먼저**
  // 켜야 커스텀 토큰 함수 호출에 토큰이 실린다 (`backend/app_check.dart`).
  await BackendAppCheck.ensureInitialized();
  // Firebase Auth — 여기서 미리 세워 두면 세션 복원(네이티브의 첫 인증 이벤트)
  // 을 기다리는 구간이 스플래시 뒤로 숨어, 로그인해 둔 사람의 콜드 스타트에서
  // 로그인 화면이 번쩍이지 않는다. 설정 파일이 없으면 연결하지 않고 넘어가고,
  // 그 실행에서는 로그인 화면이 안내와 함께 선다 (조용한 no-op 이 아니다).
  await FirebaseAuthService.ensureInitialized();
}
