# task-013 brief — 우천취소 → 플랜B 유도 흐름

> light · 브랜치 `feat/task-013-planb` · (E4, T3 표시측)

## 무엇

원정 일정에서 **경기가 취소/연기된 카드**에, 근처 실내 대안(플랜B)으로 바로 가는 유도 CTA를 붙인다.
크롤러(task-005/006)가 `games.status`를 `cancelled`/`postponed`로 갱신하면, 앱이 그 상태를 읽어
"경기 안 열림 → 플랜B" 흐름으로 사용자를 이끈다.

## 왜

E4 도메인 리스크: KBO 우천취소·연기 잦음. 취소를 확인한 사용자가 "그럼 뭐하지"로 이탈하지 않게
task-012가 깔아둔 `/places/:sid?tab=planb` 딥링크로 실내 놀거리를 즉시 제시한다.

## 어떻게 (구현 방향)

- `schedule_screen`의 `_GameCard`를 Card 안 Column으로 재구성:
  - 기존 `ListTile`(vs 상대팀 · 일시·구장 · 상태배지, onTap → `/stadium/:id`) 유지.
  - **status가 `cancelled` 또는 `postponed`일 때만** 하단에 강조 CTA 행 추가:
    - 문구: 취소 → "경기가 취소됐어요 · 근처 플랜B 보기", 연기 → "경기가 연기됐어요 · 근처 플랜B 보기"
    - errorContainer 톤(기존 취소 배지와 일관) + ☔/실내 아이콘 + 오른쪽 화살표.
    - 탭 → `context.go('/places/${game.stadiumId}?tab=planb')`.
  - 예정/경기중/종료 카드는 지금 그대로(변화 없음).
- 새 상태·모델·provider·라우트·패키지 **추가 없음**. 순수 표시측 조립.

## 결정 (light — 확정)

- **CTA 위치 = 취소/연기 카드 내부 인라인 행** (별도 배너/다이얼로그 아님). 이유: 어느 경기가 취소인지
  맥락과 붙어야 명확. 리스트 스캔 중 바로 눈에 띔.
- **트리거 = cancelled + postponed 둘 다.** status에 취소 사유(우천 등) 구분 필드 없음 → 둘 다 "경기 안 열림"으로 취급.

## DoD

- [ ] `cancelled` 경기 카드에 플랜B CTA가 뜬다.
- [ ] `postponed` 경기 카드에도 CTA가 뜨고 문구가 "연기"로 다르다.
- [ ] `scheduled`/`in_progress`/`finished` 카드에는 CTA가 **안** 뜬다.
- [ ] CTA 탭 → `/places/:stadiumId?tab=planb`(플랜B 탭 초기선택)로 이동.
- [ ] `flutter analyze` 0 이슈, 기존 테스트 회귀 없음. (런타임 e2e는 상위 게이트와 함께 — 이번 검증 범위 밖)
