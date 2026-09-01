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
- [ ] 1.2 크롤 창 과거 확장 + 경기 결과 산출 (fresh)
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
