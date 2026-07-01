# Handoff: feat/task-011-stadium — @arden

## 2026-07-01

- [ ] task-011 구장 가이드 화면 (주차·좌석뷰·동선·편의점) (E8, T9)

### 진행
- 브랜치 feat/task-010-schedule 위에서 분기 (`/stadium/:id` 라우트 + on-demand 패턴 의존).
- 무게 = **light** (트리거 0: 계약변경X·설계분기X·교차의존X). PLAN 마커 없음과 일치.
- ✅ brief.md 작성 → DoD 사용자 승인.
- ✅ 구현: Stadium 모델 · stadiumProvider(id, autoDispose.family) · stadium_screen 실구현
  (헤더 city·address + 주차/좌석/동선/편의점 4섹션, null→"준비 중이에요", 로딩/에러+재시도/당겨서새로고침).
- ✅ 끝검증 코드 리뷰(diff 전체) — 결함 없음. analyze 0 / test 5 pass (회귀 없음).

### 다음
- DoD 5개 중 4개 코드검증 완료. 남은 1개 "일정 카드 탭→구장 이동"은 라우트·네비 코드 연결은 완성
  (schedule onTap→`/stadium/:id`→StadiumScreen), 실기기 탭 확인은 task-010 e2e 시뮬 게이트와 함께.
- 후속 task-012(맛집·플랜B)가 이 구장 화면에 섹션/탭으로 얹힘.

### 결정
- **구장 상세 = stadiums 4개 info 컬럼 직접 표시**(parking/seating/route/convenience). null 필드는
  숨기지 않고 "준비 중이에요" 플레이스홀더 — 유저가 정보 유무를 알게. → (light, DECISIONS 승격은 선택)

### 블로커
- task-010 e2e 환경 게이트 대기 중이나 task-011 코드는 그 위에 독립적으로 쌓임.
