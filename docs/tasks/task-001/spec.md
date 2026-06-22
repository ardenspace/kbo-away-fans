# task-001 spec — 맥미니 Supabase 셀프호스팅 + Cloudflare Tunnel 노출   확정일: 2026-06-22

> PLAN: [task-001] (deep) · 결정 백링크: E1 · 실행계획: [docs/EXECUTION-PLAN.md](../../EXECUTION-PLAN.md)

## 1. 배경 / 문제

E1으로 backend = **Supabase 직결 + 맥미니 셀프호스팅** 확정. 호스티드 무료티어는 7일 미사용 잠자기 + 한도 → 비용·가용성 우려. 맥미니 자원 활용이 목표.
이 task는 **모든 lane의 선행 차단점** — task-002(스키마)·task-005/006(크롤러)·task-007+(앱) 전부 이 backend endpoint + 키를 기다림. 지금은 backend가 0이라 아무 개발도 못 함.

**맥미니 실측 환경(2026-06-22):**
- 호스트 `Ardenui-Macmini.local`, macOS 26.5.1, Docker 구동 중
- 점유 포트: 8080(llama), 8000(app-chak), 8081(pslog-backend), 8200(auto-shorts-api), 5433(pslog-postgres). → **회피 필수**
- **cloudflared 설치됨** + Cloudflare zone 인증(cert.pem) + 기존 튠넬 `chak`(`chak-api.ardenspace.com → localhost:8000`), `chak-dev`(유휴)
- 80/443 리스너 없음(전용 리버스프록시 미설치). 빈 포트: 8300·8400·5434·54321

## 2. 목표 / 비목표

**목표 (DoD 완료 기준):**
- ☐ 맥미니에서 self-hosted Supabase 풀스택(Postgres·GoTrue·PostgREST·Storage·Realtime·Studio·Kong) 구동
- ☐ `https://kbo-api.ardenspace.com/rest/v1/` 가 외부(폰)에서 유효 응답 (Cloudflare Tunnel 경유)
- ☐ Auth 헬스 엔드포인트 동작
- ☐ Studio로 DB 보임 (**단 공개 노출 안 함** — 로컬/Access 한정)
- ☐ 모든 포트가 기존 점유(8000/8080/8081/8200/5433)와 비충돌
- ☐ `anon` / `service_role` 키 발급 + `.env`로 안전 보관(gitignore)
- ☐ 맥미니 재부팅 후 컨테이너·튠넬 자동 복구
- ☐ pg_dump 백업 스크립트 + cron

**비목표 (YAGNI):**
- 실제 스키마/테이블 (task-002), 시딩 (task-004), 카카오 OAuth provider 설정 (task-009)
- CI/CD, 모니터링 대시보드, HA/복제, 오프사이트 백업(클라우드 복사는 v2)

## 3. 설계(안)

```
[폰/외부] ──https──▶ Cloudflare edge ──tunnel──▶ [맥미니] cloudflared
                                                      │ ingress: kbo-api.ardenspace.com → localhost:8300
                                                      ▼
                                              Kong (API gateway) :8300
                                                 ├ /auth/v1   → GoTrue
                                                 ├ /rest/v1   → PostgREST
                                                 ├ /storage/v1→ Storage API
                                                 └ /realtime/v1→ Realtime
                                              Postgres :5434 (127.0.0.1 전용)  ← 크롤러/마이그레이션 직결
                                              Studio (127.0.0.1 전용)         ← 공개 X
```

- 베이스: 공식 `supabase/docker` compose 포크. Kong 포트 8000→**8300**, Postgres 5432→**127.0.0.1:5434**로 변경.
- 노출: **Cloudflare Tunnel**(cloudflared 기존 설치 재사용). 인바운드 포트 개방 0, TLS는 Cloudflare edge에서 종단. 기존 `chak` 패턴 그대로.
- 키: JWT_SECRET → ANON_KEY / SERVICE_ROLE_KEY 생성. `.env`(gitignore). E10 격리 준비 — 앱=anon, 크롤러=service_role.
- 디렉토리: `infra/supabase/`(compose+.env.example), `infra/cloudflared/`(ingress 추가분), `scripts/backup/`(pg_dump).

## 4. 대안 & 결정 ★

| # | 분기 | 대안 | **결정** | 이유 |
|---|---|---|---|---|
| D1 | Supabase 구성 | 공식 풀스택 vs 최소(PG+PostgREST+GoTrue) | **풀스택** | Storage(사진 E8)·Auth(E2)·Studio 다 씀. 나중에 도로 붙이는 비용↑ |
| D2 | 외부 노출 | 공유기 포트포워딩+DDNS vs Cloudflare Tunnel vs Tailscale | **Cloudflare Tunnel** | cloudflared·zone 이미 보유. 인바운드 0·자동 TLS·기존 `chak` 패턴 |
| D3 | 리버스프록시 | Caddy/nginx 별도 vs 튠넬 직결 | **튠넬→Kong 직결** | TLS는 edge 종단이라 별도 프록시 불필요. 구성 최소 |
| D4 | 튠넬 분리 | 기존 `chak` ingress에 추가 vs **신규 `kbo` 튠넬** | **신규 `kbo` 튠넬** | chak과 독립(장애 격리). 비용=cloudflared 인스턴스 1개 더 |
| D5 | Studio 노출 | 공개(basic-auth) vs **비공개(로컬/Access)** | **비공개** | 관리자 UI 공개 = 공격면. REST/auth/storage만 공개, Studio는 127.0.0.1 또는 Cloudflare Access |
| D6 | 크롤러 DB 접근 | PostgREST 경유 vs **Postgres 직결** | **Postgres 직결**(127.0.0.1:5434) | 대량 upsert는 직결이 견고. 같은 호스트라 로컬 |

## 5. 영향 / 리스크

- **계약(트리거①)**: 이 task가 backend URL·anon key·service_role key를 *처음 정의* — 하류 전부 의존. 키 회전 시 전파 필요.
- **보안**: service_role 키·DB 비번·Studio 강한 시크릿. Studio 공개 금지(D5). 공개면은 REST/auth/storage뿐.
- **가용성**: 맥미니 다운 = backend 다운. → restart 정책 + 재부팅 자동기동. 앱은 마지막 캐시 표시(E5와 결).
- **롤백**: `docker compose down`(볼륨 보존). 손상 시 볼륨 삭제 후 재생성 + pg_dump 복구.
- **포트**: 8300/5434 확정 전 재확인(다른 게 먼저 잡았을 수 있음).

## 6. 의존 / 사인오프

- **하류(트리거③)**: task-002(스키마 — 이 PG에 migration), task-005/006(크롤러 — service_role 직결), task-007+(앱 — anon key + URL). 전부 이 task 완료 대기.
- **사인오프**: @arden (솔로).

## 확정 (2026-06-22 승인)
- ✅ 서브도메인 = `kbo-api.ardenspace.com`
- ✅ 신규 `kbo` 튠넬 분리 (chak과 독립)
- ✅ Studio 접근 = 로컬(127.0.0.1)만
