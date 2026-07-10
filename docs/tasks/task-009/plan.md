# task-009 plan   (spec: ./spec.md)

**아키텍처 한 줄**: supabase_flutter Auth 위에 Riverpod auth 상태(`onAuthStateChange`) + go_router `redirect` 게이트를 얹고, 카카오는 GoTrue 웹 OAuth(커스텀 스킴 콜백)로 — 앱·인프라·네이티브 딥링크 3층을 한 task로.

## 파일 구조

**신규**
- `app/lib/features/auth/auth_providers.dart` (+ codegen `.g.dart`) — `authStateChanges` 스트림 + `authController`(Notifier).
- `app/lib/features/auth/login_screen.dart` — 이메일/비번 폼 + [카카오로 시작].
- `app/lib/core/go_router_refresh_stream.dart` — `Stream`→`Listenable` 소형 헬퍼(신규 dep 없음).

**수정**
- `app/lib/router/router.dart` (+regen) — `/login` 라우트, `redirect`, `refreshListenable`.
- `app/lib/router/home_screen.dart` — 로그아웃 AppBar 액션.
- `app/android/app/src/main/AndroidManifest.xml` — `kboaway://login-callback` intent-filter.
- `app/ios/Runner/Info.plist` — `CFBundleURLTypes` scheme `kboaway`.
- `infra/supabase/docker-compose.yml` — auth 서비스 `GOTRUE_EXTERNAL_KAKAO_*`.
- `infra/supabase/.env` (gitignore, 라이브 수정) — autoconfirm + redirect allowlist + 카카오 키. `.env.example` 동기.

## Step 분해

각 Step 끝 = **build/analyze 깨짐만 확인**(단위테스트·리뷰는 끝 검증에서 일괄).
앱 codegen 파일 수정 후 공통: `cd app && dart run build_runner build --delete-conflicting-outputs && flutter analyze`.

- [ ] **Step 1 — auth 상태/컨트롤러**: `auth_providers.dart` 작성. `authStateChanges`(`@riverpod Stream<AuthState>` ← `supabaseClientProvider.auth.onAuthStateChange`), `authController`(Notifier: `signInEmail`/`signUpEmail`/`signInKakao`/`signOut`, AsyncValue 로딩·에러). `signInKakao` = `signInWithOAuth(OAuthProvider.kakao, redirectTo:'kboaway://login-callback')`.
  - 검증: build_runner + `flutter analyze` No issues. 롤백: 파일 삭제.

- [ ] **Step 2 — 로그인 화면**: `login_screen.dart`. 이메일·비번 `TextField`, [로그인]/[회원가입] 모드 토글, [카카오로 시작] 버튼, controller 호출, 에러 SnackBar, 로딩 스피너.
  - 검증: `flutter analyze` No issues. 롤백: 파일 삭제.

- [ ] **Step 3 — 라우터 게이트**: `go_router_refresh_stream.dart` 헬퍼 추가. `router.dart` 에 `GoRoute('/login')` + `redirect`(currentSession 동기 판정) + `refreshListenable`(authStateChanges 스트림). `home_screen.dart` 에 로그아웃 액션.
  - 검증: build_runner + `flutter analyze` + `flutter run` 후 **미인증 시 `/login` 자동 진입** 육안 확인. 롤백: router.dart diff revert.

- [ ] **Step 4 — 네이티브 딥링크**: AndroidManifest intent-filter(scheme `kboaway`, host `login-callback`) + iOS Info.plist `CFBundleURLTypes`.
  - 검증: `flutter build apk --debug`(또는 `flutter analyze` + 빌드) 깨짐 없음. 롤백: 네이티브 파일 revert.

- [ ] **Step 5 — GoTrue 인프라**: `.env` 에 `ENABLE_EMAIL_AUTOCONFIRM=true`, `ADDITIONAL_REDIRECT_URLS=kboaway://login-callback`, 카카오 키 변수. `docker-compose.yml` auth 서비스에 `GOTRUE_EXTERNAL_KAKAO_ENABLED/CLIENT_ID/SECRET/REDIRECT_URI`(=`https://kbo-api.ardenspace.com/auth/v1/callback`). `.env.example` 동기. 맥미니 `kbo-supabase-auth` 재기동.
  - 검증: `curl -s https://kbo-api.ardenspace.com/auth/v1/settings | jq` → `external.kakao:true`, `mailer_autoconfirm:true`. 롤백: env diff revert + 재기동.
  - 메모: 카카오 CLIENT_ID/SECRET 는 @arden 콘솔 발급 후 주입 — 키 도착 전엔 이메일 autoconfirm·allowlist 만 먼저 적용 가능.

## 끝 검증 (구현 완료 후 일괄)

1. **코드 리뷰** — 브랜치 diff 전체(숲). 발견 결정은 handoff `### 결정`.
2. **e2e**:
   - 이메일: 가입 → 세션 수립 → `profiles` row 자동 생성 확인(`select * from profiles where id=...`) → 로그아웃 → 재로그인.
   - 카카오: (콘솔 키 주입 후) [카카오로 시작] → 브라우저 로그인 → 앱 복귀 → 세션 → 홈. `auth.users` 에 kakao identity 확인.
   - 게이트: 미인증 시 `/schedule` 직접 진입 차단 → `/login`.
3. 통과 확인 후 마무리(handoff commit → PR 때 spec 결정 DECISIONS.md 승격).
