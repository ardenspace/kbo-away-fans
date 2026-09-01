// 카카오 API 를 호출하는 **유일한 자리**.
//
// 이 파일 밖에서는 카카오에 나가는 요청이 하나도 없다 — `test/kakao.test.js` 의
// 마지막 테스트가 `functions/*.js` 를 훑어 그것을 잰다. 호출이 한 자리에 모여 있어야
// 어떤 동의 항목을 요구하는지가 파일 하나를 읽는 것으로 확인되고, 나중에 항목이
// 늘어나면 그 변경이 이 파일의 diff 로 드러난다.
//
// 동의 항목: **닉네임뿐이다.** 이메일·전화번호 같은 추가 항목은 카카오 비즈니스
// 채널 등록을 요구하고, 앱이 그 값으로 하는 일이 하나도 없다 (계정을 가리키는 것은
// uid, 사람에게 보이는 것은 사용자 문서의 닉네임 — decisions.md 의 소셜 로그인 L 결정).
//
// 이 계층은 Firebase 도, 이 저장소의 다른 패키지도 import 하지 않는다. 의존성 없이
// 도는 순수 모듈이라 `npm --prefix functions test` 가 설치 없이 그대로 돌아간다.

/** 카카오 사용자 정보 엔드포인트 — 토큰 검증과 프로필 조회를 한 번에 한다. */
export const KAKAO_USER_ME_URL = 'https://kapi.kakao.com/v2/user/me';

/**
 * 응답에 실어 달라고 요구하는 항목의 전부.
 * 여기에 항목을 더하는 것은 사용자에게 동의를 더 받는 일이다 — 위 주석 참조.
 */
export const KAKAO_PROPERTY_KEYS = ['properties.nickname'];

/**
 * 사용자 문서(`users/{uid}.nickname`)의 길이 한도 — **UTF-16 코드 단위**로 20.
 *
 * 단위가 글자 수도 바이트도 아닌 것은 이 계약의 최종 판정자가 `firestore.rules` 의
 * `d.nickname.size()` 이고 그것이 UTF-16 코드 단위를 세기 때문이다 (규칙 언어에는
 * 이 단위를 다른 것으로 바꿀 방법이 없다). 함수·앱이 다른 단위로 세면 세 겹을
 * 통과한 값이 문서를 만드는 순간 규칙에서 거부된다 — decisions.md 의
 * "닉네임 길이의 기준 단위는 UTF-16 코드 단위" 결정.
 *
 * 한글·영문은 한 글자가 1단위라 사람이 세는 20자와 같고, 이모지는 대개 2단위라
 * 10개가 한도다.
 */
export const KAKAO_NICKNAME_MAX_UTF16_LENGTH = 20;

/** 카카오가 답하지 않을 때 기다리는 한도. 호출자(callable)의 시간 예산 안에 둔다. */
const DEFAULT_TIMEOUT_MS = 8000;

/**
 * 카카오 검증 경로의 실패 봉투 — `code` 는 그대로 callable 오류 코드가 된다.
 *
 * - `invalid-argument`  : 액세스 토큰이 비어 있다 (카카오를 호출하지도 않는다)
 * - `unauthenticated`   : 카카오가 401 — 토큰이 없거나 만료됐다
 * - `permission-denied` : 카카오가 403 — 앱 설정·동의 항목 문제
 * - `unavailable`       : 카카오에 닿지 못했거나 5xx
 * - `internal`          : 200 인데 우리가 아는 모양이 아니다
 */
export class KakaoAuthError extends Error {
  /**
   * @param {'invalid-argument'|'unauthenticated'|'permission-denied'|'unavailable'|'internal'} code
   * @param {string} message
   * @param {{ status?: number, kakaoCode?: number, cause?: unknown }} [details]
   */
  constructor(code, message, details = {}) {
    super(message, details.cause === undefined ? undefined : { cause: details.cause });
    this.name = 'KakaoAuthError';
    this.code = code;
    this.status = details.status ?? null;
    this.kakaoCode = details.kakaoCode ?? null;
  }
}

/**
 * 카카오 액세스 토큰을 검증하고 uid·닉네임을 돌려준다.
 *
 * 검증과 조회가 한 번의 호출인 것은 `/v2/user/me` 가 유효하지 않은 토큰에 401 로
 * 답하기 때문이다 — 토큰 정보 조회를 따로 부르면 호출 자리가 둘이 되고 왕복도 둘이 된다.
 *
 * @param {string} accessToken 앱이 카카오 SDK 로 받은 액세스 토큰
 * @param {{ fetch?: typeof globalThis.fetch, timeoutMs?: number }} [options] 테스트 주입점
 * @returns {Promise<{ id: string, nickname: string|null }>}
 * @throws {KakaoAuthError}
 */
