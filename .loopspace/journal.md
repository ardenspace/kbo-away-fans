# Journal
version: 1

## [1.1] 시드 — 잠실 LG 행 추가 + 재적재
- attempt 1: DONE → verifier PASS
- summary: stadiums.json 10행 (잠실 LG 행 "잠실야구장 (LG)", team_abbr="LG"), 파일 단언 테스트 3건 green. 이전 세션의 미완 작업을 검증 후 그대로 채택.
- 수동 ops 잔여 단계: `python3 scripts/seed.py` (맥미니 원격 DB) 실행 후 stadiums count=10 확인 — Phase 1 실기기 확인의 전제.

## [1.2] 위치 provider 추상화 + 플랫폼 권한 설정
- attempt 1: DONE → panel PASS (security PASS / test-integrity PASS / correctness PASS)
- summary: LocationClient seam 뒤 geolocator, sealed LocationResult 4분기(Acquired/PermissionDenied/ServiceDisabled/Timeout) + kLocationFixTimeout(8s), iOS·Android 포그라운드 전용 권한 선언. 16 테스트 green, analyze clean, failed-first 기계 재증명.

## [1.3] 데이터 계층 — stamp/stadium/games repository
- attempt 1: DONE → panel PASS (security PASS / test-integrity PASS / correctness PASS)
- summary: StampRepository(insertStamp/myStamps)·StadiumRepository(listStadiums)·GamesRepository(teamAbbrsInGamesOn) 인터페이스 + Supabase 구현 + 공유 fakes. DuplicateStampException(23505) vs StampNetworkException 구분, user_id는 auth 세션에서만. 32 테스트 green, analyze clean.
- note: 검증 1차 웨이브가 스펜드 리밋으로 1회 중단됨 → fresh 재dispatch로 완료 (검증 품질 영향 없음).

## [1.4] 근접 판정 + 거리 계산 + 잠실 칸 배정 도메인
- attempt 1: DONE → panel PASS (security PASS / test-integrity PASS / correctness PASS)
- summary: 순수 Dart stamp_domain.dart — 하버사인(경계 inclusive), 최근접+"N.Nkm", 잠실 동률 tie-break→"잠실야구장", KST 달력일 변환(주입 시각), 잠실 칸 배정 ∩{OB,LG} 5시나리오. 두산 abbr="OB" (teams.json 확인). 전체 64 테스트 green.
