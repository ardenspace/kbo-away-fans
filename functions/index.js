// Cloud Functions 진입점 — 카카오 커스텀 토큰 발급 함수 하나.
//
// 이 파일은 **배선만** 한다: Firebase SDK 를 붙이고, 요청에서 값을 꺼내고,
// `custom-token.js` 의 결과와 오류를 callable 규약으로 옮긴다. 판단은 전부
// 그 아래 두 모듈에 있고, 그래서 SDK 없이도 경로 전체가 테스트로 검증된다.
//
// 배포와 앱 연동은 step 2.3 의 몫이다 (`firebase deploy --only functions`).

import { setGlobalOptions } from 'firebase-functions/v2';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

import { issueKakaoCustomToken } from './custom-token.js';

initializeApp();

// 서울 리전 — 사용자와 카카오 API 가 모두 한국에 있다.
// maxInstances 는 요금 상한 장치다 (decisions.md 의 운영 비용 M 결정): 이 함수는
// 로그인할 때 한 번 불리므로 동시 10 인스턴스면 충분하고, 폭주가 곧 청구서가 되는
// 경로를 열어 두지 않는다.
setGlobalOptions({ region: 'asia-northeast3', maxInstances: 10 });

/**
 * 카카오 액세스 토큰 → Firebase 커스텀 토큰.
 *
 * 호출 규약 (앱 쪽 입구는 `lib/backend/auth.dart` 의 `signIn(AuthProviderId.kakao)`):
 *   요청: `{ accessToken: string }`
 *   응답: `{ customToken: string, uid: string, nickname: string|null }`
 *
 * 로그인 **전에** 불리는 함수라 호출자 인증을 요구하지 않는다 — 요구할 수 있는
 * 자격 증명이 바로 이 함수가 발급하려는 그것이다. 대신 이 함수가 하는 일은
 * "카카오가 인정한 사람에게만 토큰을 준다" 하나로 좁혀져 있다.
 *
 * 그 자리를 App Check 이 메운다(`enforceAppCheck: true`). 인증을 요구할 수 없다는
 * 것은 URL 만 알면 누구나 부를 수 있다는 뜻이고, 부르는 것 자체가 카카오 API 왕복과
 * 함수 실행 시간이라 남의 반복 호출이 그대로 요금이 된다. 유효한 App Check 토큰이
 * 없는 호출은 이 함수 몸이 돌기 전에 `unauthenticated` 로 거절되므로, 카카오로도
 * 나가지 않는다. 클라이언트 배선은 `lib/backend/app_check.dart` 이고, 둘 중 하나만
 * 서면 아무것도 막지 못한다 — 그래서 같은 단계에서 함께 선다.
 *
 * **강제는 배포 순서에 매인다.** 이 플래그를 켠 채로 배포하면, 콘솔에 증명 제공자가
 * 등록되지 않았거나 개발 기기의 디버그 토큰이 없는 빌드는 그 즉시 카카오 로그인이
 * 막힌다 (`.wellbegun/run.md` 의 2.3 사람 몫 체크리스트가 순서를 든다).
 */
export const kakaoCustomToken = onCall({ enforceAppCheck: true }, async (request) => {
  const accessToken = request.data?.accessToken;

  try {
    const result = await issueKakaoCustomToken({
      accessToken,
      createCustomToken: (uid) => getAuth().createCustomToken(uid),
    });
    logger.info('kakao_custom_token_issued', { uid: result.uid });
    return result;
  } catch (err) {
    // 발급 실패는 토큰 없이 오류로만 나간다. 사용자에게 보이는 것은 코드와 문구뿐이고,
    // 진단에 쓰는 원인(카카오 상태 코드 등)은 서버 로그에만 남는다.
    const code = KNOWN_CODES.has(err?.code) ? err.code : 'internal';
    logger.warn('kakao_custom_token_failed', {
      code,
      status: err?.status ?? null,
      kakaoCode: err?.kakaoCode ?? null,
      // `message` 가 아니라 `reason` 인 것은 firebase-functions 로거가 구조화 로그의
      // `message` 키를 이벤트 이름으로 이미 쓰고 있어 같은 이름을 실으면 덮이기 때문이다.
      reason: err?.message ?? String(err),
    });
    throw new HttpsError(code, err?.message ?? '카카오 로그인을 처리하지 못했습니다');
  }
});

/** `custom-token.js`·`kakao.js` 가 내는 코드 — 그대로 callable 오류 코드가 된다. */
const KNOWN_CODES = new Set([
  'invalid-argument',
  'unauthenticated',
  'permission-denied',
  'unavailable',
  'internal',
]);
