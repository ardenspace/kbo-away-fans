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

## [2.3] NCP Client ID 배선 + ops 문서 + 미주입 degrade
- attempt 1: DONE → verifier PASS (light)
- summary: 순수 Dart naver_map_config.dart — `ncpMapClientId = String.fromEnvironment('NCP_MAP_CLIENT_ID')` 상수 + `shouldDegradeMap(clientId)=trim().isEmpty` 술어. main.dart가 SUPABASE_* 컨벤션대로 참조하되 미주입이어도 crash 없이 debug-only assert 경고만(Supabase init·스탬프 정상). docs/ops/ncp-maps-setup.md(task-009 패턴): 토큰 발급5/번들ID3/패키지명4/한도설정4/무료이용량3. 실키 하드코딩 0건(default=""). 4 신규 테스트, 전체 113/113 green, analyze clean. failed-first "Method not found: 'shouldDegradeMap'" 확인.
- 검증 주의: verifier 서브에이전트가 스펜드 리밋(monthly spend limit)으로 중단 → 검증이 전부 기계적(테스트 green/red, grep 카운트, 시크릿 스캔, failed-first 타당성)이라 오케스트레이터가 메인 세션에서 잔여 기계 체크를 직접 완료(구현은 미작성, 독립성 유지). 판단 개입 없음.
- 재사용 계약(2.4 의존): shouldDegradeMap(ncpMapClientId) → 지도 화면 degrade 분기; ncpMapClientId getter → 실제 네이버맵 초기화 값.

## [2.4] 지도 화면 골격 — flutter_naver_map 통합 + 추상화 seam + degrade
- attempt 1: DONE → panel PASS (security PASS / test-integrity PASS / correctness PASS)
- summary: 함수형 MapViewBuilder seam(map_view.dart) + 실제 NaverMap 격리(naver_map_view.dart). MapScreen(clientId 기본 ncpMapClientId, mapViewBuilder 기본 buildNaverMapView)이 shouldDegradeMap(clientId)로 degrade(중앙 안내텍스트, 네이티브 위젯 미생성, takeException==null)↔실경로 분기, 마커 리스트 pass-through. 네이티브 SDK가 test 그래프에 안 끌려오게 격리 → fake builder pump로 위젯 테스트. flutter_naver_map ^1.4.4 추가. 5 신규 테스트, 전체 118/118 green, analyze clean.
- 3-lens 상세: security=하드코딩 시크릿 0, Client ID는 fromEnvironment/주입 파라미터(기본 빈문자열)만, 신규 네트워크/eval 표면 없음. test-integrity=4 acceptance 각 실제 assertion(fake pump / degrade '' / non-degrade는 `same(buildNaverMapView)`로 실경로 도달 assert / 마커 `same(markers)` 9개 identity), 게이밍 없음. correctness=118 green + analyze clean + 기계 failed-first(impl 3파일 stash→map_screen 테스트 fail→pop 복원) + scope creep 없음(2.5/2.6/2.7 명시적 defer).
- 재사용 계약(2.5 의존): MapScreen이 clientId·mapViewBuilder 주입 seam 노출 → 2.5가 view-state(내위치/권한 off, 오류+재시도)와 경로 좌표(buildStadiumRouteSequence)·경로 애니 트리거를 이 화면/컨트롤러에 얹는다. 마커 조회 provider 배선도 2.5. naver_map_view.dart의 마커 렌더는 현재 onMapReady addOverlayAll pass-through(스타일/내위치는 2.5).

