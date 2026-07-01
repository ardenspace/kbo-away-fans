# Handoff: feat/task-012-places — @arden

## 2026-07-01

- [ ] task-012 맛집·플랜B 화면 (pick_type 배지 + 상세 출처 링크) (E8, T9)

### 진행
- 브랜치 feat/task-011-stadium 위에서 분기 (구장 화면 진입점 + on-demand 패턴 의존).
- 무게 = **light** (읽기 전용, 계약변경 없음). 설계 결정 2개는 사용자 확정:
  - **배치 = 별도 라우트 `/places/:stadiumId` + 탭(맛집|플랜B)** (task-013 딥링크 위해). ↔ 구장화면 내 섹션 안 씀.
  - **출처 링크 = url_launcher 외부 브라우저** (패키지 추가 ✅ 6.3.2).
- ✅ brief.md 작성 → DoD 사용자 승인.
- ✅ 구현: Restaurant(+PickType enum)·PlanbPlace 모델 · restaurants/planbPlaces provider(autoDispose.family) ·
  places_screen(DefaultTabController, `?tab=planb` 초기선택) · router `/places/:stadiumId` · stadium_screen 진입 버튼.
  맛집 카드 pick_type 배지(선수 파랑/팬 초록/에디터 보라) + 출처 링크(launchUrl externalApplication).
- ✅ 끝검증 코드 리뷰(diff 전체) — 결함 없음. analyze 0 / test 5 pass (회귀 없음).

### 다음
- DoD 코드검증 완료. 런타임(탭 렌더·링크 열림·구장→places 이동)은 상위 e2e 시뮬 게이트와 함께.
- task-013 우천취소→플랜B 가 `/places/:sid?tab=planb` 딥링크로 이 화면 재사용.

### 결정
- **맛집·플랜B = 별도 라우트 `/places/:stadiumId`, 탭 2개.** 이유: task-013 우천취소→플랜B 딥링크를
  깔끔히(`?tab=planb`). 구장화면은 가이드에 집중. → DECISIONS 승격 후보 (task-013이 물려받음).
- **출처 노출 = source_url 외부 브라우저(url_launcher).** 원출처 신뢰·저작권 안전.

### 블로커
- 상위 task-010/011 e2e 환경 게이트 대기 중이나 task-012 코드는 독립적으로 쌓임.

## 2026-07-01 · e2e 검증

- ✅ **통과**: 구장 화면 "주변 맛집·플랜B" → `/places/:sid` 탭(맛집|플랜B) 렌더 → pick_type 배지·출처 링크 정상. `?tab=planb` 초기선택(task-013 딥링크) 동작.
