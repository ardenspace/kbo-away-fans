#!/usr/bin/env node
// 배포 스텝 스텁 — 검증 통과한 data/*.json 을 호스팅으로 올리는 단일 경로(예정).
//
// 호스팅 위치(GitHub Pages/CDN 등)는 spec 상 implementer discretion 이며 아직 미정.
// 이 스텁은 경로와 계약(검증 없이는 배포 없음)만 고정한다:
//   1) common/validate.mjs 로 data/ 전체를 검증하고, 실패하면 배포 불가로 종료
//   2) 검증을 통과해도 배포 대상이 미정이므로 명시적으로 실패(exit 2)한다
//      — CI cron 이 실수로 호출했을 때 조용히 성공한 척하지 않기 위함.
//
// 사용법: node content-pipeline/deploy.mjs

import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createLogger } from './common/log.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));

/** 배포 스텁 본체 — 아직 배포 대상이 없어 항상 던진다. */
export function deploy() {
  throw new Error(
    '배포 대상 미정: 콘텐츠 JSON 호스팅 위치가 결정되면 이 스텁을 구현으로 교체한다 ' +
      '(content-pipeline/REGISTRY.md 의 배포 스텝 행 참조)',
  );
}

function main() {
  const log = createLogger('deploy');
  log.info('deploy_start', {});

  const validation = spawnSync(
    process.execPath,
    [path.join(here, 'common', 'validate.mjs')],
    { stdio: 'inherit' },
  );
  if (validation.status !== 0) {
    log.error('deploy_abort', { reason: 'validation_failed', exitCode: validation.status });
    return 1;
  }

  try {
    deploy();
  } catch (err) {
    log.error('deploy_not_implemented', { error: err.message });
    return 2;
  }
  return 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  process.exit(main());
}
