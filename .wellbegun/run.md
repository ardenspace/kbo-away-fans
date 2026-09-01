---
mode: companion
cycle: 2
---

# 실행 원장 — 사이클 2

시작: 2026-09-01 / 모드: companion (L/XL 발견 시 멈추고 `pending/` 에 질문을 남긴다)

강제 장치 확인: phase 1 의 step 1.9 가 spec 의 Enforcement plan 4항목을 전부 담고 있어
추가 단계 없음. 착수 시점의 `pending/` 은 비어 있음.

모델 배분: S/M 구현자 = mid-tier, L/XL 결정을 건드리는 단계의 구현자 = high-tier,
모든 fresh 검증자·phase 통합 검증·전체 리뷰 = high-tier, basic 검증 = 지휘자가 직접 실행.

## Phase 1 — 델타 기반 + 강제 장치
- [x] 1.1 verified (fresh, high-tier) — 커밋 4bf9d63; 경계 테스트 6개 전부 기대대로(validate exit 0 / 버전1 픽스처 exit 1 / 종료-점수누락 픽스처 exit 1 / 파이프라인 37통과 / content_loader 19통과 / analyze 무지적), 전체 회귀 174통과·1스킵.
      round 1 ACCEPT + 계약 밖 위험 4건. 그중 "오늘 원정 경기가 finished 로 바뀌면 홈이 자정 전에 다음 경기 D-1 로 넘어감"(next_away_game.dart 의 문서화된 불변식 위반)을 지휘자가 [M] 으로 등급하고 기존 불변식 유지로 결정 → decisions.md 기록 후 수정 커밋 d152758 (크롤러 no-change 게이트에 schemaVersion 포함, 크롤 픽스처 statusInfo 실응답 반영 포함).
      round 2 새 검증자 ACCEPT — 제품 결정 2건이 코드에 반영됨을 확인, 계약 위반 없음.
      probes: round 1 은 23개 작성·2개 커밋(models_test.dart 로 흡수, schedule.canceled-with-score.json), round 2 는 12개 작성·4개 커밋(9556b25, finished_game_fanout_test.dart).
      1.2 로 넘기는 사실 3건: (a) `homeScore: 5.0` 은 validate 가 통과시키지만 앱 파서가 문서 전체를 거부 — 현재 크롤 경로로는 도달 불가, (b) 점수 없는 RESULT 경기 한 건이 크롤 전체를 exit 1 로 세움 — 창을 과거로 넓히면 노출이 커짐, (c) 종료 판정이 `statusCode === 'RESULT'` 단일 문자열에 걸려 있고 값이 바뀌면 조용히 전부 scheduled 가 됨.
- [x] 1.2 verified (fresh, high-tier) — 커밋 5f6cfec + 3bf8626 + f8872b1; 경계 테스트 4개 전부 exit 0, 전체 회귀 flutter 180통과·1스킵 / 파이프라인 61통과 / validate 4종 / 훅 2종. 산출물 108→168경기(finished 48·canceled 12·scheduled 108), 2026-08-18~09-30, 23KB→39KB.
      round 1 ACCEPT + 계약 밖 위험 6건. 그중 "점수 결측 경기를 건별 warn 후 제외하는 처리에 집계 게이트가 없어 원천이 점수 필드를 개명하면 종료 경기 전원이 빠진 채 crawl_success 로 배포됨"과 "결측이 오늘 경기에 걸리면 홈이 오늘의 원정을 잃음"을 지휘자가 [M] 으로 등급 → 이전 산출물 값 유지 + 임계값 초과 시 exit 1 의 두 겹으로 결정, 응답 잘림 방지와 함께 수정 커밋 3bf8626.
      round 2 새 검증자 ACCEPT + 지휘자 결정 자체의 사각지대 지적: 20분 cron 에서 종료 직전 상태가 언제나 scheduled 라 전원 결측이 "이전 상태 유지" 경로로 흘러 임계값이 0 을 봄(3회 반복 고착까지 재현). 지휘자가 [M] 으로 임계값이 세는 대상을 "살리지 못한 결측"에서 "원천이 종료라는데 점수를 못 얻은 모든 경기"로 옮기기로 결정 → 수정 커밋 f8872b1 (구현자가 수정 전 새 테스트의 실패를 먼저 확인).
      round 3 은 fresh 검증자 대신 지휘자가 직접 재현: 점수 필드 개명본을 실제 CLI 에 통과시켜 exit 1 · 기존 산출물 바이트 무변경 · 임시 파일 미잔류를 확인. 수정 범위가 round 2 검증자가 진단하고 해법까지 제시한 단일 시나리오의 카운트 기준 한 곳이라 새 문맥의 이득이 비용을 넘지 않는다고 판단. phase 1 integration 에서 fresh 눈이 이 단계를 다시 본다.
      probes: round 1 은 12개 작성·2케이스 커밋(crawl-schedule.window.test.mjs), round 2 는 6개 작성·2케이스 커밋(crawl-schedule.carryover.test.mjs — 유지 장치가 낡은 값을 고착시키지 않는 반대 방향).
      이후 단계로 넘기는 사실 3건: (a) 실 응답에서 미시작·취소 경기의 점수가 0/DRAW 로 채워져 있어 statusCode 가 점수보다 먼저 뒤집히면 거짓 무승부가 산출됨 — KBO 에 0-0 무승부가 실재해 0-0 자체를 신호로 쓸 수 없음, (b) 이전이 canceled 인 경기를 원천이 점수 없는 finished 로 주면 canceled 로 남음 — 발생 경로가 사실상 서스펜디드 재개뿐이고 그때는 점수가 함께 옴, (c) 과거 취소는 원천이 '경기취소'로 정규화해 우천 구분이 유실됨 — 창 확장 1회성이고 앱의 소비 지점 두 곳이 두 상태를 동등하게 다룸.
