# lib/backend/ — 작업 전 필독 (read-first)

**이 폴더에서 무엇이든 하기 전에 `lib/backend/REGISTRY.md` 로스터를 먼저 읽는다.**
(사용자 데이터를 건드린다면 `docs/firestore-schema.md` 도 함께 — 필드·경로·칸 id
체계의 원본이다.)

- 백엔드를 오가는 요소는 만들기 전에 로스터부터 확인 — 이미 있으면 재사용한다.
- 새 파일을 이 폴더에 만들면 **같은 커밋에서** REGISTRY.md 표에 행을 추가한다
  (location 열에 저장소 기준 경로를 백틱으로: 예 `lib/backend/auth.dart`).
  `scripts/hooks/check-registry-sync.sh` 는 아직 이 폴더를 지키지 않는다 —
  `lib/backend/` 짝을 더하는 일은 `.wellbegun/plan.md` step 1.9 에 배정되어
  있다. 그 전까지는 로스터와 폴더가 맞는지 손으로 확인한다.
- **SDK import 는 이 폴더 안에만.** `firebase_*`·`cloud_firestore`·카카오 SDK 를
  `lib/features/`·`lib/ui/` 에서 import 하지 않는다 (`lib/analytics/` 는 사이클 1의
  분석 래퍼라 예외). 화면은 이 계층의 타입만 소비한다.
- **SDK 예외를 밖으로 내보내지 않는다.** 백엔드 호출은 `guardBackend` 를 거쳐
  `BackendError` 세 도메인(네트워크·권한·알 수 없음)으로만 실패한다.
- **서버로 나가는 값은 write 타입의 `toData()` 결과뿐이다.** 규칙이 필드
  화이트리스트(`hasOnly`)라서 계약 밖 필드가 한 번이라도 낀 문서는 이후 쓰기가
  통째로 거부된다. 자유로운 map 을 만들어 올리지 말 것.
- **기기가 어디에 있었는지는 올리지 않는다.** 구장 근처 판정은 기기에서 하고
  결과(어느 구장·어느 경기)만 올린다 — 되돌리기 비용 XL 의 제품 결정이다.
  업로드 경로에 기기의 지점을 가리키는 필드를 더하지 않는다.
  이를 검사할 `scripts/hooks/check-no-location-upload.sh` 는 아직 없다 —
  `.wellbegun/plan.md` step 1.9 가 신설한다. 그 전까지는 손으로 확인한다.
- 문서 id 는 결정적으로 짓는다: 도장 `{stadiumId}_{gameId}`, 좋아요 `{placeId}`.
  id 를 만드는 코드는 write 타입 안에 둔다 — 호출자가 다른 조합을 지어낼 수 없게.
