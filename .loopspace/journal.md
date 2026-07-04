# Journal
version: 1

## [1.1] 시드 — 잠실 LG 행 추가 + 재적재
- attempt 1: DONE → verifier PASS
- summary: stadiums.json 10행 (잠실 LG 행 "잠실야구장 (LG)", team_abbr="LG"), 파일 단언 테스트 3건 green. 이전 세션의 미완 작업을 검증 후 그대로 채택.
- 수동 ops 잔여 단계: `python3 scripts/seed.py` (맥미니 원격 DB) 실행 후 stadiums count=10 확인 — Phase 1 실기기 확인의 전제.

## [1.2] 위치 provider 추상화 + 플랫폼 권한 설정
- attempt 1: DONE → panel PASS (security PASS / test-integrity PASS / correctness PASS)
- summary: LocationClient seam 뒤 geolocator, sealed LocationResult 4분기(Acquired/PermissionDenied/ServiceDisabled/Timeout) + kLocationFixTimeout(8s), iOS·Android 포그라운드 전용 권한 선언. 16 테스트 green, analyze clean, failed-first 기계 재증명.
