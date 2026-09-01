# Firestore 데이터 계약

사용자 데이터(계정·도장·좋아요)가 Cloud Firestore 에서 어떤 경로와 필드로 사는지
정하는 문서다. 콘텐츠(팀·구장·장소·일정)는 여기 없다 — 그쪽은 정적 JSON 파이프라인이
계속 담당하며 계약은 `content-pipeline/schema/` 에 있다.

- 강제 지점: `firestore.rules` (이 문서의 규약을 규칙으로 옮긴 것)
- 인덱스: `firestore.indexes.json`
- 규칙 단위 테스트: `firebase/test/rules.test.mjs` — `npm --prefix firebase test`
- 관련 결정: `.wellbegun/decisions.md` 2026-09-01 (데이터 소유권 XL, 도장 문서 id L,
  배지 판 읽기 패턴 L, 등급 임계 1/3/10)

이 문서와 `firestore.rules` 는 한 쌍이다. 한쪽만 고치면 안 된다 — 필드를 더하거나
지우는 변경은 두 파일과 규칙 테스트를 같은 커밋에서 함께 옮긴다.

## 원칙 셋

**1. 모든 사용자 데이터는 `users/{uid}` 아래에 산다.** 최상위 컬렉션은 `users` 하나뿐이고
도장·좋아요는 그 하위 컬렉션이다. 소유자가 경로에 박혀 있으므로 규칙이
`request.auth.uid == uid` 한 줄로 소유권을 판정하고, 문서 본문에 소유자 id 를 중복해
들 필요가 없다. 열거하지 않은 경로는 규칙이 없어 기본 거부다 — 미인증 요청과 남의
uid 접근은 어떤 allow 에도 걸리지 않는다.

**2. 기기가 어디에 있었는지는 서버에 올라가지 않는다.** 구장 근처 판정은 기기에서 하고
결과(어느 구장, 어느 경기)만 올린다. 이것은 되돌리기 비용 XL 의 제품 결정이라 필드
하나를 더하는 문제가 아니다. 규칙은 문서마다 가질 수 있는 키를 `hasOnly` 로 닫아
두므로, 이름을 무엇으로 바꾸든 계약에 없는 필드가 섞이면 쓰기가 통째로 거부된다.
`docs/firestore-schema.md` 와 `firestore.rules` 는 그런 뜻의 영문 표기가 하나도 없는지
grep 검사도 함께 받는다.

**3. 문서 id 는 가능한 한 결정적으로 짓는다.** 도장은 `{stadiumId}_{gameId}`, 좋아요는
`{placeId}` 다. 자동 생성 id 를 쓰지 않으므로 오프라인 재시도·중복 탭·여러 기기
동시 접속이 같은 문서로 수렴하고, 중복 방지를 위한 조회가 필요 없어 오프라인 쓰기가
그대로 멱등해진다.

## 값 공간 (로스터)

규칙과 이 문서가 쓰는 열거값은 전부 기존 로스터에서 온다. 새 값 공간을 만들지 않는다.

| 이름 | 값 | 원본 |
|---|---|---|
| `teamId` | `lg` `doosan` `kiwoom` `ssg` `kt` `kia` `samsung` `lotte` `nc` `hanwha` | `content-pipeline/schema/common.defs.schema.json` |
| `stadiumId` | `jamsil` `gocheok` `munhak` `suwon` `daejeon` `daegu` `sajik` `changwon` `gwangju` | 같은 곳 |
| `cellId` | `{stadiumId}_{homeTeamId}` 10가지 (아래 표) | 이 문서 |
| `tier` | `first` `regular` `master` | `lib/design/tokens.dart` 의 `BadgeTier` |
| `category` | `food` `cafe` `escape_room` `activity` `landmark` | `content-pipeline/schema/places.schema.json` |
| 날짜 표기 | `YYYY-MM-DD` (KST 달력 날짜) | `schedule.json` 계약의 `date` |

### 배지 판의 10칸

구장은 9곳인데 칸은 10개다 — 잠실만 두 홈팀으로 갈려 팀 테마 10개와 1:1 이 된다.
칸 id 는 `{stadiumId}_{homeTeamId}` 다.

`jamsil_lg` `jamsil_doosan` `gocheok_kiwoom` `munhak_ssg` `suwon_kt`
`daejeon_hanwha` `daegu_samsung` `sajik_lotte` `changwon_nc` `gwangju_kia`

이 짝 목록 밖의 조합(예: `gocheok_lg`)은 도장에서도 요약에서도 거부된다.

