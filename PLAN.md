# KBO 원정러 — PLAN

상세 실행계획: [docs/EXECUTION-PLAN.md](docs/EXECUTION-PLAN.md) · 컨셉: [docs/CONCEPT.md](docs/CONCEPT.md)

## 역할

- `@arden` — 전체 (솔로 dogfood 프로젝트)

## 태스크

> `(E#)` = 실행계획 §5 lock-in 백링크 · `(deep)` = 무게 큰 task (pslog-workflow 무게 게이트) · 영향파일은 코드 생성 전이라 *방향 제안*.

### Lane A — 데이터 기반 (선행)

- [x] [task-001] (deep) 맥미니 Supabase 셀프호스팅(Docker) + Cloudflare Tunnel (E1) — @arden — `infra/supabase/`, `infra/cloudflared/`
- [x] [task-002] (deep) DB 스키마 + RLS + migration (teams/stadiums/games/restaurants/planb_places/profiles/stamps) (E1·E3·E10) — @arden — `supabase/migrations/`
- [x] [task-003] 시딩 도구: seed 스크립트 + 포맷 + 1구장 샘플 (E8) — @arden — `scripts/seed/`
- [x] [task-004] 10구장 콘텐츠 큐레이션·시딩 (가이드·맛집·플랜B, pick_type 태깅) (E8) — @arden — `scripts/seed/data/`
- [x] [task-005] (deep) 일정 크롤러 코어: 스크랩 + 파싱 + game_id upsert + dedup (E4) — @arden — `crawler/`
- [x] [task-006] 크롤러 운영: 2단 cron(경기일 1분) + 텔레그램 실패알림 + graceful (E4·E5) — @arden — `crawler/`

### Lane B — 앱 코어 (task-002 이후)

- [x] [task-007] (deep) Flutter 스캐폴드: init + Supabase 클라이언트 + 네비 골격 (E1·E9) — @arden — `app/lib/`
- [x] [task-008] 팀별 테마 컬러 전환 (E9, T11) — @arden — `app/lib/shared/theme/`
- [ ] [task-009] (deep) 로그인: 이메일 + 카카오 OAuth (E2) — @arden — `app/lib/auth/`
- [ ] [task-010] 응원팀 설정 → 원정 일정 화면 (필터 + on-demand 조회) (E2·E3·E4, T1) — @arden — `app/lib/features/schedule/`
- [ ] [task-011] 구장 가이드 화면 (주차·좌석뷰·동선·편의점) (E8, T9) — @arden — `app/lib/features/stadium/`
- [ ] [task-012] 맛집·플랜B 화면 (pick_type 배지 + 상세 출처 링크) (E8, T9) — @arden — `app/lib/features/places/`
- [ ] [task-013] 우천취소 → 플랜B 유도 흐름 (E4) — @arden — `app/lib/features/planb/`

### Lane C — 인터랙션·게임화 (task-007 이후)

- [ ] [task-014] (deep) GPS 스탬프 코어: 근접 발급 + 중복방지 + 클라우드 동기화 (E7·E3, T4~T6) — @arden — `app/lib/features/stamp/`
- [ ] [task-015] 스탬프 도장 애니메이션 (E9) — @arden — `app/lib/features/stamp/`
- [ ] [task-016] (deep) 네이버맵 연동 + 위치 표시 (E6) — @arden — `app/lib/features/map/`
- [ ] [task-017] 지도 경로 애니메이션 (방문 구장 잇기) (E6, T10) — @arden — `app/lib/features/map/`

## 병렬 가능

- 선행: task-001 → task-002 (다른 lane이 의존)
- task-002 이후: **lane A**(task-003·004 시딩 ∥ task-005·006 크롤러) ∥ **lane B**(task-007 → 008/009/010/011/012/013)
- task-007 이후: **lane C**(task-014·015 ∥ task-016·017)

## 다음

각 task 는 `pslog-workflow` 스킬로 코드화. deep task 는 brief 대신 spec→plan 게이트.
