# content-pipeline/ — 작업 전 필독 (read-first)

**이 폴더에서 무엇이든 하기 전에 `content-pipeline/REGISTRY.md` 로스터를 먼저 읽는다.**

- 모든 크롤러·빌드 스크립트는 공통 레이어(`common/`의 fetch·validate·log)를 통과한다.
  스크립트마다 fetch/검증/로그를 새로 만들지 않는다.
- 공통 레이어를 추가하면 **같은 커밋에서** REGISTRY.md 표에 행을 추가한다
  (location 열에 저장소 기준 경로를 백틱으로: 예 `content-pipeline/common/fetch.mjs`).
  `scripts/hooks/check-registry-sync.sh`가 pre-commit에서 폴더 ↔ 로스터 어긋남을 막는다.
- JSON 계약(`schema/`) 변경은 마이그레이션급: `schemaVersion`을 올리고 앱 하위 호환을 확인한다.
