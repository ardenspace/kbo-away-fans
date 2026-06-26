# Handoff: feat/task-009-login — @arden

## 2026-06-26

- [ ] task-009 (deep) 로그인: 이메일 + 카카오 OAuth (E2)

### 진행
- ✅ spec.md → plan.md 승인
- ✅ Step 1 auth_providers (AuthController) · Step 2 login_screen · Step 3 라우터 게이트+로그아웃 · Step 4 네이티브 딥링크 · Step 5 GoTrue 카카오 env + ops 문서
- ✅ 끝검증 코드리뷰: dead provider 제거 + 게이트 테스트 재작성. analyze 0 issues, 5 tests pass.
- ⏳ **e2e 미완(사용자 ops 게이트)**: `docs/tasks/task-009/ops-kakao-setup.md` — (1) Kakao 콘솔 앱등록+키, (2) 맥미니 `.env`(autoconfirm/allowlist/KAKAO_*) + gotrue 재기동, (3) 시뮬레이터 실행해 이메일 가입·profiles 자동생성·카카오·게이트 차단 확인.

### 다음
- 사용자: ops-kakao-setup.md 적용 → 이메일/카카오 e2e 확인 → 통과 시 PLAN [task-009] 체크 + DECISIONS 승격

### 결정
- **provider = 이메일 + 카카오 유지** (E2 그대로). 카카오맵→네이버맵 교체는 지도 SDK 문제로 로그인 provider와 무관. 타겟(한국 야구팬) 적합성·dogfood 현실성 우선.
- **카카오 = GoTrue 웹 OAuth** (native KakaoTalk SDK 아님). `signInWithOAuth` + 커스텀 스킴 콜백 `kboaway://login-callback`. 앱 코드 간단, infra는 `GOTRUE_EXTERNAL_KAKAO_*` env만.
- **범위 = full 수직** — GoTrue infra env(docker-compose/.env) + 앱 코드. Kakao 개발자콘솔 앱등록·키 발급은 @arden 수동.
- **이메일 확인 = autoconfirm** (SMTP 없음, v1 dogfood). 가입 즉시 세션.
- **auth 게이트 = go_router redirect + refreshListenable** (별도 스트림 구독, router provider 재빌드 안 함). `client.auth.currentSession` 동기 판정.
- **`.env`/`.env.example` = 툴 접근 차단(시크릿)** → compose 만 커밋, 실제 키/적용은 ops-kakao-setup.md 로 맥미니에서. → DECISIONS

### 블로커
- 없음 (Kakao 콘솔 앱등록 시 email scope/비즈앱 요건은 구현 중 확인)
