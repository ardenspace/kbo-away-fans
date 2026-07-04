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

## [1.7] 도장 애니메이션 + 햅틱 순차 재생
- attempt 1: DONE → verifier PASS (light)
- summary: StampStampAnimation(AnimationController+TweenSequence 오버슈트/낙하/기울기, initState HapticFeedback→onPlay→forward) + StampCelebrationLayer 오버레이가 성공 상태 ref.listen 큐잉→완료마다 다음 칸 순차 advance. 관측 seam=stampCelebrationObserverProvider. 단일=애니·햅틱 각 1회, 잠실 2칸=각 2회 칸순서(rec.played ['OB','LG']), 부분성공=성공칸만. 햅틱은 SystemChannels.platform mock으로 HapticFeedback.vibrate 실채널 카운트. Lottie/Rive 미추가(pubspec 파일단언). 전체 95/95 green, analyze clean, failed-first 기계 재증명.

## [phase 1] verified
- Phase Verifier PASS: 전체 95/95 green, analyze clean. 모든 acceptance 시나리오(발급성공/반경밖 N.Nkm/중복 선판정+UNIQUE/권한거부/서비스꺼짐/네트워크오류/잠실 칸배정/연타방지/10칸 그리드/도장 애니·햅틱 칸당1회) 테스트 존재. Seam 정합: stamp_screen(1.6)↔StampController(1.5)↔stamp_domain(1.4)+location(1.2)+repos(1.3), StampCelebrationLayer(1.7)가 동일 성공상태 구독. 홈 "내 스탬프"→/stamp 도달 배선 확인(router.dart:47, home_screen.dart:46). TODO/FIXME 없음.

## [2.1] 지도 마커 모델 — 잠실 병합 + 방문 플래그
- attempt 1: DONE → verifier PASS (light)
- summary: buildMapMarkers가 (lat,lng) record 키로 그룹핑(좌표 기반, 하드코딩 아님) → 10구장→9마커. 대표행=kJamsilCanonicalName 우선, isVisited=그룹 any 방문(OB만/LG만→true, 둘다 미방문→false로 하드코딩 아님 증명). 비잠실 1:1. 순수 Dart(네이티브·키 무의존). 7 신규 테스트, 전체 102/102 green, analyze clean, failed-first 기계 재증명.

## [2.2] 경로 좌표 시퀀스 로직
- attempt 1: DONE → verifier PASS (light)
- summary: buildStadiumRouteSequence(map_domain.dart) — stadiumId→(lat,lng) 조인 → stampedAt 오름차순 정렬 → 좌표 매핑(미존재 skip) → 인접 동일좌표만 dedup(A→B→A 두번째 A 유지). 좌표 판정 2.1과 동일 (lat,lng) record. ≤1 방문→길이<2. stampedAt는 non-null(모델 확인). 7 신규 테스트, 전체 109/109 green, analyze clean, failed-first 기계 재증명(2.1 커밋본으로 stash→method not found→pop).
