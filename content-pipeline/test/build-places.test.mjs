// build-places.mjs 단위 테스트 — 큐레이션 병합기의 CLI 계약(종료 코드)과
// 입력 정합 검사(파일명 ↔ stadiumId ↔ 장소 stadiumId)를 확인한다.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  COVERAGE_THRESHOLD,
  coverageOf,
  readCurationFile,
} from '../build-places.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const pipelineRoot = path.join(here, '..');
const builder = path.join(pipelineRoot, 'build-places.mjs');

function runBuild(args) {
  return spawnSync(process.execPath, [builder, ...args], { encoding: 'utf8' });
}

test('저장소의 curation/ 입력 전체가 병합·검증을 통과한다 (exit 0)', () => {
  const outDir = mkdtempSync(path.join(tmpdir(), 'build-places-'));
  const out = path.join(outDir, 'places.json');
  const result = runBuild(['--out', out]);
  assert.equal(result.status, 0, result.stderr);
  assert.ok(existsSync(out), '산출 파일이 있어야 함');

  const doc = JSON.parse(readFileSync(out, 'utf8'));
  assert.equal(doc.schemaVersion, 1);

  // 시범 구장(잠실)은 플랜B 성립 조건을 충족해야 한다.
  const jamsil = doc.places.filter((p) => p.stadiumId === 'jamsil');
  const coverage = coverageOf(jamsil);
  assert.ok(coverage.places >= COVERAGE_THRESHOLD.places, `장소 ${coverage.places}건`);
  assert.ok(coverage.categories >= COVERAGE_THRESHOLD.categories, `카테고리 ${coverage.categories}종`);
  assert.ok(coverage.indoor >= COVERAGE_THRESHOLD.indoor, `실내 ${coverage.indoor}건`);
});

test('readCurationFile: 파일명과 stadiumId 가 다르면 던진다', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'curation-'));
  const file = path.join(dir, 'jamsil.json');
  writeFileSync(file, JSON.stringify({ stadiumId: 'sajik', places: [] }));
  assert.throws(() => readCurationFile(file), /파일명/);
});

test('readCurationFile: 장소의 stadiumId 가 파일 구장과 다르면 던진다', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'curation-'));
  const file = path.join(dir, 'jamsil.json');
  writeFileSync(
    file,
    JSON.stringify({
      stadiumId: 'jamsil',
      places: [{ id: 'sajik-stray', stadiumId: 'sajik' }],
    }),
  );
  assert.throws(() => readCurationFile(file), /sajik-stray/);
});

test('coverageOf: 건수·카테고리 종수·실내 수를 센다', () => {
  const coverage = coverageOf([
    { category: 'food', indoor: true },
    { category: 'food', indoor: false },
    { category: 'cafe', indoor: true },
  ]);
  assert.deepEqual(coverage, { places: 3, categories: 2, indoor: 2 });
});
