# Handoff: feat/task-013-planb — @arden

## 2026-07-01

- [ ] task-013 우천취소 → 플랜B 유도 흐름 (E4)

### 진행
- 브랜치 feat/task-012-places 위에서 분기 (취소 경기 → `/places/:sid?tab=planb` 딥링크 재사용).
- 재료 확인: `awayGamesProvider`가 status 필터 없이 오늘 이후 경기 전부 반환 → 취소 경기도 리스트에 뜸(CTA 자리 확보).
- 무게 = **light** (읽기전용·계약변경X·설계분기X·교차의존X). `(deep)` 마커 불필요.
- ✅ brief.md 작성 → DoD 확인.
- ✅ 구현: `schedule_screen._GameCard`를 Card>Column으로 재구성(clipBehavior antiAlias),
  cancelled/postponed일 때만 하단 `_PlanbCta` 인라인 행(errorContainer·☔·화살표) → `/places/:sid?tab=planb`.
  예정/경기중/종료 카드는 변화 없음. 순수 표시측 조립(새 모델/provider/라우트/패키지 0).
- ✅ 끝검증: flutter analyze 0 · test 5 pass(회귀 없음) · 코드리뷰(diff 전체) 무결함.

### 다음
- DoD 코드검증 완료. 런타임(취소카드 CTA 렌더·플랜B 탭 이동)은 상위 task-009 e2e 게이트와 함께 확인.
- 그때까지 PLAN.md task-013 체크박스 미체크 유지(009~012와 동일 — 코드 됨, 런타임 검증 대기).

### 결정
- **CTA 위치 = 취소/연기 카드 내부 인라인 행.** 이유: 어느 경기가 취소인지 맥락과 붙어야 명확. 별도 배너/다이얼로그 안 씀.
- **트리거 = cancelled + postponed 둘 다.** status에 취소 사유(우천) 구분 필드 없음 → 둘 다 "경기 안 열림"으로 취급.

### 블로커
- 상위 task-009 로그인 e2e 게이트 대기 중이나 task-013 코드는 스택으로 독립 진행.

## 2026-07-01 · e2e 검증

- ✅ **통과**: 검증용으로 NC 미래 원정 2경기를 flip(7/4=cancelled·7/5=postponed, 7/3=scheduled 대조군) → 취소=CTA "취소"·연기=CTA "연기"·예정=CTA 없음 확인 → CTA 탭 시 `/places/:sid?tab=planb` 이동. **검증 후 3경기 모두 `scheduled`로 데이터 복구 완료**(크롤 실데이터 오염 없음).
