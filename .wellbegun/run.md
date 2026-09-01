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
- [>] 1.4 타이포 조합 스타일 기존 38곳 일괄 교체 — implementing (mid-tier, sonnet)
- [ ] 1.3 디자인 토큰 확장 네 그룹 (fresh)
- [ ] 1.4 타이포 조합 스타일 기존 38곳 일괄 교체 (basic)
- [ ] 1.5 Firestore 데이터 모델과 보안 규칙 (fresh)
- [ ] 1.6 `lib/backend/` 공통 계층 골격 + 로스터·read-first 문서 (fresh)
- [ ] 1.7 카카오 커스텀 토큰 Cloud Function (fresh)
- [ ] 1.8 공유 컴포넌트 7종 골격 + 로스터 갱신 (fresh)
- [ ] 1.9 강제 장치 3종 설치와 wiring (basic)
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
