// 배포될 **해결된 옵션**을 잰다 — 소스에 무엇이 적혀 있는가가 아니라.
//
// `backend_wiring_sync_test.dart` 는 `setGlobalOptions` 의 리전 문자열을 읽어
// Dart 상수와 맞춰 본다. 그 대조가 못 보는 자리가 하나 있다: **함수별 옵션이
// 전역을 덮어쓰는 경우**다. `onCall({ enforceAppCheck: true, region: 'us-central1' }, …)`
// 로 한 줄만 늘리면 `setGlobalOptions` 는 그대로 있으므로 그 시험은 초록불이고,
// `npm --prefix functions test` 도 초록불인데, 배포된 함수는 다른 리전에 서고
// 앱의 호출은 존재하지 않는 함수로 나가 `not-found` 로 죽는다. 증상은
// 실기기에서만 보인다.
//
// 그래서 여기서는 firebase-functions 가 **실제로 계산한** 배포 서술
// (`__endpoint`)을 읽는다. 그것이 배포되는 값이다.
//
// `maxInstances` 를 함께 재는 것은 그것이 이 함수의 **유일한 지출 브레이크**이기
// 때문이다(예산은 알림일 뿐 지출을 막지 않는다). 옵션 객체가 늘어나다 이 값이
// 전역에서 떨어져 나가면 상한이 사라지고, 그 사실은 청구서에서만 보인다.
import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

process.env.GCLOUD_PROJECT ??= 'demo-kbo-away-fans';

const repoRoot = fileURLToPath(new URL('../..', import.meta.url));

let functions = null;
try {
  functions = await import('../index.js');
} catch (err) {
  if (err?.code !== 'ERR_MODULE_NOT_FOUND') throw err;
}

const skip = functions === null ? 'firebase SDK 미설치 (npm ci --prefix functions)' : false;

/** Dart 쪽이 부르는 리전 — `lib/backend/auth_kakao.dart` 의 상수 그대로. */
function dartRegion() {
  const source = readFileSync(`${repoRoot}/lib/backend/auth_kakao.dart`, 'utf8');
  const match = /const String kKakaoFunctionRegion = '([^']*)'/.exec(source);
  assert.ok(match, 'lib/backend/auth_kakao.dart 에서 kKakaoFunctionRegion 을 읽지 못했다');
  return match[1];
}

test('해결된 리전이 앱이 부르는 리전과 같다 (함수별 옵션이 전역을 덮지 않았다)', { skip }, () => {
  const endpoint = functions.kakaoCustomToken.__endpoint;

  assert.deepEqual(
    endpoint.region,
    [dartRegion()],
    '배포될 리전이 앱의 kKakaoFunctionRegion 과 다르다 — 앱의 호출은 없는 함수로 나가 '
      + 'not-found 로 죽고, 그 증상은 실기기에서만 보인다',
  );
});

test('해결된 maxInstances 가 살아 있다 (유일한 지출 브레이크)', { skip }, () => {
  const endpoint = functions.kakaoCustomToken.__endpoint;

  assert.equal(
    endpoint.maxInstances,
    10,
    '동시 인스턴스 상한이 사라졌다 — 예산은 알림일 뿐 지출을 막지 않으므로, '
      + '이 함수에서 요금을 실제로 막는 것은 이 값과 App Check 둘뿐이다',
  );
});
