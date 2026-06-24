# task-007 spec — Flutter 스캐폴드: init + Supabase 클라이언트 + 네비 골격   확정일: TBD

> PLAN: [task-007] (deep) · 결정 백링크: E1·E9 · 실행계획: [docs/EXECUTION-PLAN.md](../../EXECUTION-PLAN.md)

## 1. 배경 / 문제

Lane B 선행 차단점. Flutter 앱 뼈대 없이는 task-008~013(화면), task-014~017(지도·스탬프) 착수 불가.
현재 `app/` 디렉토리 없음. Flutter 자체도 맥미니·개발 맥 모두 미설치.

## 2. 목표 / 비목표

**목표 (DoD — 완료 기준):**
- ☐ Flutter SDK 설치 완료 (`flutter doctor` 주요 항목 green)
- ☐ `flutter create app/` — 번들ID `com.ardenspace.kboawayfans`, 지원 플랫폼 iOS·Android
- ☐ `pubspec.yaml` 핵심 의존성 추가: `supabase_flutter`, `go_router`, `flutter_riverpod`, `riverpod_annotation`
- ☐ `app/lib/main.dart` — Supabase 초기화 (URL·anonKey env/dart-define), `ProviderScope` 감싸기
- ☐ `app/lib/core/supabase_client.dart` — `supabaseClient` Riverpod Provider
- ☐ `app/lib/router/router.dart` — go_router 골격 (4개 루트: `/`, `/schedule`, `/stadium/:id`, `/stamp`)
- ☐ `flutter analyze` 경고 0 (info 허용)
- ☐ iOS Simulator 또는 Android Emulator에서 앱 실행 → 스켈레톤 화면 표시

**비목표 (YAGNI):**
- 실제 화면 UI (task-008~013)
- 로그인 플로우 (task-009)
- 지도·스탬프 (task-014~017)
- Android 릴리즈 서명, iOS 프로비저닝
- CI/CD

## 3. 설계(안)

### 3-1. 폴더 구조

```
app/
  lib/
    main.dart                    ← Supabase.init + ProviderScope + runApp
    router/
      router.dart                ← go_router GoRouter provider
    core/
      supabase_client.dart       ← supabaseClient provider (Supabase.instance.client)
    features/
      schedule/                  ← task-010 (원정 일정)
      stadium/                   ← task-011 (구장 가이드)
      places/                    ← task-012 (맛집·플랜B)
      planb/                     ← task-013 (우천 플랜B 유도)
      stamp/                     ← task-014~015 (GPS 스탬프)
      map/                       ← task-016~017 (네이버맵)
      auth/                      ← task-009 (로그인)
    shared/
      widgets/                   ← 공용 위젯
      theme/                     ← task-008 (팀 테마 컬러)
  pubspec.yaml
  .env.example                   ← SUPABASE_URL, SUPABASE_ANON_KEY 문서화
```

### 3-2. 네비게이션 골격 (go_router)

```
/                → HomeScreen (응원팀 설정 or 원정 일정 진입점)
/schedule        → ScheduleScreen (task-010)
/stadium/:id     → StadiumScreen (task-011)
/stamp           → StampScreen (task-014)
```

### 3-3. Supabase 초기화

```dart
// main.dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
);
```

빌드 시 `--dart-define=SUPABASE_URL=https://kbo-api.ardenspace.com --dart-define=SUPABASE_ANON_KEY=...` 전달.
키를 소스에 하드코딩하지 않음 (E10).

## 4. 대안 & 결정 ★

### D1 — 네비게이션 라이브러리

| 방법 | 장점 | 단점 |
|---|---|---|
| **go_router (채택)** | 선언형·URL 기반, 딥링크, 네이버맵 연동에 유리, Flutter 공식 권장 | 초기 설정 약간 verbose |
| Navigator 2.0 직접 | 의존성 0 | 보일러플레이트 과다, 딥링크 직접 구현 |
| auto_route | 코드 생성 편리 | 추가 build_runner 의존 |

→ **go_router 채택**. 공식 권장 + 딥링크 + 지도 연동 대비.

### D2 — 상태관리

| 방법 | 장점 | 단점 |
|---|---|---|
| **Riverpod (채택)** | 컴파일 타임 안전, async 지원 우수, Supabase 패턴과 잘 맞음 | 학습 곡선 약간 있음 |
| Provider | 단순, 익숙함 | Riverpod으로 대체 권장 추세 |
| Bloc | 패턴 명확 | 보일러플레이트 과다, dogfood 오버킬 |
| GetX | 코드량 적음 | 마법 많아 디버깅 어려움 |

→ **Riverpod 채택**. `flutter_riverpod` + `riverpod_annotation` (코드 생성).

### D3 — 폴더 구조

| 방법 | 장점 | 단점 |
|---|---|---|
| **feature-first (채택)** | task 단위와 1:1 매핑, 화면 추가가 독립적 | 공용 코드 위치 불명확 (→ shared/ 로 해결) |
| layer-first | 계층 분리 명확 | 단순 앱엔 과도한 분리, 파일 왔다갔다 |

→ **feature-first 채택**. PLAN.md task 분해와 1:1 대응.

### D4 — Supabase 키 주입

| 방법 | 장점 | 단점 |
|---|---|---|
| **dart-define (채택)** | 소스 미포함, 빌드 파라미터로 분리 | 빌드 명령에 항상 포함 필요 |
| .env 파일 (flutter_dotenv) | 친숙 | 패키지 추가, 앱 번들에 포함 위험 |
| 하드코딩 | 없음 | E10 키 격리 위반 |

→ **dart-define 채택**. E10 격리 원칙 준수.

## 5. 영향 / 리스크

- **Flutter 미설치**: Step 0에서 설치 필요. SDK 설치 + PATH 설정 + `flutter doctor` 통과 전까지 이후 step 불가.
- **iOS 빌드**: Xcode 설치 여부 미확인. `flutter doctor` 결과에 따라 CocoaPods 추가 설치 필요할 수 있음.
- **번들ID**: `com.ardenspace.kboawayfans` — 깃 레포지토리명과 일치. 앱스토어 배포 시 그대로 사용. 지금 정해두면 이후 변경 공수 큼.
- **롤백**: `app/` 디렉토리 삭제로 완전 롤백.

## 6. 의존 / 사인오프

- **의존**: task-002 스키마 ✅ (Supabase URL·키는 infra/.env에서)
- **차단**: task-008~017 전부 이 스캐폴드 대기
- **사인오프**: @arden (솔로)
