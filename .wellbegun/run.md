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
- [ ] 1.1 schedule 계약 schemaVersion 2 + 앱 파서 확장 (fresh)
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
