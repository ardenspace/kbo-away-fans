#!/usr/bin/env node
// 콘텐츠 JSON 계약 검증기 — content-pipeline/schema/*.schema.json 이 원본.
//
// 사용법 (저장소 루트 기준, 최초 1회 `npm ci --prefix content-pipeline` 필요):
//   node content-pipeline/common/validate.mjs               # data/ 의 4개 산출물 전부 검증
//   node content-pipeline/common/validate.mjs <file...>     # 지정 파일만 검증 (픽스처 포함)
//
// 파일이 어느 계약을 따르는지는 파일명 첫 세그먼트로 정한다:
//   teams*.json → teams.schema.json, schedule.unknown-status.json → schedule.schema.json …
// 종료 코드: 전부 통과 0, 하나라도 실패/오류 1.

import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import AjvModule from 'ajv/dist/2020.js';

const Ajv2020 = AjvModule.default ?? AjvModule;

const here = path.dirname(fileURLToPath(import.meta.url));
const schemaDir = path.join(here, '..', 'schema');
const dataDir = path.join(here, '..', 'data');

const ENTITIES = ['teams', 'stadiums', 'places', 'schedule'];
const SCHEMA_ID_BASE = 'https://schema.kbo-away-fans.dev';

function loadAjv() {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  for (const name of readdirSync(schemaDir).filter((f) => f.endsWith('.schema.json'))) {
    ajv.addSchema(JSON.parse(readFileSync(path.join(schemaDir, name), 'utf8')));
  }
  return ajv;
}

function entityOf(filePath) {
  const first = path.basename(filePath).split('.')[0];
  return ENTITIES.includes(first) ? first : null;
}

function main(argv) {
  const targets =
    argv.length > 0 ? argv : ENTITIES.map((e) => path.join(dataDir, `${e}.json`));

  const ajv = loadAjv();
  let failed = 0;

  for (const target of targets) {
    const entity = entityOf(target);
    if (entity === null) {
      console.error(
        `FAIL ${target}: 파일명이 어느 계약인지 알 수 없음 ` +
          `(${ENTITIES.join('|')} 로 시작해야 함)`,
      );
      failed += 1;
      continue;
    }

    let data;
    try {
      data = JSON.parse(readFileSync(target, 'utf8'));
    } catch (err) {
      console.error(`FAIL ${target}: 읽기/파싱 실패 — ${err.message}`);
      failed += 1;
      continue;
    }

    const validate = ajv.getSchema(`${SCHEMA_ID_BASE}/${entity}.schema.json`);
    if (validate === undefined) {
      console.error(`FAIL ${target}: 스키마 ${entity}.schema.json 을 찾을 수 없음`);
      failed += 1;
      continue;
    }

    if (validate(data)) {
      console.log(`OK   ${target} (${entity}.schema.json)`);
    } else {
      failed += 1;
      console.error(`FAIL ${target} (${entity}.schema.json)`);
      for (const e of validate.errors ?? []) {
        console.error(`  - ${e.instancePath || '(root)'} ${e.message}`);
      }
    }
  }

  if (failed > 0) {
    console.error(`\n${failed}개 파일 검증 실패`);
    return 1;
  }
  return 0;
}

process.exit(main(process.argv.slice(2)));
