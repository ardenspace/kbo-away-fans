#!/usr/bin/env node
// 배포 스텝 — 검증 통과한 data/*.json 을 GitHub Pages(gh-pages 브랜치)로 올리는 단일 경로.
//
// 동작 계약:
//   1) common/validate.mjs 로 배포 대상 4종 전부를 검증 — 하나라도 실패하면 배포 없이 exit 1
//   2) git plumbing(hash-object → mktree → commit-tree)으로 4종 JSON + .nojekyll 만 담긴
//      고아 커밋을 만들어 gh-pages 브랜치에 force-push (배포 이력은 main 의 data/ 커밋이 원본)
//   3) 원격 gh-pages 의 트리와 동일하면 push 를 생략(idempotent) — CI 재실행이 헛배포를 안 만듦
//
// 사용법: node content-pipeline/deploy.mjs   (또는 npm --prefix content-pipeline run deploy)
//
// 환경 변수 (테스트·CI 주입점):
//   DEPLOY_REMOTE   push 대상 리모트 이름/URL/경로 (기본 origin)
//   DEPLOY_BRANCH   push 대상 브랜치 (기본 gh-pages)
//   DEPLOY_DATA_DIR 배포할 산출물 디렉터리 (기본 content-pipeline/data)
//
// 종료 코드: 0 배포 성공 또는 변경 없음 생략, 1 검증 실패, 2 git/push 실패.

import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createLogger } from './common/log.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');

/** 배포 대상 산출물 4종 — 계약 로스터(validate.mjs ENTITIES)와 같은 목록. */
export const DEPLOY_ENTITIES = ['teams', 'stadiums', 'places', 'schedule'];

/** git 명령 실행 — 실패 시 stderr 를 담아 던진다. */
function git(args, { input, env } = {}) {
  const result = spawnSync('git', args, {
    cwd: repoRoot,
    input,
    env: env ? { ...process.env, ...env } : process.env,
    encoding: 'utf8',
  });
  if (result.status !== 0) {
    throw new Error(`git ${args.join(' ')} 실패: ${(result.stderr ?? '').trim()}`);
  }
  return result.stdout.trim();
}

/**
 * 검증 통과한 산출물을 gh-pages 브랜치로 push 한다.
 * 검증은 호출 전에 끝났다고 가정한다 (main() 이 강제).
 *
 * @returns {{ pushed: boolean, tree: string, commit?: string }}
 */
export function deploy({
  remote = process.env.DEPLOY_REMOTE ?? 'origin',
  branch = process.env.DEPLOY_BRANCH ?? 'gh-pages',
  dataDir = process.env.DEPLOY_DATA_DIR ?? path.join(here, 'data'),
  log = createLogger('deploy'),
} = {}) {
  // 배포 트리: 4종 JSON + .nojekyll (Pages 의 Jekyll 빌드 생략 — 정적 파일 그대로 서빙)
  const entries = [];
  for (const entity of DEPLOY_ENTITIES) {
    const file = path.join(dataDir, `${entity}.json`);
    if (!existsSync(file)) {
      throw new Error(`배포 대상 없음: ${file}`);
    }
    const blob = git(['hash-object', '-w', file]);
    entries.push({ name: `${entity}.json`, blob });
  }
  entries.push({
    name: '.nojekyll',
    blob: git(['hash-object', '-w', '--stdin'], { input: '' }),
  });

  // git mktree 는 트리 순서(이름 ASCII 오름차순) 입력을 요구한다.
  entries.sort((a, b) => (a.name < b.name ? -1 : 1));
  const tree = git(['mktree'], {
    input: entries.map((e) => `100644 blob ${e.blob}\t${e.name}`).join('\n') + '\n',
  });

  // idempotence: 원격 브랜치의 트리와 같으면 push 생략.
  const fetched = spawnSync('git', ['fetch', '--depth=1', remote, branch], {
    cwd: repoRoot,
    encoding: 'utf8',
  });
  if (fetched.status === 0) {
    try {
      const remoteTree = git(['rev-parse', 'FETCH_HEAD^{tree}']);
      if (remoteTree === tree) {
        log.info('deploy_skip', { reason: 'tree_unchanged', tree });
        return { pushed: false, tree };
      }
    } catch {
      // 원격 트리 확인 실패 — 그냥 push 로 진행.
    }
  }

  const sourceCommit = git(['rev-parse', 'HEAD']);
  const commit = git(
    ['commit-tree', tree, '-m', `deploy: content from ${sourceCommit.slice(0, 7)}`],
    {
      // CI 등 git identity 미설정 환경에서도 커밋 생성이 되도록 명시 주입.
      env: {
        GIT_AUTHOR_NAME: 'kbo-away-fans deploy',
        GIT_AUTHOR_EMAIL: 'deploy@kbo-away-fans.local',
        GIT_COMMITTER_NAME: 'kbo-away-fans deploy',
        GIT_COMMITTER_EMAIL: 'deploy@kbo-away-fans.local',
      },
    },
  );
  git(['push', '--force', remote, `${commit}:refs/heads/${branch}`]);
  log.info('deploy_pushed', { remote, branch, commit, tree });
  return { pushed: true, tree, commit };
}

function main() {
  const log = createLogger('deploy');
  const dataDir = process.env.DEPLOY_DATA_DIR ?? path.join(here, 'data');
  log.info('deploy_start', { dataDir });

  // 검증 없이는 배포 없음 — 배포 대상 4종을 명시 나열해 검증한다.
  const validation = spawnSync(
    process.execPath,
    [
      path.join(here, 'common', 'validate.mjs'),
      ...DEPLOY_ENTITIES.map((e) => path.join(dataDir, `${e}.json`)),
    ],
    { stdio: 'inherit' },
  );
  if (validation.status !== 0) {
    log.error('deploy_abort', { reason: 'validation_failed', exitCode: validation.status });
    return 1;
  }

  try {
    deploy({ dataDir, log });
  } catch (err) {
    log.error('deploy_fail', { error: err.message });
    return 2;
  }
  return 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(main());
}
