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

## [1.5] 발급 컨트롤러 — 상태머신 + 실패 분기 + 연타/중복 방지
- attempt 1: DONE → panel PASS (security PASS / test-integrity PASS / correctness PASS)
- summary: @riverpod StampController Notifier + sealed StampIssueState. 위치=currentLocationProvider seam, 기준시각=신규 stampClockProvider seam(주입). 연타방지=첫 await 이전 동기적 StampIssuing 세팅. 잠실=canonical("잠실야구장") 행 id로 games 조회→resolveTargetSlots로 칸 확정, insert는 대상 칸별 1회 루프(부분실패 시 성공칸=성공/나머지=실패). 선판정 dup + 주입 UNIQUE(23505) 둘 다 StampDuplicated로 수렴. 21 테스트, 전체 85 green, analyze clean. correctness가 impl 2파일 stash→컴파일 fail→pop 복원으로 failed-first 기계 재증명.
- 규약 결정(비블로킹): 잠실 games 조회 stadium_id는 명세 미고정 → name==kJamsilCanonicalName("잠실야구장", OB행) id로 조회(크롤러 별칭표 "잠실"→"잠실야구장" 매핑과 정합). games FK가 실제 LG행을 가리키면 그 한 줄만 조정.

## [1.6] 스탬프북 화면 — 10칸 그리드 + 수집률 + 로딩/오류
- attempt 1: DONE → verifier PASS (light)
- summary: stampbookProvider(FutureProvider가 listStadiums+myStamps 병합)를 유일 렌더 소스로 AsyncValue.when 로딩/오류(StampbookError+재시도)/그리드 분기. 칸=Key(stamp-cell-<abbr>)+stampColor(방문=팀컬러 kTeamColors, 미방문=회색). "도장 찍기" 버튼 발급중 onPressed==null. 6 신규 테스트, 전체 91/91 green, analyze clean. failed-first 기계 재증명 통과.
- note: riverpod 3.1.0 Override 미공개 export → 테스트가 내부 _IssuingController override로 StampIssuing 주입. busy state는 별도 CircularProgressIndicator라 해당 테스트 pump() 사용.
