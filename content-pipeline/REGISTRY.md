# Content pipeline registry — `content-pipeline/`

> 규칙: 모든 크롤러·빌드 스크립트는 공통 레이어(`common/`)를 통과한다.
> 스크립트마다 fetch/검증/로그를 새로 만들지 않는다.
> 공통 레이어를 추가하면 **같은 커밋에서** 아래 표에 행을 추가한다.
> 전체 로스터(예정 목록)는 `.wellbegun/spec.md`의 Backend common layers 절 참조.

| name | purpose (one line) | location | use when |
|---|---|---|---|
| 스키마 검증 | 산출 JSON이 계약(schemaVersion 포함)을 지키는지 빌드 시 검증 | `content-pipeline/common/validate.mjs` | 모든 JSON 산출 직전 |
<!-- 공통 레이어가 실제로 만들어질 때 행을 추가한다. -->

## 폴더 구조
- `common/` — fetch·검증·로깅 등 모든 스크립트가 공유하는 레이어
- `schema/` — 콘텐츠 JSON 계약의 원본 (JSON Schema, draft 2020-12)
  - `teams` / `stadiums` / `places` / `schedule` 4개 계약 + `common.defs`(팀 10·구장 9 안정 id 로스터)
  - 계약 변경은 마이그레이션급: 해당 스키마의 `schemaVersion` const를 올리고 앱 하위 호환 확인
- `data/` — 계약을 따르는 산출물/샘플 데이터 (검증 통과가 커밋 조건)
- `test/fixtures/` — 검증이 반드시 실패시켜야 하는 깨진 픽스처 (파일명 첫 세그먼트가 대상 계약)

## 검증 명령 사용법
최초 1회 의존성 설치(ajv):

```sh
npm ci --prefix content-pipeline
```

검증 (저장소 루트에서):

```sh
# data/ 의 4개 산출물 전부 — 전부 통과 시 exit 0
node content-pipeline/common/validate.mjs

# 지정 파일만 (실패 픽스처 재현 — exit 1)
node content-pipeline/common/validate.mjs content-pipeline/test/fixtures/schedule.missing-required.json
node content-pipeline/common/validate.mjs content-pipeline/test/fixtures/schedule.unknown-status.json
node content-pipeline/common/validate.mjs content-pipeline/test/fixtures/teams.schema-version-mismatch.json
node content-pipeline/common/validate.mjs content-pipeline/test/fixtures/places.missing-source.json
```

`npm --prefix content-pipeline run validate` 도 전체 검증과 동일하다.
