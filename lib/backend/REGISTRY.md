# Backend common layers registry — `lib/backend/`

> 규칙 1: **Firebase·카카오 SDK import 는 이 폴더 안에만 둔다.** 화면과 상태
> 계층은 이 계층이 내보내는 타입만 소비한다 (사이클 1이 `StadiumMapView`·
> `analytics`·`weather` 에 세운 경계와 같은 규칙).
> 규칙 2: 백엔드를 오가는 요소가 필요하면 여기 먼저 — 로스터에 있으면 재사용하고,
> 없으면 이 폴더에 만들고 **같은 커밋에서** 아래 표에 행을 추가한다.
> 전체 로스터(예정 목록)는 `.wellbegun/spec.md` 의 Backend common layers 절 참조.
>
> 형식 규약: location 열에 저장소 기준 경로를 백틱으로 감싸 적는다
> (`scripts/hooks/check-registry-sync.sh` 가 이 폴더의 파일과 표의 경로를 대조).

| name | purpose (one line) | location | use when |
|---|---|---|---|
| `AuthService` | 인증 공통 — 세 제공자(구글·애플·카카오) 로그인·로그아웃·세션 상태를 한 타입 뒤로, 사용자 값은 uid·표시 이름뿐 | `lib/backend/auth.dart` | 로그인 게이트, 마이페이지, 계정이 필요한 모든 곳 |
| `UserDataStore` | 사용자 데이터 접근 — 사용자 문서·도장·좋아요 읽기/쓰기의 단일 경로 + 계약 필드만 싣는 업로드 payload 타입(`NewUserProfile`·`UserProfilePatch`·`StampWrite`·`LikeWrite`)과 칸 id 로스터(`kBoardCellIds`) | `lib/backend/user_data.dart` | 배지·좋아요·프로필을 다루는 모든 곳 |
| `BackendError` | 오류 봉투 — Firebase 예외를 네트워크/권한/알 수 없음 세 도메인 오류로 바꾸는 유일한 변환 경로(`guardBackend`) | `lib/backend/errors.dart` | 백엔드 호출의 모든 실패 경로 |

## 이 폴더 밖에 있는 짝

- **카카오 커스텀 토큰 함수** (`functions/`, step 1.7 에서 만듦) — 카카오 액세스
  토큰을 검증해 Firebase 커스텀 토큰을 발급한다. 앱 쪽 입구는 위 `AuthService` 의
  `signIn(AuthProviderId.kakao)` 하나다. 호출 규약은 서울 리전(`asia-northeast3`)의
  callable `kakaoCustomToken`:
  - 요청 `{ accessToken: string }` — 카카오 SDK 가 준 액세스 토큰
  - 응답 `{ customToken: string, uid: string, nickname: string|null }` —
    `uid` 는 `kakao:{카카오 사용자 id}` 로 결정적이고, `nickname` 은 사용자 문서
    (`users/{uid}.nickname`)의 씨앗값이라 그 길이 계약에 맞춰 이미 잘려 있다:
    **UTF-16 코드 단위로 1~20** (`firestore.rules` 의 `nickname.size()` 가 세는
    단위 — 한글 20자, 이모지 10개까지). 결합용 문자만 남는 값은 `null` 로 온다
  - 실패 코드 `unauthenticated`(카카오 토큰 무효) · `permission-denied` ·
    `unavailable`(카카오 미응답) · `invalid-argument` · `internal` —
    2.3 이 이것을 `BackendError` 세 도메인으로 옮긴다
  - 배포는 아직이다 (`firebase deploy --only functions` 는 step 2.3 의 몫)
- **데이터 계약 원본** — `docs/firestore-schema.md` (필드 뜻·경로·칸 id 체계)와
  `firestore.rules` (강제). 이 폴더의 타입은 그 계약을 앱 쪽으로 옮긴 것이므로
  **셋 중 하나를 고치면 셋을 함께 고친다.**

## 아직 구현이 없는 자리 (phase 2 이후)

`authServiceProvider` 와 `userDataStoreProvider` 는 기본 구현 없이 던진다.
Firebase 연결은 2.2(구글·애플)·2.3(카카오)·2.4(사용자 문서)가 붙이고, 그전까지
이 provider 를 읽는 코드는 override 로 주입받는다. 테스트용 가짜 구현은
`test/backend/fake_backend.dart` 에 있다 — 그 fake 는 규칙의 `hasOnly` 대역
노릇도 하므로, 계약 밖 필드를 실은 쓰기는 에뮬레이터 없이도 테스트에서 막힌다.
