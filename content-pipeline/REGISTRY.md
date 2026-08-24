# Content pipeline registry — `content-pipeline/`

> 규칙: 모든 크롤러·빌드 스크립트는 공통 레이어(`common/`)를 통과한다.
> 스크립트마다 fetch/검증/로그를 새로 만들지 않는다.
> 공통 레이어를 추가하면 **같은 커밋에서** 아래 표에 행을 추가한다.
> 전체 로스터(예정 목록)는 `.wellbegun/spec.md`의 Backend common layers 절 참조.

| name | purpose (one line) | location | use when |
|---|---|---|---|
<!-- 공통 레이어가 실제로 만들어질 때 행을 추가한다. 아직 구현된 레이어 없음. -->

## 폴더 구조
- `common/` — fetch·검증·로깅 등 모든 스크립트가 공유하는 레이어
- `schema/` — 콘텐츠 JSON 계약의 원본 (JSON Schema)
