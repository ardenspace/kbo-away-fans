// deploy.mjs 단위 테스트 — "검증 없이는 배포 없음" 경로와 gh-pages push 계약 검증.
//
// 원격은 임시 bare 저장소(DEPLOY_REMOTE=경로)로 대체해 네트워크 없이
// 실제 push 결과(브랜치 트리 내용)까지 확인한다.
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, readFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const deployScript = path.join(here, '..', 'deploy.mjs');
const dataDir = path.join(here, '..', 'data');
const ENTITIES = ['teams', 'stadiums', 'places', 'schedule'];

function makeBareRemote() {
  const dir = mkdtempSync(path.join(os.tmpdir(), 'deploy-remote-'));
  const init = spawnSync('git', ['init', '--bare', dir], { encoding: 'utf8' });
  assert.equal(init.status, 0, init.stderr);
  return dir;
}

function copyDataTo(dir) {
  for (const entity of ENTITIES) {
    cpSync(path.join(dataDir, `${entity}.json`), path.join(dir, `${entity}.json`));
  }
}

function runDeploy(env) {
  return spawnSync(process.execPath, [deployScript], {
    encoding: 'utf8',
    env: { ...process.env, ...env },
  });
}

function lsTree(remote) {
  const result = spawnSync(
    'git',
    ['--git-dir', remote, 'ls-tree', '--name-only', 'gh-pages'],
    { encoding: 'utf8' },
  );
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim().split('\n').sort();
}

test('정상 데이터: gh-pages 브랜치에 4종 JSON + .nojekyll 이 올라간다', () => {
  const remote = makeBareRemote();
  const result = runDeploy({ DEPLOY_REMOTE: remote });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stderr, /deploy_pushed/);

  assert.deepEqual(lsTree(remote), [
    '.nojekyll',
    ...ENTITIES.map((e) => `${e}.json`).sort(),
  ]);

  // push 된 내용이 원본과 byte 단위로 같은지 — teams.json 하나로 대표 확인.
  const shown = spawnSync('git', ['--git-dir', remote, 'show', 'gh-pages:teams.json'], {
    encoding: 'utf8',
  });
  assert.equal(shown.stdout, readFileSync(path.join(dataDir, 'teams.json'), 'utf8'));
});

test('같은 내용 재배포: 트리 동일 → push 생략(exit 0)', () => {
  const remote = makeBareRemote();
  assert.equal(runDeploy({ DEPLOY_REMOTE: remote }).status, 0);
  const second = runDeploy({ DEPLOY_REMOTE: remote });
  assert.equal(second.status, 0, second.stderr);
  assert.match(second.stderr, /deploy_skip/);
  assert.match(second.stderr, /tree_unchanged/);
});

test('깨진 산출물: 검증 실패 → 배포 없이 exit 1, 원격에 브랜치가 생기지 않는다', () => {
  const remote = makeBareRemote();
  const brokenDir = mkdtempSync(path.join(os.tmpdir(), 'deploy-broken-'));
  copyDataTo(brokenDir);
  // schedule.json 을 픽스처(필수 필드 누락)로 교체 — validate 가 반드시 잡아야 한다.
  cpSync(
    path.join(here, 'fixtures', 'schedule.missing-required.json'),
    path.join(brokenDir, 'schedule.json'),
  );

  const result = runDeploy({ DEPLOY_REMOTE: remote, DEPLOY_DATA_DIR: brokenDir });
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /validation_failed/);

  const branches = spawnSync('git', ['--git-dir', remote, 'branch', '--list'], {
    encoding: 'utf8',
  });
  assert.equal(branches.stdout.trim(), '', 'gh-pages 가 만들어지면 안 됨');
});
