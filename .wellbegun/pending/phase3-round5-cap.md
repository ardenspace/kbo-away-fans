# Pending decision: Phase 3 round 5 REJECT 이후 어떻게 진행할까요?

## Situation
사용자가 허용한 마지막 추가 검증인 Phase 3 round 5도 Step 3.2 계약 위반을 찾았습니다.
실제 추천→구장 route에서 `CategoryChip`과 `TeamThemedAppBar`가 전역 응원팀 테마보다
목적지 `TeamThemeScope`를 우선해, 팀 없음 A/dark에서도 롯데색을 쓰고 살아 있는 route의
응원팀을 NC→삼성으로 바꿔도 롯데색이 남습니다. 새 verifier probe가 두 경로를 재현합니다.

## Options
1. 현재 Phase 3를 승인하고 결함을 Deferred에 남긴다 — reversal grade L, 일부 추천 route가 사용자의 선택 테마를 따르지 않는 채 남습니다.
2. 이 결함을 Phase 3의 새 Step 3.3으로 분리한다 — reversal grade M, 목적지 맥락과 전역 accent의 소유권을 별도 계약과 검증 라운드로 고정합니다.
3. Phase 3 통합에 추가 1회를 허용한다 — reversal grade M, Step 3.2의 두 공용 컴포넌트를 좁게 수정하고 새 verifier로 round 6 한 번만 진행합니다.

## Recommendation
옵션 2를 권합니다. 다섯 라운드 동안 서로 다른 화면 조합 seam이 계속 드러났고,
이번 문제는 두 공용 컴포넌트의 색 소유권을 명시적으로 고정할 작은 독립 계약이 적합합니다.

## How to answer
옵션 번호(또는 원하는 선택)를 답해주세요. 답은 decisions.md에 기록하고 이 파일을
삭제한 뒤, 선택한 방식으로 Phase 3에서 재개합니다.
