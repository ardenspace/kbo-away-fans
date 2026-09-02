// 배선 테스트 — callable 이 실제로 export 되고 오류가 규약대로 나가는지.
//
// 이 파일과 `app-check-enforcement.test.js` 가 Firebase SDK 를 필요로 한다
// (그쪽은 강제를 HTTP 로 재고, 여기서는 배선과 오류 규약을 잰다). 설치 없이 돌리는 경우(`npm --prefix functions
// test` 만 실행)에는 통째로 건너뛴다 — 판단이 있는 두 모듈은 의존성 없이 검증되므로
// 이 파일이 없어도 acceptance 는 그대로 서고, 여기서 재는 것은 "배선이 붙어 있다"뿐이다.
// 네트워크로 나가는 경로(카카오 호출·Admin SDK 서명)는 여기서 부르지 않는다.
import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const functionsDir = fileURLToPath(new URL('..', import.meta.url));

// 에뮬레이터 전용 접두 — 어떤 요청도 이 id 로 클라우드에 나가지 않는다.
process.env.GCLOUD_PROJECT ??= 'demo-kbo-away-fans';

let functions = null;
try {
  functions = await import('../index.js');
} catch (err) {
  if (err?.code !== 'ERR_MODULE_NOT_FOUND') throw err;
}

const skip = functions === null ? 'firebase SDK 미설치 (npm ci --prefix functions)' : false;

test('kakaoCustomToken callable 하나를 export 한다', { skip }, () => {
  assert.deepEqual(Object.keys(functions), ['kakaoCustomToken']);
  assert.equal(typeof functions.kakaoCustomToken.run, 'function');
});

test('액세스 토큰 없는 호출은 invalid-argument 로 거절된다', { skip }, async () => {
  await assert.rejects(
    () => functions.kakaoCustomToken.run({ data: {} }),
    (err) => {
      assert.equal(err.code, 'invalid-argument');
      assert.equal(err.httpErrorCode.status, 400);
      return true;
    },
  );
});

// App Check 강제는 SDK 없이도 재야 한다 — 이 파일의 나머지는 firebase-admin 이
// 없으면 통째로 skip 되는데, 강제가 꺼진 채 배포되는 것은 그 skip 뒤에 숨으면
// 안 되는 종류의 실수다. 켜져 있어야만 이 함수의 남용 방어가 성립하고
// (`lib/backend/app_check.dart` 참조), 꺼져도 테스트·배포는 멀쩡히 통과한다.
test('kakaoCustomToken 은 App Check 을 강제한다', () => {
  const source = readFileSync(join(functionsDir, 'index.js'), 'utf8');

  assert.match(
    source,
    /onCall\(\s*\{[^}]*enforceAppCheck:\s*true/,
    'onCall 옵션에 enforceAppCheck: true 가 없습니다 — 이 함수는 로그인 전에 불려서 '
      + '호출자 인증을 요구할 수 없고, App Check 이 그 자리의 유일한 방어입니다',
  );
});
