# KBO 원정팬 — Dogfood / 수동 검증 체크리스트

> 목적: 자동 테스트가 통과한 코드 상태와, 실제 기기·원격 DB·운영 환경에서 확인해야 하는 항목을 분리한다.
>
> 원칙: 실키(`dart_define.local.json`, Supabase env, NCP Client ID, Telegram token)는 저장소에 커밋하지 않는다.

## 0. 기준 상태 기록

- [ ] 브랜치 확인

```bash
git status --short --branch
```

- [ ] 앱 자동 테스트 확인

```bash
cd app
flutter test
flutter analyze
```

기대:

- `flutter test` 전부 통과
- `flutter analyze` issue 없음

## 1. 원격 DB / seed 확인

목표: 앱이 기대하는 10개 스탬프 칸과 콘텐츠 기본 데이터가 운영 DB에 존재하는지 확인한다.

- [ ] Supabase 셀프호스팅 컨테이너 기동 확인
- [ ] migration 적용 상태 확인
- [ ] seed 실행 또는 최신 seed 반영 확인

```bash
python3 scripts/seed.py
```

- [ ] `stadiums` count = 10 확인
- [ ] 잠실 두 칸 확인
  - `잠실야구장` / team_abbr `OB`
  - `잠실야구장 (LG)` / team_abbr `LG`
  - 두 행 좌표 동일
- [ ] `teams`에 두산 abbr가 `OB`인지 확인
- [ ] `restaurants`, `planb_places`가 주요 구장에 표시될 만큼 존재하는지 확인
- [ ] RLS smoke
  - anon으로 콘텐츠 SELECT 가능
  - anon으로 콘텐츠 INSERT/UPDATE 불가
  - 로그인 유저 A/B가 서로의 `profiles`, `stamps`를 볼 수 없음

## 2. 앱 실키 / dart-define 확인

목표: 앱 실행에 필요한 compile-time 값이 로컬에서만 주입되는지 확인한다.

- [ ] `app/dart_define.local.json` 존재, gitignore 확인
- [ ] 값 확인
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `NCP_MAP_CLIENT_ID`
- [ ] 실키 파일이 `git status --short`에 추적 대상으로 뜨지 않는지 확인

```bash
git status --short app/dart_define.local.json
```

- [ ] `NCP_MAP_CLIENT_ID` 미주입 실행 시 지도 화면만 안내 텍스트로 degrade 되는지 확인
- [ ] `NCP_MAP_CLIENT_ID` 주입 실행 시 네이버맵 초기화가 시도되는지 확인

## 3. 인증 / 프로필 dogfood

목표: 이메일 로그인 기준으로 V1 인증 경로와 유저 상태 동기화를 확인한다.

- [ ] 미인증 부팅 시 `/login` 화면 렌더
- [ ] 이메일 가입/로그인 성공
- [ ] 가입 후 `profiles` 자동 생성
- [ ] 응원팀 선택 가능
- [ ] 앱 재시작/재로그인 후 favorite team 유지
- [ ] 카카오 버튼/흐름은 현재 보류 상태임을 UI/문서상 혼동 없이 처리

## 4. 원정 일정 dogfood

목표: favorite team 기준 원정 일정이 DB 최신 상태로 표시되는지 확인한다.

- [ ] 응원팀을 하나 선택
- [ ] `/schedule` 진입
- [ ] `games.away_team_id == 내 팀`인 경기만 표시
- [ ] 홈경기가 섞이지 않음
- [ ] 오늘 00:00 이후 경기만 표시
- [ ] 당겨서 새로고침/재진입 시 최신 DB 조회
- [ ] `cancelled`/`postponed` 경기 카드에서 플랜B CTA 표시

## 5. 구장 / 맛집 / 플랜B dogfood

목표: 수작업 콘텐츠가 앱 안에서 출처와 함께 읽히는지 확인한다.

- [ ] 일정 카드에서 구장 상세 이동
- [ ] 구장 가이드 4종 표시
  - 주차
  - 좌석
  - 동선
  - 편의
- [ ] 맛집 탭 표시
- [ ] `pick_type` 배지 표시
- [ ] 플랜B 탭 표시
- [ ] 출처 링크가 외부 브라우저로 열림
- [ ] 빈 콘텐츠/네트워크 실패 UI가 깨지지 않음

## 6. GPS 스탬프 dogfood

목표: 실제 기기 위치 권한과 GPS 품질에서 스탬프 UX가 자연스러운지 확인한다.

