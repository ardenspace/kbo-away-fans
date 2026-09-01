// 카카오 검증 → Firebase 커스텀 토큰 발급의 순서를 든 자리.
//
// 이 파일은 카카오도 Firebase 도 직접 알지 않는다. 카카오 호출은 `kakao.js` 가,
// 커스텀 토큰 발급은 주입받은 `createCustomToken` 이 한다 — 그래서 이 경로 전체가
// 가짜 카카오 응답과 가짜 Admin SDK 만으로 검증된다 (`test/custom-token.test.js`).
//
// 지켜야 할 순서는 하나다: **카카오 검증이 성공한 뒤에만 토큰을 만든다.**
// 실패 경로에서 발급이 일어나지 않는다는 것이 이 단계의 acceptance 다.

import { KakaoAuthError, fetchKakaoProfile } from './kakao.js';

/**
 * 카카오 계정의 uid 접두.
 *
 * Firebase Auth 가 스스로 만드는 uid 는 28자 난수라 이 접두와 겹치지 않고,
 * 구글·애플은 기본 제공자라 그 규칙을 따른다 — 그래서 접두 하나로 "이 계정은
 * 카카오에서 왔다"가 uid 만 보고도 읽히고 다른 제공자와 충돌하지 않는다.
 */
export const KAKAO_UID_PREFIX = 'kakao:';

/**
 * 카카오 사용자 id → Firebase uid. 같은 사람은 언제 로그인해도 같은 uid 다.
 *
 * @param {string|number} kakaoUserId
 * @returns {string}
 */
export function kakaoUid(kakaoUserId) {
  const id = typeof kakaoUserId === 'number' ? String(kakaoUserId) : kakaoUserId;
  if (typeof id !== 'string' || !/^[0-9]+$/.test(id)) {
    throw new KakaoAuthError('internal', `카카오 사용자 id 가 아닙니다: ${kakaoUserId}`);
  }
  return `${KAKAO_UID_PREFIX}${id}`;
}

/**
 * 카카오 액세스 토큰을 검증하고 그 사람의 Firebase 커스텀 토큰을 발급한다.
 *
 * 닉네임을 커스텀 클레임이 아니라 응답 payload 로 돌려주는 것은, 닉네임이 인증의
 * 사실이 아니라 사용자 문서의 씨앗값이기 때문이다 — 클레임에 실으면 ID 토큰마다
 * 따라다니면서도 사용자가 앱에서 닉네임을 바꾸면 곧바로 옛 값이 된다.
 *
 * @param {{
 *   accessToken: string,
 *   createCustomToken: (uid: string) => Promise<string>,
 *   fetchProfile?: (accessToken: string) => Promise<{ id: string, nickname: string|null }>,
 * }} args
 * @returns {Promise<{ customToken: string, uid: string, nickname: string|null }>}
 * @throws {KakaoAuthError}
 */
export async function issueKakaoCustomToken({
  accessToken,
  createCustomToken,
  fetchProfile = fetchKakaoProfile,
}) {
  if (typeof accessToken !== 'string' || accessToken.trim() === '') {
    throw new KakaoAuthError('invalid-argument', '카카오 액세스 토큰이 없습니다');
  }

  const profile = await fetchProfile(accessToken);
  const uid = kakaoUid(profile.id);

  let customToken;
  try {
    customToken = await createCustomToken(uid);
  } catch (cause) {
    throw new KakaoAuthError('internal', '커스텀 토큰을 발급하지 못했습니다', { cause });
  }

  return { customToken, uid, nickname: profile.nickname };
}
