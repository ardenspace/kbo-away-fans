# Handoff: feat/task-009-login — @arden

## 2026-06-26

- [ ] task-009 (deep) 로그인: 이메일 + 카카오 OAuth (E2)

### 다음
- spec.md 승인 → plan.md 승인 → 구현

### 결정
- **provider = 이메일 + 카카오 유지** (E2 그대로). 카카오맵→네이버맵 교체는 지도 SDK 문제로 로그인 provider와 무관. 타겟(한국 야구팬) 적합성·dogfood 현실성 우선.
- **카카오 = GoTrue 웹 OAuth** (native KakaoTalk SDK 아님). `signInWithOAuth` + 커스텀 스킴 콜백 `kboaway://login-callback`. 앱 코드 간단, infra는 `GOTRUE_EXTERNAL_KAKAO_*` env만.
- **범위 = full 수직** — GoTrue infra env(docker-compose/.env) + 앱 코드. Kakao 개발자콘솔 앱등록·키 발급은 @arden 수동.

### 블로커
- 없음 (Kakao 콘솔 앱등록 시 email scope/비즈앱 요건은 구현 중 확인)
