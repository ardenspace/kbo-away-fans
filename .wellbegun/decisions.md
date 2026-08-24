# kbo-away-fans — decisions

- [2026-08-24] [XL] 크로스플랫폼 프레임워크는 Flutter — 애니메이션 연출이 제품 정체성이고, 콘텐츠 갱신은 원격 JSON이 담당하므로 Expo OTA의 이점이 줄며, 긴급 패치는 Shorebird로 가능; rejected: React Native + Expo (OTA 배포 편의는 강점이나 이 앱에서는 콘텐츠 파이프라인이 그 역할을 대체)
- [2026-08-24] [L] 콘텐츠는 서버 없이 버전 있는 정적 JSON 번들로 배포 — 쓰기 주체가 운영자뿐이고 서버에 개인 데이터를 두지 않는 begin 결정과 정합하며, 운영 부담이 최소; rejected: 백엔드 API 서버 (MVP에 운영·비용 부담만 추가, 개인화 없음이라 이점 없음)
- [2026-08-24] [L] KBO 일정은 스케줄러 크롤링 → schedule.json 계약으로 공급 — 공식 API가 없어 크롤링이 불가피하며, 앱은 JSON 계약만 소비해 소스 교체가 계약 뒤에서 가능; rejected: 앱이 직접 경기 사이트를 크롤링 (차단·파싱 변경에 전체 사용자가 동시 노출)
- [2026-08-24] [L] 지도는 네이버 지도 SDK + flutter_naver_map — 국내 POI·한글 라벨 품질이 핵심이고 사용자가 네이버 계정 보유, Flutter 플러그인이 성숙; rejected: Mapbox (커스텀 모션은 최강이나 국내 장소 데이터 품질 열세), 카카오맵 (Flutter 플러그인 성숙도 부족)
- [2026-08-24] [M] 우천 취소 감지는 일정 크롤러의 경기일 고빈도(15–30분) 실행으로 schedule.json에 반영, 앱은 폴링 — 별도 감지 체계 없이 기존 파이프라인에 얹는 가장 싼 구조
- [2026-08-24] [M] 날씨는 OpenWeatherMap 무료 티어를 앱에서 직접 호출, 얇은 래퍼 뒤에 격리 — 연출·플랜B 유도 용도라 정확도 요구가 낮고 래퍼 뒤 소스 교체가 쉬움
- [2026-08-24] [M] 스탬프 인증 방식은 MVP에서 미결정으로 유지 — 콘텐츠 스키마의 구장 ID를 안정적 식별자로 보장해 도입 문만 열어 둠
- [2026-08-24] [M] UGC 대비는 places 스키마의 source 필드(현재 "curated" 고정) 예약까지만 — 검수·계정 구조는 기능 도입 시점에 결정
- [2026-08-24] [M] 콘텐츠 구장 목록은 1군 정규 홈구장 9곳, 컬러 테마는 팀 10개 — 잠실은 두 팀이 공유하므로 테마는 경기의 홈팀 기준으로 전환하고, 제2구장(포항·울산 등)은 후순위
- [2026-08-24] [M] 성공 지표(추천 탭 → 지도 진입)는 Firebase Analytics 익명 이벤트로 측정 — 계정·개인 데이터 없이 행동 횟수만 집계, "서버에 개인 데이터를 두지 않는다"는 begin 결정과 양립
- [2026-08-24] [M] 상태 관리는 flutter_riverpod — 컴파일 타임 안전한 DI/스코프로 TeamThemeScope류 컨텍스트 주입과 잘 맞고, 루트 ProviderScope만 걸어 두면 도입 비용이 낮음
- [2026-08-24] [S] flutter create는 ios/android 플랫폼만 생성 — 모바일 팬 앱이라 데스크톱/웹 불필요, 나중에 flutter create로 추가 가능
- [2026-08-24] [M] 번들 id org는 dev.arden (dev.arden.kbo_away_fans) — 스토어 배포 전이라 변경 비용이 낮은 시점에 임시 확정
- [2026-08-24] [S] lint 기준선은 flutter_lints + strict-casts/inference/raw-types + 소수 추가 규칙(prefer_single_quotes 등) — analyze 경고 0을 유지 가능한 선에서 엄격하게
- [2026-08-24] [S] 루트 위젯(KboAwayFansApp)을 lib/app.dart로 분리 — smoke test가 main() 부작용 없이 루트 위젯만 펌프할 수 있게