## [2.5] 지도 view-state — 내 위치/권한 + 경로 애니 재생 + 오류
- attempt 1: DONE → panel PASS (security PASS / test-integrity PASS / correctness PASS)
- summary: 새 MapView ConsumerStatefulWidget + mapDataProvider(2.1 buildMapMarkers + 2.2 buildStadiumRouteSequence 병합). 내위치=currentLocationProvider→resolveMyLocation(데이터와 독립 → 위치 실패가 마커/경로 blank 안 함, 권한거부→enabled=false+message≠null+마커·경로 정상). 조회실패→MapErrorView(오류+재시도), 빈 지도 아님. 경로애니=mapRouteAnimationObserverProvider, mount당 route길이≥2면 1회 발화·≤1 미발화, re-mount 시 _animationFired 리셋 재발화. 새 MapSurfaceBuilder/MapSurfaceData seam(fake로 전달값 pump 검증). 7 신규 테스트, 전체 125/125 green, analyze clean, 기계 failed-first 확인.
- 3-lens 상세: security=시크릿 0, 위치는 기존 포그라운드 1회 seam 유지(백그라운드/추적/영속 없음, raw 좌표 transient view-state만). test-integrity=4 criteria 실제 assertion(perm-denied 마커·경로 생존 assert, anim ≥2/≤1/재진입 3케이스 실카운트, route=buildStadiumRouteSequence 실좌표 동등, fetch-error MapErrorView·surface 미렌더), 2.4 5테스트 무손상. correctness=125 green+analyze clean+failed-first(impl 5파일 stash→2.5 테스트 compile fail→pop 복원)+scope creep 없음.
- 재사용/주의(2.6 반드시 인지): correctness 비블로킹 지적 — 새 MapView가 정적 MapScreen을 기능적으로 대체함. **2.6은 /map 라우트에 MapScreen이 아니라 MapView를 연결해야 한다** (안 그러면 MapScreen이 dead code화). MapView는 stadiumRepository/stampRepository provider에서 데이터를 조회하므로 라우트에서 파라미터 없이 빌드 가능.

## [2.6] 홈 "원정 지도" 버튼 + /map 라우트
- attempt 1: DONE → verifier PASS (light)
- summary: router.dart:49 GoRoute('/map')→const MapView()(완성 화면, all-default params라 라우트 빌드 가능 — 2.5 correctness의 dead-code 우려 해소: 골격 MapScreen이 아니라 MapView 연결). home_screen.dart:50-53 "원정 지도" OutlinedButton→context.go('/map'). map_route_test: 버튼 탭→currentConfiguration.uri.path=='/map' + MapView findsOneWidget + takeException null(단순 존재확인 아님). 기존 "내 스탬프"/"원정 일정 보기" 버튼·widget_test.dart 무회귀. 2 신규 테스트, 전체 127/127 green, analyze clean, 기계 failed-first(impl 2파일 stash→map_route 테스트 fail→pop) 확인.

## [2.7] flutter_naver_map 네이티브 플랫폼 설정
- attempt 1: DONE → verifier PASS (light)
- summary: flutter_naver_map ^1.4.4 = pure-Dart init(네이티브 키 슬롯 없음). main.dart:37 가드 init `if (!shouldDegradeMap(ncpMapClientId)) FlutterNaverMap().init(...)` — 미주입→스킵→crash 없음(R12, naver_map_config 재사용). 네이티브 토큰: iOS Info.plist:75 주입지점(--dart-define=NCP_MAP_CLIENT_ID) + deployment target 13.0(pbxproj, 플러그인 iOS12 요구 충족), Android Manifest:5 주입지점 + build.gradle.kts:24 minSdk=maxOf(flutter.minSdkVersion,23)(플러그인 ≥23 충족). 리터럴 키 0건, 백그라운드 위치 권한 미추가(기존 포그라운드만). Dart 테스트 신규 없음(네이티브 config — grep 단언+analyze 검증, init은 main()에서만 실행되어 위젯테스트 미노출; failed-first stash 스킵). 전체 127/127 green, analyze clean.
- fact 정정: plan files 라인 "app/android/build.gradle" → 실제 앱레벨은 Kotlin DSL "app/android/app/build.gradle.kts"(minSdk 위치). 구현자가 올바른 파일 사용.
