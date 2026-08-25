#!/usr/bin/env node
// 추천 장소 큐레이션 병합기 — curation/<stadiumId>.json 입력들을 모아
// 계약(schema/places.schema.json)을 따르는 data/places.json 을 산출한다.
//
// 워크플로(입력 → 검증 → 병합)와 장소 품질 규칙은 CURATION.md 참조.
// 구장 하나를 새로 채울 때는 curation/<stadiumId>.json 을 만들고 이 스크립트를
// 다시 돌리면 된다 — 나머지 8개 구장도 같은 반복이다.
//
// 계약(실패 시 기존 산출물 보호 — crawl-schedule.mjs 와 같은 패턴):
//   1) 입력별 정합 검사(파일명 ↔ stadiumId ↔ 각 장소의 stadiumId)를 통과한
//      병합본을 임시 파일(places.next.json)에 쓰고
//   2) common/validate.mjs (스키마 + place id 유일성 의미 검사)를 통과한
//      경우에만 기존 파일을 교체(rename)한다.
//   3) 어느 단계든 실패하면 exit 1 — 기존 data/places.json 무변경.
//   4) 구장별 커버리지(장소 수·카테고리 수·실내 수)를 로그로 남기고,
//      플랜B 성립 조건(장소 ≥ 10 · 카테고리 ≥ 3 · 실내 ≥ 3) 미달이면 warn.
//      (채우는 중인 구장이 있을 수 있어 실패로 치지는 않는다.)
//
// 사용법:
//   node content-pipeline/build-places.mjs              # curation/*.json → data/places.json
//   node content-pipeline/build-places.mjs --out p.json # 산출 경로 변경 (테스트)

import { readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createLogger } from './common/log.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const CURATION_DIR = path.join(here, 'curation');
const DEFAULT_OUT = path.join(here, 'data', 'places.json');
const VALIDATOR = path.join(here, 'common', 'validate.mjs');
const SCHEMA_VERSION = 1;

/** 플랜B 성립 조건 — CURATION.md 의 구장별 최소 커버리지. */
export const COVERAGE_THRESHOLD = Object.freeze({
  places: 10,
  categories: 3,
  indoor: 3,
});

/**
 * 큐레이션 입력 1개를 읽고 정합을 검사한다.
 * 형식: { stadiumId, places: [...] } — 파일명(<stadiumId>.json)과
 * 문서의 stadiumId, 각 장소의 stadiumId 가 전부 일치해야 한다
 * (복붙으로 다른 구장 장소가 섞이는 사고 방지).
 */
export function readCurationFile(filePath) {
  const expectedId = path.basename(filePath, '.json');
  const doc = JSON.parse(readFileSync(filePath, 'utf8'));
  if (doc.stadiumId !== expectedId) {
    throw new Error(
      `${filePath}: stadiumId "${doc.stadiumId}" 가 파일명("${expectedId}")과 다름`,
    );
  }
  if (!Array.isArray(doc.places)) {
    throw new Error(`${filePath}: places 배열이 없음`);
  }
  for (const place of doc.places) {
    if (place.stadiumId !== expectedId) {
      throw new Error(
        `${filePath}: 장소 "${place.id}" 의 stadiumId "${place.stadiumId}" 가 파일 구장("${expectedId}")과 다름`,
      );
    }
  }
  return doc.places;
}

/** 구장별 커버리지 요약 — 로그·플랜B 임계 판정용. */
export function coverageOf(places) {
  return {
    places: places.length,
    categories: new Set(places.map((p) => p.category)).size,
    indoor: places.filter((p) => p.indoor).length,
  };
}

function meetsThreshold(coverage) {
  return (
    coverage.places >= COVERAGE_THRESHOLD.places &&
    coverage.categories >= COVERAGE_THRESHOLD.categories &&
    coverage.indoor >= COVERAGE_THRESHOLD.indoor
  );
}

async function main(argv) {
  const log = createLogger('build-places');
  const outFlag = argv.indexOf('--out');
  const out = outFlag !== -1 ? path.resolve(argv[outFlag + 1] ?? '') : DEFAULT_OUT;

  try {
    const inputs = readdirSync(CURATION_DIR)
      .filter((f) => f.endsWith('.json'))
      .sort();
    if (inputs.length === 0) {
      log.error('build_fail', { reason: 'no_curation_inputs', dir: CURATION_DIR });
      return 1;
    }

    const places = [];
    for (const file of inputs) {
      const stadiumPlaces = readCurationFile(path.join(CURATION_DIR, file));
      const coverage = coverageOf(stadiumPlaces);
      const stadiumId = path.basename(file, '.json');
      log.info('stadium_coverage', { stadiumId, ...coverage });
      if (!meetsThreshold(coverage)) {
        log.warn('coverage_below_threshold', {
          stadiumId,
          ...coverage,
          threshold: COVERAGE_THRESHOLD,
        });
      }
      places.push(...stadiumPlaces);
    }

    const document = { schemaVersion: SCHEMA_VERSION, places };

    // 임시 파일에 쓰고 검증 통과 시에만 교체 — 실패 시 기존 산출물 무변경.
    // (파일명은 validate 의 계약 판별 규칙 때문에 places 로 시작해야 한다.)
    const tempPath = path.join(path.dirname(out), 'places.next.json');
    writeFileSync(tempPath, `${JSON.stringify(document, null, 2)}\n`);
    const validation = spawnSync(process.execPath, [VALIDATOR, tempPath], { stdio: 'inherit' });
    if (validation.status !== 0) {
      rmSync(tempPath, { force: true });
      log.error('build_fail', { reason: 'validation_failed', exitCode: validation.status });
      return 1;
    }
    renameSync(tempPath, out);
    log.info('build_success', { out, stadiums: inputs.length, places: places.length });
    return 0;
  } catch (err) {
    log.error('build_fail', { reason: 'read_or_merge_failed', error: String(err) });
    return 1;
  }
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(await main(process.argv.slice(2)));
}
