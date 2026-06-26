# task-009 spec — 로그인: 이메일 + 카카오 OAuth   확정일: 2026-06-26

> PLAN: [task-009] (deep) 로그인: 이메일 + 카카오 OAuth (E2) · 출처 [docs/EXECUTION-PLAN.md](../../EXECUTION-PLAN.md) E2

## 1. 배경 / 문제

현재 앱은 인증이 없다. 라우터(`app/lib/router/router.dart`)에 auth gate가 없고, 누구나 모든 화면 진입.
이후 task들(010 응원팀 설정, 014 GPS 스탬프)은 `profiles`·`stamps` 에 쓰는데, 이 테이블은 RLS owner-scoped(`auth.uid()`) — **로그인 세션 없이는 유저 상태 저장 자체가 불가**(task-002 RLS). 따라서 로그인은 모든 유저-상태 기능의 선행.

인프라 측: `handle_new_user()` 트리거가 task-002에서 깔려 있어 가입 시 `profiles` row 자동 생성됨. 자가호스팅 GoTrue(`supabase/gotrue:v2.189.0`)는 카카오를 외부 provider로 정식 지원하지만, hosted처럼 콘솔 토글이 아니라 `GOTRUE_EXTERNAL_KAKAO_*` env + Kakao 개발자콘솔 앱등록이 필요.

## 2. 목표 / 비목표

**목표 (= 완료조건/DoD)**
- ☐ 이메일 회원가입 + 로그인(비밀번호)이 맥미니 Supabase 대상으로 e2e 동작.
- ☐ 카카오 로그인이 **GoTrue 웹 OAuth**(`signInWithOAuth` + 커스텀 스킴 콜백)로 e2e 동작 — 브라우저 카카오 로그인 후 앱 복귀·세션 수립.
- ☐ auth 상태 provider(`onAuthStateChange` 스트림) + go_router redirect 게이팅: 미인증→`/login`, 인증 상태에서 `/login`→`/`.
- ☐ 로그아웃 동작(홈에서 호출 → `/login` 복귀).
- ☐ 가입 시 `profiles` row 자동 생성 확인(트리거 동작).
- ☐ GoTrue infra 설정(이메일 autoconfirm, 카카오 external env)이 맥미니에 적용되어 위가 실제로 동작.

**비목표 (YAGNI)**
- 응원팀 설정 화면 — task-010. 로그인 성공 후 **홈(`/`)으로만** 보낸다.
- 구글/애플 로그인 — E2 "후속".
- 비밀번호 재설정·이메일 인증 메일 플로우 — v1은 SMTP 없이 autoconfirm.
- 프로필 편집 UI, 계정 탈퇴.
- 네이티브 KakaoTalk SDK 로그인(원탭).

## 3. 설계(안)

### 화면·플로우
- `/login` 라우트 신규. 단일 화면: 이메일·비밀번호 필드 + [로그인]/[회원가입] 토글 + [카카오로 시작] 버튼.
- 로그인/가입 성공 → redirect가 `/`로 보냄(화면이 직접 push 안 함, gate가 처리).
- 카카오 버튼 → `signInWithOAuth(OAuthProvider.kakao, redirectTo: 'kboaway://login-callback')` → 외부 브라우저 → 카카오 로그인 → `kboaway://login-callback` 딥링크로 앱 복귀 → supabase_flutter가 세션 자동 수립 → `onAuthStateChange` 발화 → redirect가 `/`로.
- 홈 화면에 로그아웃 진입점(AppBar 액션) 추가.

### 코드 구조 (app/lib/features/auth/ — 형제(features/*) 일관성)
- `auth_providers.dart` — `@riverpod` 으로:
  - `authStateChanges` (Stream<AuthState>, `supabase.auth.onAuthStateChange`),
  - `authController` (Notifier): `signInEmail`/`signUpEmail`/`signInKakao`/`signOut` 메서드 + 로딩/에러 상태.
- `login_screen.dart` — 폼 + 카카오 버튼, controller 호출, 에러 SnackBar.
- 라우터 redirect는 `supabase.instance.client.auth.currentSession`(동기) 으로 판정, `refreshListenable`로 스트림에 반응.

### 라우터 게이팅 (router.dart 수정)
- `GoRoute('/login')` 추가.
- `redirect`: `loggedIn = currentSession != null`; `!loggedIn && loc != '/login' → '/login'`; `loggedIn && loc == '/login' → '/'`.
- `refreshListenable`: auth 스트림 → `Listenable`(소형 `GoRouterRefreshStream` 헬퍼, 신규 dep 없음).