- [x] 1.3 verified (fresh, high-tier) — 커밋 fedc120 + 2280352 + 0ee633a + 6b9f91a; 경계 테스트 3개 exit 0, 전체 회귀 197통과·1스킵, 훅 2종 통과.
      **세 번 REJECT 를 받은 단계.** 세 번 모두 뿌리가 같았다 — 등급 표현에 겹과 신호를 더할수록 검사할 경계가 늘고 그때마다 빈틈이 생겼다.
      round 1 REJECT: 등급 링 색이 팀 색 위에서 안 읽힘(한화·기아는 세 등급 전부 3:1 미달, regular↔master 는 10팀 전부 1.17:1). 이를 지킨다는 테스트가 `ringColor != 팀색` 을 == 로 비교하는 공허한 단언이라 어떤 값도 통과했다. 함께 지적된 "1.4 의 경계 grep 이 lib/app.dart 의 ThemeData 까지 잡아 통과 불가"는 지휘자가 plan.md 의 검사 명령을 의도에 맞게 교정(acceptance 문구는 유지).
      round 2 REJECT: 수정이 밝은 겹을 어두운 겹 안쪽에 가둬 몸통과 닿는 겹은 잉크뿐 — 경계 기준으로 재면 7팀 미달(두산 1.04·롯데 1.05·키움 1.19·kt 1.21). 통과한 이유는 새 테스트가 경계가 아니라 "겹 중 최대"를 쟀기 때문. 지휘자가 [M] 으로 측정 기준을 몸통과 맞닿는 겹으로 못 박고 요구 범위를 10개 팀 색으로 되돌림(sRGB 전수는 경계 기준으로 원리상 달성 불가).
      round 3 REJECT: 등급별 흰 광택이 몸통 자체를 밝혀 실제 칠해지는 색 기준으로 한화×마스터가 2.83:1. 굵기 하한도 겉테에만 걸려 있어 윤곽 0.01·띠 0.1 변이가 27개 테스트를 전부 통과. 지휘자가 [M] 으로 **덜어내는 방향**을 확정 — 광택 제거(등급 신호는 금속색·띠 개수·링 굵기 셋), 굵기 하한을 모든 겹으로.
      round 4 는 fresh 검증자 대신 지휘자가 직접 확인: 겉테↔팀색 경계 대비를 10팀 재계산(최소 3.37 한화 / 최대 21.00 kt, 전부 3:1 이상), 금속↔윤곽 3.38·6.48·12.53, 이웃 등급 1.918·1.933, 윤곽 제거 시 금 띠가 1.385 로 무너지는 것까지 확인. round 3 에서 27개를 전부 통과시켰던 변이 둘(contourWidth 0.01, bandWidth 0.1)을 직접 주입해 이제 정확히 실패하는 것을 재현하고 원복. 수정이 신호를 걷어내는 방향이라 새 문맥의 이득이 비용을 넘지 않는다고 판단했고, phase 1 integration 이 다시 본다.
      probes: round 1 은 3개 작성·1개 인계(등급 가독성), round 2 는 5개 작성·1개 인계(경계 대비), round 3 은 9개 작성·1개 인계(칠해지는 몸통 기준) — 셋 다 badge_tier_legibility_test.dart 로 합쳐 커밋됨.
      함께 정리된 것: haloColor 를 ColorTokens.textInverse 참조로 통일, 좌초 토큰 tierMarkSize 제거, emptyBorderColor 추가, BadgeTierStyle.bodyColor 로 "칠해지는 몸통"을 토큰이 소유(다음에 몸통에 무언가 얹혀도 검사가 따라오게), 은색을 #969FAB 로 옮겨 금속 사다리를 균등화.
      text.* 15항목은 round 1 검증에서 실제 사용처 37곳(12개 파일)을 전부 덮는 것이 전수 확인됨 — 1.4 가 손조합으로 남길 자리 없음.