export async function fetchKakaoProfile(accessToken, options = {}) {
  const { fetch: fetchImpl = globalThis.fetch, timeoutMs = DEFAULT_TIMEOUT_MS } = options;

  if (typeof accessToken !== 'string' || accessToken.trim() === '') {
    throw new KakaoAuthError('invalid-argument', '카카오 액세스 토큰이 없습니다');
  }

  const url = new URL(KAKAO_USER_ME_URL);
  url.searchParams.set('property_keys', JSON.stringify(KAKAO_PROPERTY_KEYS));

  let response;
  try {
    response = await fetchImpl(url.toString(), {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken.trim()}`,
        Accept: 'application/json',
      },
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (cause) {
    throw new KakaoAuthError('unavailable', '카카오에 닿지 못했습니다', { cause });
  }

  if (!response.ok) {
    throw errorForStatus(response.status, await readKakaoCode(response));
  }

  let body;
  try {
    body = await response.json();
  } catch (cause) {
    throw new KakaoAuthError('internal', '카카오 응답을 읽지 못했습니다', {
      status: response.status,
      cause,
    });
  }

  return { id: readId(body), nickname: readNickname(body) };
}

/** 카카오의 오류 코드는 진단용으로만 들고 간다 (없으면 null). */
async function readKakaoCode(response) {
  try {
    const body = await response.json();
    return typeof body?.code === 'number' ? body.code : null;
  } catch {
    return null;
  }
}

function errorForStatus(status, kakaoCode) {
  const details = { status, kakaoCode };
  if (status === 401) {
    return new KakaoAuthError('unauthenticated', '카카오 액세스 토큰이 유효하지 않습니다', details);
  }
  if (status === 403) {
    return new KakaoAuthError('permission-denied', '카카오가 이 요청을 거부했습니다', details);
  }
  if (status >= 500) {
    return new KakaoAuthError('unavailable', '카카오 서버가 응답하지 못했습니다', details);
  }
  return new KakaoAuthError('internal', `카카오가 예상 밖 상태로 답했습니다 (${status})`, details);
}

/**
 * 카카오 사용자 id 를 문자열로 꺼낸다.
 *
 * JSON 의 숫자를 그대로 쓰지 않고 문자열로 옮기는 것은 이 값이 uid 의 원본이기
 * 때문이다 — 숫자로 들고 다니면 자릿수가 늘었을 때 부동소수 표현으로 뭉개진 id 가
 * 조용히 다른 사람의 계정을 가리킬 수 있다. 안전 정수 범위를 벗어난 응답은 받지 않는다.
 */
function readId(body) {
  const raw = body?.id;
  if (typeof raw === 'number' && Number.isSafeInteger(raw) && raw > 0) {
    return String(raw);
  }
  if (typeof raw === 'string' && /^[0-9]+$/.test(raw)) {
    return raw;
  }
  throw new KakaoAuthError('internal', '카카오 응답에 사용자 id 가 없습니다');
}

/**
 * 닉네임은 동의 안 했으면 없을 수 있다 — 없으면 null 이고 로그인은 그대로 성립한다.
 *
 * 길이를 재는 단위는 규칙과 같은 UTF-16 코드 단위다
 * ([KAKAO_NICKNAME_MAX_UTF16_LENGTH] 참조). 자르고 나서도 null 이 될 수 있다 —
 * 결합용 문자만 남는 닉네임이 그렇고, 그때도 로그인은 그대로 성립한다.
 */
function readNickname(body) {
  const raw = body?.properties?.nickname;
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (trimmed === '') return null;
  const truncated = truncateToUtf16Length(trimmed, KAKAO_NICKNAME_MAX_UTF16_LENGTH);
  return truncated === '' ? null : truncated;
}

/**
 * UTF-16 코드 단위로 한도에 맞추되, 깨진 문자를 남기지 않는다.
 *
 * `String.prototype.slice` 를 쓰지 않는 것은 그것이 코드 단위 한가운데를 자를 수
 * 있기 때문이다 — 이모지처럼 두 단위를 차지하는 문자가 경계에 걸리면 짝 잃은
 * 서러게이트 반쪽이 남는다. 코드 포인트를 하나씩 얹으면서 길이를 재고, 한도를
 * 넘기는 코드 포인트는 통째로 버린다 (그래서 결과는 19단위가 될 수 있다).
 *
 * 끝에 남은 ZWJ(U+200D)를 떼는 것은 그것이 결합용 문자라서다: 가족 이모지처럼
 * ZWJ 로 이어 붙인 사슬이 경계에 걸리면 이어 줄 뒷짝 없이 ZWJ 만 매달리고,
 * `trim()` 은 이 문자를 공백으로 보지 않아 떼지 않는다.
 *
 * @param {string} value
 * @param {number} maxUtf16Length
 * @returns {string}
 */
function truncateToUtf16Length(value, maxUtf16Length) {
  let kept = value;

  if (kept.length > maxUtf16Length) {
    kept = '';
    for (const codePoint of value) {
      if (kept.length + codePoint.length > maxUtf16Length) break;
      kept += codePoint;
    }
  }

  while (kept.endsWith('\u200d')) {
    kept = kept.slice(0, -1);
  }

  // 자른 자리에 드러난 뒤쪽 공백까지 털어 낸다 (앞쪽은 호출자가 이미 털었다).
  return kept.trimEnd();
}
