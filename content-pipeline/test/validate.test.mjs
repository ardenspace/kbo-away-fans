// validate.mjs 단위 테스트 — CLI 계약(종료 코드) 검증.
// 1.2의 실패 픽스처(test/fixtures/)를 전부 실패 판정하는지,
// data/ 샘플 산출물을 전부 통과시키는지 실제 프로세스로 확인한다.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const pipelineRoot = path.join(here, '..');
const validator = path.join(pipelineRoot, 'common', 'validate.mjs');
const fixturesDir = path.join(here, 'fixtures');

function runValidate(args) {
  return spawnSync(process.execPath, [validator, ...args], { encoding: 'utf8' });
}

test('data/ 샘플 산출물 전체가 검증을 통과한다 (exit 0)', () => {
  const result = runValidate([]);
  assert.equal(result.status, 0, result.stderr);
});

test('실패 픽스처 각각이 검증에 실패한다 (exit 1)', () => {
  const fixtures = readdirSync(fixturesDir).filter((f) => f.endsWith('.json'));
  assert.ok(fixtures.length >= 4, '1.2의 실패 픽스처가 4개 이상 있어야 함');
  for (const fixture of fixtures) {
    const result = runValidate([path.join(fixturesDir, fixture)]);
    assert.equal(result.status, 1, `${fixture} 는 실패 판정이어야 함:\n${result.stderr}`);
    assert.match(result.stderr, /FAIL/, `${fixture} 실패 사유가 stderr 에 나와야 함`);
  }
});

test('계약을 알 수 없는 파일명은 실패한다 (exit 1)', () => {
  const result = runValidate([path.join(pipelineRoot, 'package.json')]);
  assert.equal(result.status, 1);
});
