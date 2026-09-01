# 핸드오프 — 사이클 2, wellplan 직전

작성: 2026-09-01 / 다음 할 일: **wellplan**

## 지금 어디까지 왔나

사이클 2(계정·배지·개인화)의 파이프라인을 wellnext → wellbegin → wellspec 까지
마쳤습니다. 다음 렌즈인 wellplan 은 아직 시작하지 않았습니다.

| 산출물 | 상태 |
|---|---|
| `.wellbegun/audit.md` | 사이클 2 개시 전 감사 완료 |
| `.wellbegun/begin.md` | `status: approved` |
| `.wellbegun/spec.md` | `status: approved` |
| `.wellbegun/plan.md` | **없음 — 여기부터 시작** |
| `.wellbegun/cycles/01/` | 사이클 1 아카이브 (불변) |

## 다음 세션에서 이렇게 시작하십시오

```
kbo-away-fans 사이클 2 를 이어서 진행한다. .wellbegun/HANDOFF.md 를 읽고
wellplan 으로 넘어가자.
```

wellplan 은 `spec.md` 가 `status: approved` 인 것을 확인하고 `plan.md` 를 초안으로
만든 뒤 단계를 분해합니다. 델타 모드이므로 phase 1 은 **확장 로스터가 더하는 것만**
실물로 만듭니다. 기존에 살아 있는 기반을 다시 쓰는 것은 계획 단계가 아니라 spec 의
결정 사항이므로, 그런 요구가 나오면 wellspec 으로 되돌아가야 합니다.

## 반드시 먼저 읽을 것

1. `.wellbegun/begin.md` — 현재 정체성의 **답안지**. 사이클 1 아카이브가 아니라
   이 파일이 현재 답입니다.
2. `.wellbegun/spec.md` — 해결된 결정 8건, 레지스트리 확장분, 강제 장치 계획.
3. `.wellbegun/decisions.md` — L/XL 색인과 사이클 2 원장. 뒤집힌 결정은 supersede
   형식으로 기록되어 있습니다.
4. `.wellbegun/audit.md` — 승격 후보 3건이 전부 승격되어 spec 로스터에 들어갔습니다.

## 오해하기 쉬운 지점

**사이클 1 문서는 정반대를 말합니다.** `cycles/01/begin.md` 에는 "계정 없이 시작",
"서버에 개인 데이터를 두지 않는다"가 그대로 남아 있고 `decisions.md` 초반에는
"백엔드 API 서버 기각"이 있습니다. 전부 사이클 2 에서 뒤집혔습니다. 아카이브는
이력이라 수정하지 않습니다.

**"원정"의 뜻이 두 갈래입니다.** 홈 화면의 D-day 와 추천은 야구 용어의 원정(내 팀이
어웨이인 경기) 기준을 유지합니다. 반면 **배지는 홈·원정을 구분하지 않고** "내가 그
구장에 갔는가"를 셉니다. 이 둘을 섞으면 판이 깨집니다.

## 다음 렌즈가 알아야 할 제약

- **비용**: Cloud Functions 때문에 Firebase Blaze 전환이 필요하고 카드 등록은
  피할 수 없습니다. 무료 할당량(일 5만 읽기·2만 쓰기)은 그대로 포함되므로,
  **Firestore 읽기 패턴을 그 안에 머물게 하는 것이 설계 조건**입니다. 배지 판처럼
  자주 여는 화면은 오프라인 캐시를 우선 읽습니다.
- **애플 로그인**: Apple Developer Program(연 $99)이 필요할 가능성이 높습니다.
  착수 전에 무료 계정으로 Sign in with Apple capability 설정이 가능한지 실제로
  확인해야 합니다.
- **기존 테스트 154개**: 앱 전체가 로그인 필수가 되면 `RootGate` 를 지나는 위젯
  테스트들이 로그인 상태를 주입해야 합니다. 계획에 이 비용을 반영하십시오.

## wellplan 이 다룰 phase 1 후보 (참고, 확정 아님)

spec 의 확장 로스터를 실물로 만드는 단계들입니다.

- `schedule.json` 계약 schemaVersion 2 (점수·승패 필드 + 과거 경기) + 크롤 창 확장
- Firestore 컬렉션 3종과 보안 규칙
- 디자인 토큰 확장 (`text.*`, `badge.*`, `badgeTier.*`, `motion.stamp`)
- 타이포 조합 스타일 기존 38곳 일괄 교체 (13개 파일)
- 백엔드 공통 계층 `lib/backend/` + REGISTRY.md + CLAUDE.md
- 카카오 커스텀 토큰 Cloud Function
- 공유 컴포넌트 7개 스켈레톤
- 강제 장치 3종 (registry-sync 짝 추가, no-location-upload 신설,
  firebase-import-boundary 신설)

## 현재 기준선 (사이클 2 착수 시점, 전부 통과)

- `flutter analyze` — 지적 사항 없음
- `flutter test` — 154개 통과, 1개 skip
- `npm --prefix content-pipeline test` — 33개 통과
- `node content-pipeline/common/validate.mjs` — 산출물 4종 통과
- `bash scripts/hooks/check-hardcoded-values.sh` / `check-registry-sync.sh` — 통과
