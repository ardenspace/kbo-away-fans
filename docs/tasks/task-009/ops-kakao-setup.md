# task-009 ops — GoTrue 카카오 + 이메일 autoconfirm 적용 (맥미니)

> 코드/compose 는 커밋됨. 아래는 **시크릿(.env)·외부콘솔·컨테이너 재기동** 수동 단계.
> `infra/supabase/.env` 는 gitignore + 툴 접근 차단(시크릿) → 맥미니에서 직접 적용.

## 1. 카카오 개발자콘솔 (developers.kakao.com)

1. 애플리케이션 추가 → 앱 생성.
2. **REST API 키** = `KAKAO_CLIENT_ID`.
3. 보안 → **Client Secret** 생성·활성화 = `KAKAO_SECRET`.
4. 카카오 로그인 → **활성화 ON**.
5. **Redirect URI** 등록: `https://kbo-api.ardenspace.com/auth/v1/callback`
6. 동의항목 → 필요한 scope 설정.
   - ⚠️ **email**: 개인앱은 이메일 동의항목이 "비즈앱(사업자등록)" 심사를 요구할 수 있음.
     이메일을 못 받으면 GoTrue Kakao 가입이 실패할 수 있다(알려진 지점).
     막히면 비즈앱 전환 또는 이메일 optional 처리 검토 → handoff 블로커 기록.

## 2. `infra/supabase/.env` (맥미니) 키 추가/수정

```ini
# 이메일: SMTP 없이 가입 즉시 세션 (v1 dogfood)
ENABLE_EMAIL_AUTOCONFIRM=true

# 카카오 웹 OAuth 콜백 → 앱 커스텀 스킴 복귀 허용
ADDITIONAL_REDIRECT_URLS=kboaway://login-callback

# 카카오 (compose 가 ${KAKAO_*} 참조)
KAKAO_ENABLED=true
KAKAO_CLIENT_ID=<REST API 키>
KAKAO_SECRET=<Client Secret>
```

`.env.example` 에도 동일 키를 placeholder 로 추가해 둘 것(추적 파일, 다음 셋업 참고용).

## 3. 적용 (맥미니 infra/supabase/)

```bash
docker compose up -d auth      # auth(gotrue) 컨테이너만 재생성
# 또는: docker compose restart auth   # env 변경은 up -d 권장(재생성)
```

## 4. 검증

```bash
curl -s https://kbo-api.ardenspace.com/auth/v1/settings | jq '{external, mailer_autoconfirm}'
# 기대: external.kakao == true, mailer_autoconfirm == true
```

이후 앱에서 [카카오로 시작] → 브라우저 로그인 → `kboaway://login-callback` 복귀 → 세션.