## 컬렉션

| entity | 경로 | 문서 id | 소유권 |
|---|---|---|---|
| 사용자 | `users/{uid}` | Firebase Auth uid | 본인만 읽고 쓴다 |
| 도장 | `users/{uid}/stamps/{stampId}` | `{stadiumId}_{gameId}` | 본인만 읽고 쓴다 |
| 좋아요 | `users/{uid}/likes/{likeId}` | `{placeId}` | 본인만 읽고 쓴다 |

### `users/{uid}` — 사용자

| 필드 | 타입 | 필수 | 뜻 |
|---|---|---|---|
| `nickname` | string (1~20자) | 예 | 표시 이름 |
| `favoriteTeamId` | `teamId` | 예 | 선택 팀. 이 문서가 원본이고 `shared_preferences` 는 첫 렌더용 캐시일 뿐이다 |
| `profileThemeKey` | `teamId` | 예 | 프로필 색의 팀 테마 키. 보통 `favoriteTeamId` 와 같지만 따로 둔 이유는 아래 참조 |
| `joinedAt` | timestamp | 예 | 가입 시각 |
| `updatedAt` | timestamp | 아니오 | 마지막 수정 시각 |
| `board` | map | 예 | 배지 판의 칸별 요약 (아래 절) |

`profileThemeKey` 를 `favoriteTeamId` 와 따로 둔 것은, 마이페이지의 프로필 색 변경이
"응원 팀을 갈아탄다"와 같은 뜻이 아니기 때문이다. 두 값을 한 필드로 합치면 색만 바꾸고
싶은 사람이 선택 팀까지 바꾸게 되고, 그 순간 홈의 경기 일정이 통째로 달라진다.

빈 문서는 없다 — 온보딩(팀 선택)을 마친 뒤 다섯 필수 필드를 갖춘 채 한 번에 만들어진다.

### `users/{uid}.board` — 칸별 요약

배지 판은 **사용자 문서 하나만 읽고** 그린다. 개별 도장 문서는 칸 상세를 열 때만 읽는다.
판을 열 때마다 도장을 전부 읽으면 읽기 수가 사용자 수 × 도장 수로 늘어 오래 쓴 사람일수록
비싸지기 때문이다.

`board` 는 **칸 id 를 키로 하는 map** 이다. 배열이 아니라 map 인 이유는 도장 쓰기가
`board.{cellId}` 한 자리만 갱신하면 되기 때문이다 — 배열이면 갱신에 전체를 읽어 다시
써야 하고 두 기기가 동시에 쓰면 서로를 덮는다.

| 키 | 값 |
|---|---|
| 칸 id (위 10가지 중 하나) | 아래 칸 요약 map |

칸 요약 map 의 필드:

| 필드 | 타입 | 필수 | 뜻 |
|---|---|---|---|
| `count` | int (1 이상) | 예 | 그 칸에 찍힌 도장 개수 |
| `tier` | `tier` | 예 | 현재 등급. `count` 로부터 파생된 값을 저장해 둔 것 |
| `lastStampedOn` | `YYYY-MM-DD` | 아니오 | 그 칸의 마지막 도장 날짜 |

**도장이 없는 칸은 `board` 에 아예 없다.** 빈 칸을 `count: 0` 으로 두지 않는 이유는
값 하나를 두 방식(키 없음 / 0)으로 표현하게 되어 읽는 쪽이 둘 다 처리해야 하기 때문이다.
그래서 `count` 는 항상 1 이상이고, 판을 그리는 쪽은 "키가 없으면 빈 칸" 한 규칙만 쓴다.

등급 사다리 (`count` → `tier`): 1개 이상 `first`, 3개 이상 `regular`, 10개 이상 `master`.

`tier` 를 `count` 에서 매번 계산하지 않고 저장하는 것은 중복 표현이다. 그래도 저장하는
이유는 판이 이 문서만 읽고 그려야 하는데, 임계값이 앱 코드에만 있으면 저장된 데이터를
보는 것만으로는 판의 상태를 알 수 없기 때문이다. 어긋남은 두 곳이 막는다 — 도장 쓰기가
둘을 같은 트랜잭션에서 함께 갱신하고, 규칙 테스트가 사다리를 단언한다.

### `users/{uid}/stamps/{stadiumId}_{gameId}` — 도장

