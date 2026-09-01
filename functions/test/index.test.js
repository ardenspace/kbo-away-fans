// 배선 테스트 — callable 이 실제로 export 되고 오류가 규약대로 나가는지.
//
// 이 파일만 Firebase SDK 를 필요로 한다. 설치 없이 돌리는 경우(`npm --prefix functions
// test` 만 실행)에는 통째로 건너뛴다 — 판단이 있는 두 모듈은 의존성 없이 검증되므로
// 이 파일이 없어도 acceptance 는 그대로 서고, 여기서 재는 것은 "배선이 붙어 있다"뿐이다.
// 네트워크로 나가는 경로(카카오 호출·Admin SDK 서명)는 여기서 부르지 않는다.
import assert from 'node:assert/strict';
import test from 'node:test';

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
