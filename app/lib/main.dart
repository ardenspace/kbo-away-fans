import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/map/naver_map_config.dart';
import 'router/router.dart';
import 'shared/theme/team_theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  assert(
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty,
    'SUPABASE_URL / SUPABASE_ANON_KEY 가 비어 있습니다. '
    'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... 로 실행하세요.',
  );

  // NCP_MAP_CLIENT_ID 는 SUPABASE_* 와 같은 주입 컨벤션을 따르되, 미주입이어도
  // crash 시키지 않는다 — 지도 화면만 안내 텍스트로 degrade 하고 나머지(스탬프
  // 등)는 정상 동작한다 (R12). 개발 중 누락을 알 수 있도록 debug 경고만 남긴다.
  assert(() {
    if (shouldDegradeMap(ncpMapClientId)) {
      debugPrint(
        'NCP_MAP_CLIENT_ID 미주입 — 지도 화면은 안내 텍스트로 degrade 됩니다. '
        'flutter run --dart-define=NCP_MAP_CLIENT_ID=... 로 실키를 주입하세요.',
      );
    }
    return true;
  }());

  // Client ID 실주입 지점: flutter_naver_map ^1.4.4 는 네이티브 파일에 키를 박지
  // 않고 Dart 에서 초기화한다. 빌드 타임 --dart-define 값(ncpMapClientId)을 그대로
  // 넘긴다 — 리터럴 키를 코드/네이티브 설정에 하드코딩하지 않는다. 미주입 시엔
  // init 을 스킵해 crash 없이 지도 화면만 degrade 시킨다 (R12).
  if (!shouldDegradeMap(ncpMapClientId)) {
    await FlutterNaverMap().init(
      clientId: ncpMapClientId,
      onAuthFailed: (ex) => debugPrint('NAVER Map 인증 실패: $ex'),
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );
  runApp(const ProviderScope(child: KboAwayApp()));
}

class KboAwayApp extends ConsumerWidget {
  const KboAwayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final theme = ref.watch(teamThemeProvider);
    return MaterialApp.router(
      title: 'KBO 원정팬',
      theme: theme,
      routerConfig: router,
    );
  }
}
