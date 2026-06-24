# task-007 plan   (spec: ./spec.md)

## 아키텍처 한 줄

Flutter SDK 설치 → `flutter create app/` → 핵심 패키지 추가 → Supabase 초기화 + Riverpod + go_router 골격 연결.

## 파일 구조 (신규)

```
app/
  lib/
    main.dart
    router/
      router.dart
    core/
      supabase_client.dart
    features/
      schedule/    (빈 디렉토리 — task-010)
      stadium/     (빈 디렉토리 — task-011)
      places/      (빈 디렉토리 — task-012)
      planb/       (빈 디렉토리 — task-013)
      stamp/       (빈 디렉토리 — task-014~015)
      map/         (빈 디렉토리 — task-016~017)
      auth/        (빈 디렉토리 — task-009)
    shared/
      widgets/     (빈 디렉토리)
      theme/       (빈 디렉토리 — task-008)
  pubspec.yaml
  .env.example
```

## Step 분해

- [ ] **Step 0** — Flutter SDK 설치 + `flutter doctor` 주요 항목 확인
- [ ] **Step 1** — `flutter create app/` (번들ID `com.ardenspace.kboawayfans`, iOS·Android)
- [ ] **Step 2** — `pubspec.yaml` 의존성 추가 + `flutter pub get`
- [ ] **Step 3** — `main.dart`: Supabase.initialize (dart-define) + ProviderScope + go_router 연결
- [ ] **Step 4** — `core/supabase_client.dart`: supabaseClient Provider
- [ ] **Step 5** — `router/router.dart`: 4개 루트 골격
- [ ] **Step 6** — feature 디렉토리 + 플레이스홀더 화면 생성
- [ ] **Step 7** — `flutter analyze` 통과 + 시뮬레이터 실행 확인

## 각 Step 상세

### Step 0 — Flutter SDK 설치

```bash
# macOS: 공식 바이너리 다운로드 방식
cd ~/development  # 또는 원하는 경로
# 최신 stable 다운로드 후 압축 해제
export PATH="$PATH:$HOME/development/flutter/bin"
flutter doctor
```

검증: `flutter --version` → Flutter 3.x 출력.

### Step 1 — flutter create

```bash
cd /Users/arden/code/kbo-away-fans
flutter create \
  --org com.ardenspace \
  --project-name kbo_away_fans \
  --platforms ios,android \
  app
```

검증: `app/lib/main.dart` 생성됨.

### Step 2 — pubspec.yaml 의존성

추가할 패키지:
```yaml
dependencies:
  supabase_flutter: ^2.8.4
  go_router: ^14.6.3
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

dev_dependencies:
  riverpod_generator: ^2.6.2
  build_runner: ^2.4.13
  custom_lint: ^0.7.5
  riverpod_lint: ^2.6.2
```

검증: `flutter pub get` 오류 없음.

### Step 3 — main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const ProviderScope(child: KboAwayApp()));
}

class KboAwayApp extends ConsumerWidget {
  const KboAwayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'KBO 원정팬',
      routerConfig: router,
    );
  }
}
```

검증: `flutter analyze` 오류 없음.

### Step 4 — core/supabase_client.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
```

검증: `flutter analyze` 오류 없음.

### Step 5 — router/router.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/stadium/stadium_screen.dart';
import '../features/stamp/stamp_screen.dart';
import 'home_screen.dart';   // router/ 내 임시 홈 화면

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/',         builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
      GoRoute(
        path: '/stadium/:id',
        builder: (_, state) => StadiumScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/stamp',    builder: (_, __) => const StampScreen()),
    ],
  ),
);
```

검증: `flutter analyze` 오류 없음.

### Step 6 — 플레이스홀더 화면

각 features/ 에 최소 Scaffold만 있는 화면 파일 생성:
- `features/schedule/schedule_screen.dart`
- `features/stadium/stadium_screen.dart` (id 파라미터 받음)
- `features/stamp/stamp_screen.dart`
- `router/home_screen.dart` (임시 홈)

feature 빈 디렉토리: `places/`, `planb/`, `map/`, `auth/`, `shared/widgets/`, `shared/theme/` — `.gitkeep` 추가.

검증: `flutter analyze` 경고 0.

### Step 7 — 실행 확인

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://kbo-api.ardenspace.com \
  --dart-define=SUPABASE_ANON_KEY=<anon_key> \
  -d <simulator_id>
```

검증: 홈 화면 뜨고 콘솔에 Supabase 초기화 에러 없음.

## 롤백

`rm -rf app/` — flutter create 이전 상태로 완전 복구.
