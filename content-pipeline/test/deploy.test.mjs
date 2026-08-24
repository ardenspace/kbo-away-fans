// deploy.mjs(스텁) 단위 테스트 — "검증 없이는 배포 없음" 경로와 스텁 계약 검증.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { deploy } from '../deploy.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const deployScript = path.join(here, '..', 'deploy.mjs');

test('deploy() 스텁은 배포 대상 미정을 명시하며 던진다', () => {
  assert.throws(() => deploy(), /배포 대상 미정/);
});

test('CLI 는 검증을 먼저 통과시킨 뒤 스텁 단계에서 exit 2 로 끝난다', () => {
  const result = spawnSync(process.execPath, [deployScript], { encoding: 'utf8' });
  assert.equal(result.status, 2, result.stderr);
  assert.match(result.stderr, /deploy_not_implemented/);
});
