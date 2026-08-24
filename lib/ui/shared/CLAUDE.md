# lib/ui/shared/ — 작업 전 필독 (read-first)

**이 폴더에서 무엇이든 하기 전에 `lib/ui/shared/REGISTRY.md` 로스터를 먼저 읽는다.**

- 두 군데 이상에서 렌더될 위젯은 만들기 전에 로스터부터 확인 — 이미 있으면 재사용한다.
- 새 공유 컴포넌트를 만들면 **같은 커밋에서** REGISTRY.md 표에 행을 추가한다
  (location 열에 저장소 기준 경로를 백틱으로: 예 `lib/ui/shared/place_card.dart`).
  `scripts/hooks/check-registry-sync.sh`가 pre-commit에서 폴더 ↔ 로스터 어긋남을 막는다.
- 색·간격·모서리·타이포·모션 값은 `lib/design/` 토큰만 사용한다
  (`scripts/hooks/check-hardcoded-values.sh`가 PostToolUse·pre-commit에서 검사).