- [x] 1.4 verified (basic) — 커밋 d0b00b5 (12개 파일, +116/-358); 경계 5개 전부 통과: 손조합 잔여 grep **0**, tokens_test 23통과, 전체 197통과·1스킵, 하드코딩 훅 exit 0, analyze 무지적. 지휘자가 렌더 불변을 기계적으로 대조 — 삭제된 손조합 35개 중 29개가 조합 스타일의 (크기·굵기·색)과 정확히 일치하고, 나머지 6개(앱바 3곳의 동적 색, dday_header 와 team_badge 의 조건부 크기, scratch_card 의 색 상속)는 대응 조합의 크기·굵기가 원래 값과 같고 색만 copyWith 으로 얹힘. 새 조합을 만들 필요가 없었고 ADR 도 없음.
- [x] 1.5 verified (fresh, high-tier) — 커밋 27003a8 + 10ef1b0 + 4e25d65; 경계 테스트 2종 통과(규칙 테스트 50개 exit 0 / firestore.rules·docs/firestore-schema.md 좌표 grep 매치 없음), 전체 회귀 flutter 197통과·1스킵 / 파이프라인 통과 / validate exit 0 / 훅 2종 exit 0 / analyze 무지적. 세션 중단으로 부분 작업이 트리에 남았던 단계 — 새 구현자가 이어받아 완성(27003a8).
      round 1 REJECT: 테스트 하네스가 파일 2개를 못 견딤 — node --test 가 파일별 프로세스를 병렬로 띄워 한 에뮬레이터 DB 를 서로 clearFirestore(11회 중 8회 실패 재현). 함께 확인된 문서-사실 불일치 2건: 계약 문서가 "규칙 테스트가 사다리를 단언한다"·"grep 검사를 받는다"라고 썼으나 당시 사실이 아니었음. 수정 커밋 10ef1b0 — --test-concurrency=1, 규칙이 tierFor(count) 로 임계 1/3/10 을 직접 강제, 문서 교정. round 1 탐침 13개는 rules-surface.test.mjs 로 다듬어져 같은 커밋에 흡수.
      수정 중 구현자가 [L] 로 보고한 발견을 지휘자가 [M] 재등급: firestore.rules 가 표현식 한도(평가당 1000)에 임박 — 만판 쓰기를 그대로 재는 파수꾼 테스트와 문서 못박기까지만 하고 재구성은 유보 (decisions.md 기록).
      round 2 새 검증자 ACCEPT — 서버 변환 공격(serverTimestamp·increment·deleteField·merge·batch) 전부 방어, 로스터·정규식을 실데이터 168+12건과 전수 대조, 표현식 예산을 별도 에뮬레이터로 실측 재확인(여유 칸당 conjunct 2줄 — 문서 기록 1줄은 안전한 방향의 보수). probes: 20개 작성·커밋(4e25d65, rules-writes.test.mjs).
      이후 단계로 넘기는 사실 5건: (a) board 는 자기신고 값 — 규칙은 count↔tier 일치만 재고 실제 도장 문서 수와의 일치는 재지 못하므로 4.2 의 "요약이 어긋나지 않는다"는 앱 트랜잭션이 보장해야 함, (b) 사용자 문서를 지워도 하위 컬렉션(stamps·likes)은 남음 — 계정 삭제 흐름이 직접 지워야 함, (c) 계약 밖 필드가 한 번 낀 문서는 hasOnly 때문에 소유자 update 가 전부 거부됨 — 마이그레이션은 Admin SDK 로만 가능, (d) 사용자 문서가 없어도 도장 쓰기가 통과 — 4.2 의 전제(온보딩 완료)는 규칙이 아니라 앱 흐름이 보장, (e) 컬렉션 그룹 질의는 규칙·인덱스 모두 미지원 — 3.3·4.3 이 쓰려면 둘을 함께 고쳐야 함.