- [ ] 위치 권한 미허용 상태에서 도장 찍기 → 권한 안내
- [ ] 위치 서비스 꺼짐 → 서비스 켜기 안내
- [ ] 위치 timeout 상황 → 재시도 안내
- [ ] 구장 반경 밖 → 최근접 구장까지 `N.Nkm` 안내
- [ ] 구장 반경 안 → 스탬프 발급 성공
- [ ] 중복 발급 시 중복 안내
- [ ] 버튼 연타해도 중복 insert가 발생하지 않음
- [ ] 잠실 현장 테스트 시 OB/LG 칸 배정이 당일 경기와 맞는지 확인
- [ ] 도장 애니메이션과 햅틱이 과하거나 어색하지 않은지 체감 확인
- [ ] 앱 재시작/재로그인 후 스탬프북 상태 유지

## 7. 네이버맵 / 원정 지도 dogfood

목표: 실제 네이버맵 SDK 렌더와 지도 데이터가 맞는지 확인한다.

- [ ] `/map` 라우트 진입
- [ ] Client ID 미주입이면 안내 텍스트만 보이고 crash 없음
- [ ] Client ID 주입이면 네이버맵 렌더
- [ ] 구장 마커 표시
- [ ] 잠실은 마커 1개로 병합
- [ ] 방문한 구장은 visited 상태로 구분
- [ ] 위치 권한 거부/서비스 꺼짐이 마커/경로 표시를 막지 않음
- [ ] 내 위치 표시가 기대대로 동작
- [ ] 방문 구장 2개 이상일 때 경로 입력/애니메이션 트리거 확인
- [ ] 지도 조회 실패 시 오류+재시도 UI 확인

## 8. 크롤러 / 운영 dogfood

목표: 앱이 읽는 `games` 데이터가 운영 크롤러로 안정적으로 갱신되는지 확인한다.

- [ ] 수동 daily 실행

```bash
crawler/.venv/bin/python -m crawler.ops --mode daily
```

- [ ] 수동 gameday 실행

```bash
crawler/.venv/bin/python -m crawler.ops --mode gameday
```

- [ ] `games` upsert count와 status 분포 확인
- [ ] 경기일 윈도우 밖 gameday no-op 확인
- [ ] launchd plist 등록 상태 확인
- [ ] 로그 확인

```bash
tail -n 200 ~/Library/Logs/kbo-crawler.log
```

- [ ] 실패 알림 env 미설정이어도 크롤 자체가 crash하지 않음
- [ ] 실패 알림 env 설정 시 Telegram 알림 1건 수신 확인
- [ ] daily/gameday 동시 실행 lock 동작 확인

## 9. 백업 / 인프라 dogfood

목표: 셀프호스팅 Supabase 운영 리스크를 최소화한다.

- [ ] Cloudflare Tunnel `kbo` ingress가 API 경로만 노출하는지 확인
- [ ] Studio가 외부에서 열리지 않는지 확인
- [ ] 로컬 Kong/Studio 접근 확인
- [ ] pg_dump 백업 launchd 동작 확인
- [ ] `backups/`에 최신 gzip dump 생성 확인
- [ ] 복구 리허설 절차 문서화 여부 확인

## 10. 출시 전 판단

- [ ] “실제 원정 한 번을 이 앱만 보고 다녀올 수 있는가?” 기준으로 한 사이클 수행
  - 일정 확인
  - 구장 가이드 확인
  - 맛집 확인
  - 비/취소 시 플랜B 확인
  - 현장 스탬프
  - 지도/경로 확인
- [ ] 발견 이슈를 분류
  - 코드 버그
  - 데이터 부족/오류
  - UX 문구/흐름 문제
  - 운영/인프라 문제
  - 장기 개선 아이디어
- [ ] 수정은 작은 task 단위로 재개

## 장기 개선 메모

서버 주도 섹션 레이어를 검토할 때의 첫 적용 후보:

- 홈 hero banner
- 오늘/이번 주 원정 일정 strip
- 응원팀 기반 추천 카드
- 우천/취소 플랜B banner
- 구장별 맛집 carousel
- 스탬프 진행률 card
- 공지/이벤트 notice

권장 원칙:

- 앱은 안전한 렌더러와 핵심 로직을 책임진다.
- 서버/DB는 콘텐츠, 노출 순서, 기간, 조건, 이미지 URL, CTA route를 책임진다.
- 모르는 section type은 skip/fallback 처리한다.
- schema_version을 둔다.
