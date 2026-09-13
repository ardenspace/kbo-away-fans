# Pending decision: Phase 3 round cap 이후 어떻게 진행할까요?

## Situation
Phase 3 통합 검증이 세 번째 라운드에서도 Step 3.2 계약 위반을 재현했습니다.
NC dark 홈에서 시즌 종료 제목의 팀 primary `#315288`이 dark backdrop `#11162B`
위에 놓여 대비가 2.2949:1입니다. 큰 텍스트 최소 기준 3:1에도 못 미치며,
두 색을 조합한 `DdayHeader`와 `WeatherBackdrop`은 모두 Phase 3 변경 범위입니다.
wellrun의 세 라운드 상한에 도달해 추가 수정 전에 사용자 선택이 필요합니다.

## Options
1. 현재 Phase 3를 승인하고 결함을 Deferred에 남긴다 — reversal grade L, NC dark 홈의 핵심 상태 제목이 읽기 어려운 채 남습니다.
2. 이 결함을 Phase 3의 새 Step 3.3으로 분리한다 — reversal grade M, 팀 accent와 동적 배경의 대비 역할을 별도 계약으로 고정합니다.
3. Phase 3 통합에 고정 2회 추가 라운드를 허용한다 — reversal grade M, Step 3.2 소유의 좁은 대비 fix 후 새 verifier로 round 4와 필요 시 round 5까지만 진행합니다.

## Recommendation
옵션 3을 권합니다. 실패 지점과 소유 파일이 좁고 기존 Step 3.2의 읽기 가능한 역할
조합 계약을 직접 깨므로, 제한된 추가 라운드 안에서 고치는 편이 가장 직접적입니다.

## How to answer
옵션 번호(또는 원하는 선택)를 답해주세요. 답은 decisions.md에 기록하고 이 파일을
삭제한 뒤, 선택한 방식으로 Phase 3에서 재개합니다.