- [x] 1.6 verified (fresh, high-tier) — 커밋 4405bbd + f190a61; 경계 테스트 4종 전부 통과(test/backend 40케이스 exit 0 / SDK import grep 매치 없음 / 하드코딩 훅 exit 0 / analyze 무지적), 전체 회귀 flutter 237통과·1스킵 / 파이프라인 61통과 / registry-sync exit 0.
      round 1 REJECT: 코드·타입 경계는 전부 버텼으나 read-first 문서(CLAUDE.md)가 미신설 강제 장치 2개(registry-sync 의 backend 짝, check-no-location-upload.sh — 둘 다 1.9 몫)를 현재형 사실로 서술. 검증자 탐침 17케이스는 3중 복제(규칙↔문서↔앱 상수) 전수 대조·등급 사다리·읽기 모델 공격·provider 조용한 대역 부재까지 전부 통과 확인. 수정 커밋 f190a61 (mid-tier, sonnet — 결정 없는 시제 교정 2문장) 후 지휘자가 직접 재확인: 두 서술이 오늘의 사실과 일치, 훅 2종·analyze 통과. 수정 범위가 검증자가 해법까지 제시한 문장 2곳이라 새 문맥의 이득이 비용을 넘지 않는다고 판단, phase 1 integration 이 다시 본다.
      이후 단계로 넘기는 사실 5건: (a) UserProfile.fromData 가 board 에만 관대 — board 키 없음·map 아님이면 예외 없이 빈 판, 2.4 어댑터 변환 오류가 "도장 잃은 판"으로 조용히 그려질 수 있음, (b) guardBackend 는 Future 전용 — 스트림 2개(authStateChanges·watchProfile)의 오류를 도메인 오류로 옮기는 공용 경로가 없어 2.2/2.4 가 손으로 붙이면 흩어짐, (c) 닉네임 길이 셈이 앱(runes)과 규칙(size())에서 다를 수 있음 — 규칙 테스트가 ASCII 만 재서 한글·이모지 경계 미확정, 2.4 전에 규칙 테스트 한 줄로 확정 권장, (d) LikeRecord.fromData 가 문서 id↔placeId 일치를 확인 안 함(쓰기는 규칙이 강제), (e) StampWrite.documentId 는 검사 없이 문자열 연결 — 호출자가 toData() 전에 문서 참조를 만들면 로스터 밖 경로가 잠깐 존재.
- [x] 1.7 verified (fresh, high-tier) — 커밋 77758b5 + 7b7716a + b7ad78b; 경계 테스트 2종 통과(functions 테스트 exit 0 / account_email grep 매치 없음), 전체 회귀 functions 33 / firebase 규칙 51 / flutter 237통과·1스킵 / 파이프라인 61 / analyze 무지적 / 훅 2종.
      round 1 REJECT: 닉네임 길이를 세 겹이 서로 다른 단위로 셈 — 규칙 size() 는 UTF-16 코드 단위(에뮬레이터 실측으로 확정), 함수는 코드 포인트 절단, Dart 는 runes. "코드포인트 ≤20, UTF-16 >20" 닉네임(이모지 혼합)이 함수·앱을 통과하고 규칙에서 거부되어 2.3/2.4 사용자 문서 생성이 실패하는 경로. 1.6 이 넘긴 사실 (c)가 결함으로 확정된 사례. 수정 커밋 7b7716a — [M] 기준 단위를 UTF-16 코드 단위로 확정(규칙 언어가 단위를 못 바꾸는 유일한 자리라서), 함수 절단(서러게이트·ZWJ 꼬리 방지)·Dart _checkNickname·규칙 테스트 경계 케이스·REGISTRY·schema 문서 네 자리 정합.
      round 2 새 검증자 ACCEPT — 함수가 실제로 내놓은 닉네임을 에뮬레이터 규칙에 그대로 태우는 층간 탐침 포함 11개 전부 통과, uid `kakao:{id}` 가 규칙 경로 매칭과 정합함도 확인. probes: round 1 은 8개 작성·수정 커밋에 정식화(kakao-e2e.test.js), round 2 는 11개 작성·커밋(b7ad78b).
      이후 단계로 넘기는 사실 4건: (a) 429 가 internal 로 나감 — 2.3 이 BackendError 로 옮길 때 재시도 가능 실패가 "알 수 없음"으로 떨어짐, (b) 함수 nickname 은 null 일 수 있는데 규칙은 nickname 필수·size≥1 — 대체값을 정하는 자리가 아직 없어 2.4 의 문서 생성 경로가 정해야 함, (c) kakaoCustomToken 은 미인증 공개 callable 이고 App Check 없음(비용 브레이크는 maxInstances:10 뿐) — 2.3 배포 시점에 App Check 여부 결정 필요, (d) index.js 가 err.message 를 클라이언트로 그대로 보냄 — 예상 밖 예외의 메시지 노출 표면.