### 인프라 (infra/supabase/ — 맥미니 적용)
- `.env`: `ENABLE_EMAIL_AUTOCONFIRM=true`(→ GOTRUE_MAILER_AUTOCONFIRM), `ADDITIONAL_REDIRECT_URLS` 에 `kboaway://login-callback` 추가, 카카오 키 변수(`KAKAO_CLIENT_ID`/`KAKAO_SECRET`) 추가(.env 는 gitignore, 예시는 `.env.example`/문서).
- `docker-compose.yml` auth 서비스에 `GOTRUE_EXTERNAL_KAKAO_ENABLED/CLIENT_ID/SECRET/REDIRECT_URI` 추가. redirect_uri = `https://kbo-api.ardenspace.com/auth/v1/callback`.
- cloudflared ingress 는 `/auth` 이미 allowlist(task-001) — 튠넬 변경 불필요.
- 적용: `supabase-auth`(gotrue) 컨테이너 재기동.

### 네이티브 딥링크 설정
- Android `AndroidManifest.xml`: launch activity 에 `kboaway://login-callback` intent-filter.
- iOS `Info.plist`: `CFBundleURLTypes` 에 scheme `kboaway`.

### @arden 수동 단계 (콘솔)
- developers.kakao.com 앱 생성 → REST API key(= CLIENT_ID) + client secret 발급 → Redirect URI 에 `https://kbo-api.ardenspace.com/auth/v1/callback` 등록 → 카카오 로그인 활성화.

## 4. 대안 & 결정 ★

1. **카카오 플로우: GoTrue 웹 OAuth ✅ vs 네이티브 KakaoTalk SDK.**
   웹 OAuth 채택 — 앱 코드 간단, 네이티브 키해시(Android SHA)·iOS URL스킴·OIDC idToken 배선 불필요, v1 dogfood에 충분. 네이티브 원탭 UX는 출시 직전 fast-follow 후보. (사용자 확정)
2. **이메일 확인: autoconfirm ✅ vs SMTP 메일 인증.**
   autoconfirm — v1은 SMTP 인프라 없음(.env SMTP 빈값). 가입 즉시 세션. SMTP는 나중에 reversible.
3. **auth 게이팅: go_router redirect+refreshListenable ✅ vs StreamBuilder 래퍼/수동 네비.**
   redirect — 중앙집중, 기존 go_router 자산 재사용, 딥링크와도 자연스러움.
4. **provider: 이메일+카카오 유지 ✅ vs 구글로 교체.**
   유지 — 카카오맵→네이버맵 교체는 지도 SDK 문제로 로그인과 무관. 타겟(한국 야구팬) 적합성·dogfood 현실성 우선(E2 그대로). (사용자 확정)

## 5. 영향 / 리스크

- **infra 변경(맥미니)**: `docker-compose.yml`+`.env` 수정 후 gotrue 재기동. 오타 시 auth 컨테이너 다운 → 이메일 로그인까지 마비. **롤백**: env 되돌리고 재기동.
- **카카오 email scope 리스크**: 카카오 개인앱이 이메일을 보장 못 줄 수 있고(동의항목 비즈앱 심사), GoTrue Kakao provider가 이메일 없으면 가입 실패할 수 있는 알려진 지점. **완화**: 구현 중 실로그인으로 검증, 막히면 handoff `### 블로커`에 기록 후 사용자와 비즈앱/대안 협의.
- **게이트 도입**: `/schedule` 등 기존 라우트가 미인증 시 `/login` 으로 redirect — 의도된 동작.
- **신규 dep 없음**: supabase_flutter 가 app_links 로 딥링크 콜백 자동 처리. redirect refresh 는 소형 헬퍼.
- cloudflared `/auth` 이미 허용 — 튠넬 무변경.

## 6. 의존 / 사인오프

- **역할**: 솔로 @arden.
- **선행(충족)**: task-002 profiles 트리거 ✓, task-007 Flutter 스캐폴드 ✓.
- **이 task가 막는 것**: task-010(응원팀, auth.uid 필요), task-014(스탬프).
- **수동 게이트**: @arden 의 Kakao 개발자콘솔 앱등록 + REST API key/secret 발급 (코드/인프라 준비 후 키 주입 → e2e 검증).