**문서 id 는 `{stadiumId}_{gameId}` 한 형태뿐이다.** 규칙이
`stampId == data.stadiumId + '_' + data.gameId` 를 요구하므로, 자동 생성 id 나 다른
조합으로는 문서가 만들어지지 않는다. 같은 경기에 대한 두 번째 쓰기는 새 문서를 만들지
않고 같은 문서를 덮는다.

| 필드 | 타입 | 필수 | 뜻 |
|---|---|---|---|
| `stadiumId` | `stadiumId` | 예 | 도장을 받은 구장 |
| `gameId` | string (`^[A-Za-z0-9-]{1,64}$`) | 예 | 경기 id. `schedule.json` 의 경기 id 를 그대로 쓴다 |
| `homeTeamId` | `teamId` | 예 | 그날의 홈팀. 도장의 색과 칸을 정한다 |
| `gameDate` | `YYYY-MM-DD` | 예 | 경기 날짜 (KST) |
| `stampedAt` | timestamp | 예 | 도장이 찍힌 시각 |

`stadiumId + '_' + homeTeamId` 는 위 10칸 중 하나여야 한다. 이 문서가 채우는 칸이 곧
그 값이다.

홈·원정을 구분하는 필드는 없다. 배지는 "내가 그 구장에 갔는가"를 세기 때문이다 —
야구 용어의 원정으로 세면 내 팀 홈구장 칸이 구조적으로 영원히 빈칸이 된다.

### `users/{uid}/likes/{placeId}` — 좋아요

문서 id 는 `placeId` 다. 한 장소는 눌렸거나 안 눌렸거나 둘 중 하나이므로 문서가 곧
"눌렸다"는 사실이고, 취소는 문서 삭제다. 같은 장소를 두 번 눌러도 문서는 하나다.

| 필드 | 타입 | 필수 | 뜻 |
|---|---|---|---|
| `placeId` | string (`^[a-z][a-z0-9-]{0,63}$`) | 예 | `places.json` 의 장소 slug. 문서 id 와 같아야 한다 |
| `stadiumId` | `stadiumId` | 예 | 그 장소가 딸린 구장. 구장별 묶어 보기용 |
| `category` | `category` | 예 | 추천과 같은 카테고리 |
| `likedAt` | timestamp | 예 | 누른 시각 |

`stadiumId` 와 `category` 는 `places.json` 에서 다시 읽을 수 있는 값이지만 문서에 함께
둔다. 좋아요 목록은 구장·카테고리로 묶어 보여 주는데, 이 값이 없으면 목록을 그릴 때마다
장소 문서 전체를 대조해야 하고 장소가 콘텐츠에서 사라진 뒤에는 묶을 근거가 사라진다.

## 인덱스

Firestore 는 단일 필드 인덱스를 자동으로 만들고, 여러 필드를 함께 거는 질의만 복합
인덱스를 요구한다. `firestore.indexes.json` 에 둔 것은 셋이다.

| 컬렉션 | 필드 | 쓰는 화면 |
|---|---|---|
| `stamps` | `stadiumId` ↑, `homeTeamId` ↑, `gameDate` ↓ | 칸 상세 — 그 칸의 도장을 최신순으로 |
| `likes` | `category` ↑, `likedAt` ↓ | 좋아요 내역 — 카테고리 탭 안에서 최신순 |
| `likes` | `stadiumId` ↑, `likedAt` ↓ | 좋아요 내역 — 구장으로 묶어 최신순 |

`fieldOverrides` 로 자동 인덱스를 끈 필드도 셋이다. 자동 인덱스는 쓰기 비용에 얹히므로
질의에 쓰이지 않는 필드는 꺼 두는 편이 낫다.

| 컬렉션 | 필드 | 끄는 이유 |
|---|---|---|
| `users` | `board` | map 이라 하위 키마다 인덱스가 생기는데(칸이 늘면 그만큼 늘어난다) 이 필드로 질의하지 않는다 — 문서를 통째로 읽어 판을 그린다 |
| `stamps` | `stampedAt` | 정렬은 `gameDate` 로 한다. 도장을 찍은 시각은 표시용이라 질의에 안 쓴다 |
| `stamps` | `gameId` | 문서 id 에 이미 들어 있어 id 로 바로 찾는다 |

## 계약 밖의 것

- **다른 사람의 데이터를 읽는 경로가 없다.** 배지 자랑·공유는 이번 사이클의 non-goal 이라
  공개 읽기 규칙을 미리 열어 두지 않는다.
- **집계 문서·통계 문서가 없다.** 필요한 집계는 사용자 문서의 `board` 하나뿐이다.
- **로그인 기기 목록이 없다.** non-goal.