- [x] 1.8 verified (fresh, high-tier) — 커밋 de61f36 + 46060df; 경계 테스트 4종 전부 통과(test/ui/shared 71케이스 exit 0 / registry-sync·하드코딩 훅 exit 0 / analyze 무지적), 전체 회귀 flutter 277통과·1스킵 / 파이프라인 61 / firebase 규칙 54 / functions 41.
      round 1 REJECT: 시스템 뒤로가기 한 번이 모든 탭의 스택을 되돌림 — NavigatorPopHandler.enabled 는 canPop 만 정하고 콜백은 IndexedStack 이 살려 둔 5개 핸들러 전부에 전달되어 각자 pop(구현 자신의 주석이 막겠다고 적은 바로 그 동작). 검증자가 가드 한 줄(if (index != _index) return)로 해소됨을 실측하고 red 탐침을 남김. 수정 커밋 46060df (mid-tier, sonnet) — 가드 추가 + initialIndex assert 상한 보강, 탐침 13개를 shared_skeleton_edge_cases_test.dart 로 흡수(전부 기존과 중복 없음). 지휘자가 직접 재확인: 71케이스·전체 277 통과. 해법까지 실측된 단일 시나리오라 새 문맥의 이득이 비용을 넘지 않는다고 판단, phase 1 integration 이 다시 본다.
      이후 단계로 넘기는 사실 3건: (a) 구글·애플 로그인 버튼은 제공자 표기 지침(전용 자산·색·문구)이 심사에 걸림 — 2.2 실연동 때 SocialSignInButton 모습을 지침에 맞춰 재손질 필요, (b) LikeButton 의 실패 되돌리기는 탭 시점 값으로 되돌림 — 쓰기 대기 중 부모가 liked 를 바꾸는 호출부가 생기면(3.2) 최신 값이 아닌 탭 이전 값으로 돌아가는 경계 존재, (c) BadgeTokens.cellRadius 는 현재 미소비(StampBadge 가 원형) — 판 배치를 바꾸는 단계가 소비하거나 정리해야 함.
- [x] 1.9 verified (basic) — 커밋 30272a7; 지휘자가 경계 시나리오를 직접 재현: 깨끗한 트리 4검사 전부 exit 0 / lib/backend 로스터 없는 파일 → registry-sync exit 2 / lib/backend 업로드 경로 lat 필드 → no-location-upload exit 2 / lib/features cloud_firestore import → import-boundary exit 2 / 위반 스테이징 상태 git commit → exit 1 차단 / 정리 후 전부 exit 0·트리 원상 복구. flutter 277통과·1스킵, analyze 무지적. PostToolUse 는 hardcoded-values(기존)+no-location-upload(신규) 2종, registry-sync·import-boundary 는 pre-commit 전용. 1.6 이 예고로 남긴 CLAUDE.md 두 서술을 현재형으로 갱신. ADR 2줄(전부 S).
- [ ] phase 1 integration

## Phase 2 — 계정: 로그인 게이트에서 사용자 문서까지
- [ ] 2.1 로그인 게이트와 인증 상태 (fresh)
- [ ] 2.2 구글·애플 로그인 실연결 + Firebase 프로젝트 설정 (fresh)
- [ ] 2.3 카카오 로그인 (fresh)
- [ ] 2.4 사용자 문서와 선택 팀의 원본 이전 (fresh)
- [ ] 2.5 온보딩 위치 권한 요청 (basic)
- [ ] phase 2 integration

## Phase 3 — 5탭 골격과 좋아요 여정
- [ ] 3.1 하단 5탭 전환 (basic)
- [ ] 3.2 좋아요 토글 (basic)
- [ ] 3.3 좋아요 내역 탭 (basic)
- [ ] 3.4 마이페이지 탭 (basic)
- [ ] phase 3 integration

## Phase 4 — 배지: 방문 판정에서 못 받는 날까지
- [ ] 4.1 구장 방문 판정 (fresh)
- [ ] 4.2 도장 쓰기와 칸별 요약 갱신 (fresh)
- [ ] 4.3 배지 판과 칸 상세 (fresh)
- [ ] 4.4 도장 획득 연출과 등급 상승 (basic)
- [ ] 4.5 도장을 못 받는 날의 안내 (basic)
- [ ] phase 4 integration

## Phase 5 — 홈 개인화 마무리
- [ ] 5.1 홈 최근 5경기 결과 요약 (basic)
- [ ] 5.2 홈 상단 현재 위치 표시 (basic)
- [ ] phase 5 integration

## 전체 리뷰
- [ ] whole-run fresh-eyes review
