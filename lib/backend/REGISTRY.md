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
| `AuthService` | 인증 공통 — 세 제공자(구글·애플·카카오) 로그인·로그아웃·세션 상태를 한 타입 뒤로, 사용자 값은 uid·표시 이름뿐 (+ 화면이 보는 로그인 상태 하나 `authStateProvider`: 값은 세션 스트림에서만 오고, 세션을 아직 모르는 구간은 값 없음(로딩)으로 구분되며, 오류는 도메인 오류) | `lib/backend/auth.dart` | 로그인 게이트, 마이페이지, 계정이 필요한 모든 곳 |
| `FirebaseAuthService` | 위 계약의 구현 — Firebase Auth 위의 세 제공자 로그인(`firebase_auth`·`google_sign_in` import 는 여기까지). 설정 파일이 없으면 서지 않고 `firebase-unconfigured` 로 드러나게 실패한다 | `lib/backend/auth_firebase.dart` | 앱이 실제로 로그인할 때 — 화면은 이 타입을 부르지 않고 `authServiceProvider` 만 본다 |
| `KakaoAuthGateway` | 카카오의 두 걸음 — SDK 로그인(액세스 토큰)과 커스텀 토큰 교환(서울 리전 callable). 실 구현 `KakaoSdkAuthGateway` 에 `package:kakao_flutter_sdk_user`·`cloud_functions` import 가 모여 있고, 네이티브 앱 키 상수 `kKakaoNativeAppKey` 도 여기 산다. SDK 와 닿는 세 자리(앱 키·`KakaoSdk.init`·로그인 호출)는 `KakaoSdkAuthGateway.withSeams` 로 갈아 끼운다 — 시험이 "설정이 없는 실행"을 **스스로 만들 수 있게** 하는 자리다 | `lib/backend/auth_kakao.dart` | 카카오 로그인 — 화면은 이 타입을 모르고 `signIn(AuthProviderId.kakao)` 만 부른다 |
| `BackendAppCheck` | App Check 배선 — 백엔드가 이 앱의 빌드가 건 호출만 받게 한다(디버그 빌드는 디버그 토큰, 릴리스는 Play Integrity / DeviceCheck). 함수 쪽 강제는 `functions/index.js` 의 `enforceAppCheck: true` 와 짝이다 | `lib/backend/app_check.dart` | `main` 에서 1회 — 인증보다 먼저. 그 한 번이 실패한 실행에서는 카카오 로그인 경로(`_signInWithKakao`)가 교환 직전에 다시 켠다 (실패한 시도를 기억하지 않는다). **기다림에는 `kAppCheckActivationTimeout`(5초) 상한이 있고 넘어도 던지지 않는다** — 두 호출자 모두 사람이 보는 화면을 붙잡고 있어서, 끝나지 않는 활성화가 스플래시나 로그인 버튼 잠금을 영구히 만들지 않게 한다 |
| `UserDataStore` | 사용자 데이터 접근 — 사용자 문서·도장·좋아요 읽기/쓰기의 단일 경로 + 계약 필드만 싣는 업로드 payload 타입(`NewUserProfile`·`UserProfilePatch`·`StampWrite`·`LikeWrite`)과 칸 id 로스터(`kBoardCellIds`), 첫 문서의 닉네임 씨앗(`seedNickname` — 제공자 표시 이름이 없을 수 있다), `createProfile` 이 **실제로 만들었는지를 bool 로 돌려준다**(false = 이미 있어서 아무것도 하지 않았다 → 호출자가 수정 경로로 이어 간다), 그리고 **화면이 사용자 문서를 구독하는 유일한 자리 `userProfileProvider`**(문서가 없으면 값이 null = 온보딩 전) | `lib/backend/user_data.dart` | 배지·좋아요·프로필을 다루는 모든 곳 |
| `FirestoreUserDataStore` | 위 계약의 구현 — Cloud Firestore 위의 읽기/쓰기(`cloud_firestore` import 는 여기까지)와 계약 타입 ↔ SDK 타입 어댑터(`encodeBackendValues`/`decodeBackendValues`: `ServerTimestamp`→서버 시각 센티널, `Timestamp`→UTC `DateTime`). 첫 문서 만들기는 트랜잭션이라 **이미 있는 문서를 덮지 않고**(재로그인이 가입 시각·배지 판을 지우지 못한다) 만들지 않았다는 사실을 false 로 돌려준다. 설정 파일이 없으면 서지 않고 `firebase-unconfigured` 로 드러나게 실패한다 | `lib/backend/user_data_firestore.dart` | 앱이 실제로 사용자 문서를 읽고 쓸 때 — 화면은 이 타입을 부르지 않고 `userDataStoreProvider`·`userProfileProvider` 만 본다 |
| `BackendError` | 오류 봉투 — Firebase 예외를 네트워크/권한/알 수 없음 세 도메인 오류로 바꾸는 유일한 변환 경로(Future 는 `guardBackend`, 스트림은 `guardBackendStream`) | `lib/backend/errors.dart` | 백엔드 호출의 모든 실패 경로 |

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
  - 실패 코드 `unauthenticated`(카카오 토큰 무효 · **App Check 토큰 없음**) ·
    `permission-denied` · `unavailable`(카카오 미응답) · `invalid-argument` ·
    `internal` — 이 코드들은 `cloud_functions` 가 `FirebaseException` 으로
    돌려주고 `errors.dart` 의 공통 표가 세 도메인으로 옮긴다(2.3). 카카오 쪽에
    따로 둔 변환은 없다
  - **App Check 을 강제한다**(`enforceAppCheck: true`). 로그인 전에 불리는
    함수라 호출자 인증을 요구할 수 없어서, 유효한 App Check 토큰이 그 자리의
    유일한 방어다. 클라이언트 짝은 위 `BackendAppCheck` 이고 둘 중 하나만
    서면 아무것도 막지 못한다
  - 배포는 사람 몫이다 (`firebase deploy --only functions` — 순서와 확인
    방법은 `.wellbegun/run.md` 의 2.3 사람 몫 체크리스트)
