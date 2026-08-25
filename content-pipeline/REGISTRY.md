# Content pipeline registry — `content-pipeline/`

> 규칙: 모든 크롤러·빌드 스크립트는 공통 레이어(`common/`)를 통과한다.
> 스크립트마다 fetch/검증/로그를 새로 만들지 않는다.
> 공통 레이어를 추가하면 **같은 커밋에서** 아래 표에 행을 추가한다.
> 전체 로스터(예정 목록)는 `.wellbegun/spec.md`의 Backend common layers 절 참조.

| name | purpose (one line) | location | use when |
|---|---|---|---|
| Fetch 공통 | HTTP 요청·재시도(기본 3회, 지수 백오프)·타임아웃(10s)·User-Agent 한곳 | `content-pipeline/common/fetch.mjs` | 모든 외부 요청 |
| 스키마 검증 | 산출 JSON이 계약(schemaVersion 포함)을 지키는지 + 스키마로 못 잡는 의미 검사(schedule game id 중복) | `content-pipeline/common/validate.mjs` | 모든 JSON 산출 직전 |
| 로깅 | 크롤 성공/실패 구조화 로그 (JSON Lines → stderr) | `content-pipeline/common/log.mjs` | 모든 스크립트 (console.* 대신) |
| 배포 스텝 (스텁) | 검증 통과한 JSON을 호스팅으로 올리는 단일 경로 — 호스팅 미정이라 검증 후 exit 2 | `content-pipeline/deploy.mjs` | 모든 콘텐츠 갱신 (구현은 호스팅 결정 후) |
| 일정 크롤러 | 네이버 스포츠 API에서 KBO 일정·상태를 긁어 schedule.json 산출 — validate 통과 시에만 기존 파일 교체 | `content-pipeline/crawl-schedule.mjs` | CI cron(`.github/workflows/crawl-schedule.yml`)·수동 일정 갱신 |
| 장소 병합기 | `curation/*.json` 큐레이션 입력을 병합·검증해 places.json 산출 — validate 통과 시에만 기존 파일 교체, 구장별 커버리지 로그 | `content-pipeline/build-places.mjs` | 장소 큐레이션 갱신 (워크플로는 `CURATION.md`) |
<!-- 공통 레이어가 실제로 만들어질 때 행을 추가한다. -->

## 폴더 구조
- `common/` — fetch·검증·로깅 등 모든 스크립트가 공유하는 레이어
- `deploy.mjs` — 배포 스텝의 단일 진입점 (현재 스텁)
- `crawl-schedule.mjs` — KBO 일정 크롤러 (네이버 스포츠 API → `data/schedule.json`)
- `build-places.mjs` — 장소 큐레이션 병합기 (`curation/*.json` → `data/places.json`)
- `curation/` — 구장별 장소 큐레이션 입력 (`<stadiumId>.json`; 워크플로·품질 규칙은 `CURATION.md`)
- `test/` — 공통 레이어 단위 테스트 (`node:test`, `*.test.mjs`)
- `schema/` — 콘텐츠 JSON 계약의 원본 (JSON Schema, draft 2020-12)
  - `teams` / `stadiums` / `places` / `schedule` 4개 계약 + `common.defs`(팀 10·구장 9 안정 id 로스터)
  - 계약 변경은 마이그레이션급: 해당 스키마의 `schemaVersion` const를 올리고 앱 하위 호환 확인
- `data/` — 계약을 따르는 산출물/샘플 데이터 (검증 통과가 커밋 조건)
- `test/fixtures/` — 검증이 반드시 실패시켜야 하는 깨진 픽스처 (파일명 첫 세그먼트가 대상 계약)
  - `test/fixtures/crawl/` — 크롤러 테스트용 저장 응답 픽스처 (실 네이버 응답 기반; validate 실패 픽스처 규약의 예외)

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

## 단위 테스트 실행 명령
공통 레이어(fetch 재시도·타임아웃, 로그 포맷, validate 픽스처 실패 판정, deploy 스텁) 전체:

```sh
npm --prefix content-pipeline test
```

(내부적으로 `content-pipeline/` 에서 `node --test` 를 실행해 `test/*.test.mjs` 를 전부 돌린다. 의존성 설치는 위의 `npm ci --prefix content-pipeline` 1회면 충분 — 테스트 러너는 Node 내장 `node:test`.)
