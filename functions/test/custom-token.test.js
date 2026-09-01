// 커스텀 토큰 발급 경로의 단위 테스트 — 가짜 카카오 응답과 가짜 Admin SDK 로 돈다.
// 실제 카카오 API·Firebase 프로젝트에 나가는 요청은 하나도 없다.
import assert from 'node:assert/strict';
import test from 'node:test';

import { KakaoAuthError } from '../kakao.js';
import { issueKakaoCustomToken, kakaoUid } from '../custom-token.js';

/** 가짜 Admin SDK — createCustomToken 호출을 세어 둔다. */
function fakeAuth() {
  const calls = [];
  return {
    calls,
    createCustomToken: async (uid, claims) => {
      calls.push({ uid, claims });
      return `custom-token-for-${uid}`;
    },
  };
}

/** 프로필 하나를 돌려주거나 오류를 던지는 가짜 카카오 계층. */
function fakeProfile(result) {
  const calls = [];
  const impl = async (accessToken) => {
    calls.push(accessToken);
    if (result instanceof Error) throw result;
    return result;
  };
  impl.calls = calls;
  return impl;
}

test('유효한 카카오 토큰이면 커스텀 토큰을 한 번 발급한다', async () => {
  const auth = fakeAuth();
  const fetchProfile = fakeProfile({ id: '8123456', nickname: '원정팬' });

  const result = await issueKakaoCustomToken({
    accessToken: 'valid-access-token',
    fetchProfile,
    createCustomToken: auth.createCustomToken,
  });

  assert.equal(auth.calls.length, 1);
  assert.deepEqual(result, {
    customToken: 'custom-token-for-kakao:8123456',
    uid: 'kakao:8123456',
    nickname: '원정팬',
  });
  assert.deepEqual(fetchProfile.calls, ['valid-access-token']);
});

test('발급하는 uid 는 카카오 사용자 id 에서 결정적으로 나온다', async () => {
  const auth = fakeAuth();
  const call = () =>
    issueKakaoCustomToken({
      accessToken: 'token',
      fetchProfile: fakeProfile({ id: '8123456', nickname: null }),
      createCustomToken: auth.createCustomToken,
    });

  const first = await call();
  const second = await call();

  assert.equal(first.uid, second.uid);
  assert.equal(first.uid, kakaoUid('8123456'));
  assert.equal(first.uid, 'kakao:8123456');

  // 다른 사람은 다른 uid — 같은 계정에 붙지 않는다.
  const other = await issueKakaoCustomToken({
    accessToken: 'token',
    fetchProfile: fakeProfile({ id: '999', nickname: null }),
    createCustomToken: auth.createCustomToken,
  });
  assert.notEqual(other.uid, first.uid);
});

test('uid 는 문자열 id 와 숫자 id 에 대해 같은 값이 나온다', () => {
  assert.equal(kakaoUid(8123456), kakaoUid('8123456'));
  assert.throws(() => kakaoUid(''), /카카오 사용자 id/);
  assert.throws(() => kakaoUid(null), /카카오 사용자 id/);
});

test('카카오 검증이 401 로 실패하면 토큰을 발급하지 않고 오류를 돌려준다', async () => {
  const auth = fakeAuth();
  const kakaoFailure = new KakaoAuthError('unauthenticated', '카카오 토큰이 유효하지 않습니다', {
    status: 401,
  });

  await assert.rejects(
    () =>
      issueKakaoCustomToken({
        accessToken: 'expired-token',
        fetchProfile: fakeProfile(kakaoFailure),
        createCustomToken: auth.createCustomToken,
      }),
    (err) => err instanceof KakaoAuthError && err.code === 'unauthenticated',
  );

  assert.equal(auth.calls.length, 0, '검증 실패인데 커스텀 토큰이 발급됐습니다');
});

test('카카오가 닿지 않으면 발급 없이 unavailable 로 끝난다', async () => {
  const auth = fakeAuth();

  await assert.rejects(
    () =>
      issueKakaoCustomToken({
        accessToken: 'token',
        fetchProfile: fakeProfile(new KakaoAuthError('unavailable', '카카오에 닿지 못했습니다')),
        createCustomToken: auth.createCustomToken,
      }),
    (err) => err.code === 'unavailable',
  );

  assert.equal(auth.calls.length, 0);
});

test('액세스 토큰이 없으면 카카오도 Admin SDK 도 호출하지 않는다', async () => {
  const auth = fakeAuth();
  const fetchProfile = fakeProfile({ id: '1', nickname: null });

  await assert.rejects(
    () =>
      issueKakaoCustomToken({
        accessToken: undefined,
        fetchProfile,
        createCustomToken: auth.createCustomToken,
      }),
    (err) => err instanceof KakaoAuthError && err.code === 'invalid-argument',
  );

  assert.equal(fetchProfile.calls.length, 0);
  assert.equal(auth.calls.length, 0);
});

test('Admin SDK 가 실패하면 internal 오류로 감싸 나온다', async () => {
  const cause = new Error('admin sdk down');

  await assert.rejects(
    () =>
      issueKakaoCustomToken({
        accessToken: 'token',
        fetchProfile: fakeProfile({ id: '1', nickname: null }),
        createCustomToken: async () => {
          throw cause;
        },
      }),
    (err) => err instanceof KakaoAuthError && err.code === 'internal' && err.cause === cause,
  );
});

test('커스텀 토큰에 추가 클레임을 싣지 않는다 (닉네임은 응답 payload 로만)', async () => {
  const auth = fakeAuth();

  await issueKakaoCustomToken({
    accessToken: 'token',
    fetchProfile: fakeProfile({ id: '1', nickname: '원정팬' }),
    createCustomToken: auth.createCustomToken,
  });

  assert.equal(auth.calls[0].claims, undefined);
});