- **데이터 계약 원본** — `docs/firestore-schema.md` (필드 뜻·경로·칸 id 체계)와
  `firestore.rules` (강제). 이 폴더의 타입은 그 계약을 앱 쪽으로 옮긴 것이므로
  **셋 중 하나를 고치면 셋을 함께 고친다.**

## 아직 구현이 없는 자리 (phase 2 이후)

`authServiceProvider` 의 기본값은 `FirebaseAuthService` 이고, 세 제공자가 모두
붙어 있다(2.2 구글·애플, 2.3 카카오). `userDataStoreProvider` 의 기본값도
2.4 부터 실제 구현(`FirestoreUserDataStore`)이다 — 도장 쓰기의 트랜잭션 갱신
(4.2)만 아직 이 계층 밖의 몫으로 남아 있다.

카카오 네이티브 앱 키(`kKakaoNativeAppKey`)는 **저장소에 그대로 두는 값**이다
(`.wellbegun/decisions.md` 의 [S] 줄: 감출지 말지를 "이 값이 바이너리에 실려
나가는가"로 가른다). 아직 카카오 앱을 등록하지 않아 값이 비어 있고, 그 실행에서
카카오 로그인은 `kakao-key-missing` 으로 드러나게 실패한다. 값을 채울 때는 세
자리를 함께 고친다 — Dart 상수, `android/app/src/main/AndroidManifest.xml` 의
리다이렉트 스킴, `ios/Runner/Info.plist` 의 `CFBundleURLTypes`.
`test/backend/kakao_app_key_sync_test.dart` 가 셋을 대조한다.

설정 파일(`google-services.json` / `GoogleService-Info.plist`)이 없는 실행에서는
인증 구현도 사용자 데이터 구현도 서지 못하고 둘 다 `firebase-unconfigured` 로
던진다. 그 실행에서 두 provider 는 오류 상태가 되고, 루트 게이트(2.1)는 인증
쪽 오류를 "로그인 화면 + 안내"로 받는다 — 조용히 로그아웃한 사람처럼
보이지 않는다. 인증에서 분석 래퍼 같은 조용한 no-op 을 쓰지 않는 까닭이 이것이다:
계정 없이 쓰는 경로가 없는 앱에서 "no-op 인증"은 설정 실수를 숨긴다.
테스트용 가짜 구현은
`test/backend/fake_backend.dart` 에 있다 — 그 fake 는 규칙의 `hasOnly` 대역
노릇도 하므로, 계약 밖 필드를 실은 쓰기는 에뮬레이터 없이도 테스트에서 막힌다.
