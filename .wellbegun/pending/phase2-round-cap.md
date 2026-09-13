# Pending decision: Phase 2 round cap 이후 어떻게 진행할까요?

## Situation
Phase 2 통합 검증이 세 번째 라운드에서도 Step 2.2 계약 위반을 재현했습니다.
계정 A의 느린 밝음 저장 중 B로 전환했다가 A로 돌아와 어두움을 저장하면,
계정 전환 때 초기화된 설정 큐 때문에 오래된 밝음 쓰기가 나중에 최신 어두움 값을
덮을 수 있습니다. wellrun의 세 라운드 상한에 도달해 추가 수정 전에 사용자 선택이
필요합니다.

## Options
1. 현재 Phase 2를 승인하고 결함을 Deferred에 남긴다 — reversal grade L, 계정 재전환과 느린 쓰기가 겹치면 최신 테마 설정이 유실될 수 있습니다.
2. 이 결함을 Phase 2의 새 Step 2.3으로 분리한다 — reversal grade M, 별도 계약과 검증 기록으로 큐의 계정 전환 수명주기를 명시합니다.
3. Phase 2 통합에 고정 2회 추가 라운드를 허용한다 — reversal grade M, Step 2.2 소유 fix 후 새 verifier로 round 4와 필요 시 round 5까지만 진행합니다.

## Recommendation
옵션 3을 권합니다. 발견이 기존 Step 2.2 저장 계약을 직접 깨고 수정 소유권도
명확하므로, 범위를 새 기능으로 넓히지 않고 제한된 두 라운드 안에서 고치는 편이
가장 직접적입니다.

## How to answer
옵션 번호(또는 원하는 선택)를 답해주세요. 답은 decisions.md에 기록하고 이 파일을
삭제한 뒤, 선택한 방식으로 Phase 2에서 재개합니다.
