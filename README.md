# kbo-away-fans

**KBO 원정팬** — 응원팀을 정하면 원정 경기 일정, 구장 가이드, 맛집·플랜B, GPS 스탬프, 원정 지도를 제공하는 Flutter + Supabase 앱.

## 현재 상태

이 저장소는 초기 pslog 계획(`PLAN.md`, `docs/EXECUTION-PLAN.md`) 위에 Loopspace Phase 1/2 구현이 추가된 상태다.

- 브랜치: `main`
- 앱 테스트: `cd app && flutter test` 기준 127개 통과
- Loopspace 실행 상태: `.loopspace/state.md` 기준 `run_status: complete`
- 자동 검증 범위: Flutter 위젯/도메인/provider 테스트, 지도 미주입 degrade, 스탬프 상태머신, 마커/경로 도메인
- 남은 범위: 실기기 dogfood, 원격 DB seed 확인, NCP Maps 실키 주입, launchd 크롤러 운영 로그 확인

수동 검증 체크리스트는 [`docs/DOGFOOD-CHECKLIST.md`](docs/DOGFOOD-CHECKLIST.md)를 본다.

## 제품 범위

V1 기준 기능:

- 응원팀 설정 후 내 팀 원정 일정 조회
- 구장별 주차·좌석·동선·편의 정보
- 구장별 맛집, 우천 플랜B 장소 표시
- 경기 취소/연기 시 플랜B 유도
- 이메일 로그인 + Supabase 유저 상태 동기화
- GPS 근접 기반 스탬프 발급 + 중복 방지
- 도장 애니메이션 + 햅틱
- 네이버맵 기반 구장 마커, 방문 구장 경로 입력/트리거
- KBO 공식 일정 크롤러로 `games` upsert

카카오 OAuth는 구조는 있으나, 카카오 개인앱의 이메일 동의항목/비즈앱 전환 이슈로 V1 dogfood에서는 이메일 로그인을 기준으로 본다.

## 아키텍처

```text
app/                 Flutter 앱
  lib/
    core/            Supabase client, router refresh seam
    router/          go_router 라우트와 홈
    features/
      auth/          로그인
      team/          응원팀 선택/동기화
      schedule/      원정 일정 조회
      stadium/       구장 가이드
      places/        맛집/플랜B
      stamp/         GPS 스탬프, 도장 애니메이션, repositories
      map/           네이버맵, 마커/경로 도메인, degrade 처리

supabase/migrations/ DB 스키마 + RLS
scripts/             migration/seed/backup 스크립트
crawler/             KBO 일정 fetch → parse → map → upsert 파이프라인
infra/               Supabase Docker, cloudflared, launchd plist

docs/                컨셉, 실행계획, task 문서, ops 문서
handoffs/            완료 task handoff
.loopspace/          Loopspace 최신 Phase 1/2 실행 기록
```

## 백엔드 / DB

백엔드는 Supabase 셀프호스팅을 기준으로 한다.

- 앱: Supabase SDK + anon key
- 콘텐츠 테이블: public SELECT, 앱 anon 쓰기 불가
- 유저 테이블: `profiles`, `stamps` owner-scoped RLS
- 크롤러/시드: Postgres 직결
- 노출: Cloudflare Tunnel (`kbo-api.ardenspace.com`) 설계
- Studio: 외부 비공개, 로컬 접근 기준

주요 테이블:

- `teams`
- `stadiums`
- `games`
- `restaurants`
- `planb_places`
- `profiles`
- `stamps`

## 앱 실행

Flutter 앱은 compile-time dart-define 값이 필요하다.

```bash
cd app
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=NCP_MAP_CLIENT_ID=...
```

로컬 파일로 주입할 때는 예시 파일을 복사해서 사용한다.

```bash
cd app
cp dart_define.example.json dart_define.local.json
# dart_define.local.json 값을 로컬에서만 채운다.
flutter run --dart-define-from-file=dart_define.local.json
```

주의:

- `dart_define.local.json`은 로컬 실키 파일이다.
- `NCP_MAP_CLIENT_ID`가 비어 있으면 앱 전체가 죽지 않고 지도 화면만 안내 텍스트로 degrade 된다.
- Supabase URL/anon key는 비어 있으면 debug assert로 잡는다.

NCP Maps 설정 절차는 [`docs/ops/ncp-maps-setup.md`](docs/ops/ncp-maps-setup.md)를 본다.

## 테스트 / 검증

```bash
cd app
flutter test
flutter analyze
```

현재 기록상:

- `flutter test`: 127/127 통과
- `flutter analyze`: clean (`.loopspace/journal.md` Phase 2 verifier 기록)

주요 테스트 범위:

- 인증 게이트
- 팀 테마
- 스탬프 도메인/상태머신/repository seam
- 위치 권한 4분기
- 도장 애니메이션/햅틱 observer seam
- 지도 마커 잠실 병합/방문 플래그
- 방문 구장 경로 시퀀스
- 지도 미주입 degrade
- `/map` 라우트와 홈 버튼

자동 테스트가 실기기 GPS·네이버맵 렌더·launchd 운영까지 보장하지는 않는다. 그 범위는 dogfood 체크리스트로 확인한다.

## 크롤러

KBO 공식 일정 `GetScheduleList`를 월 단위 JSON으로 가져와 `games`에 upsert한다.

```bash
# 단발 범위 실행
crawler/.venv/bin/python -m crawler --from 2026-06-08 --to 2026-06-14

# 운영 wrapper
crawler/.venv/bin/python -m crawler.ops --mode daily
crawler/.venv/bin/python -m crawler.ops --mode gameday
```

구조:

```text
fetch.py     KBO 공식 일정 요청
parse.py     raw rows → RawGame
mapping.py   팀/구장 매핑, 상태 정규화, game_id 합성, KST→UTC
db.py        Postgres 직결 + games upsert
pipeline.py  fetch → parse → map → upsert 결선
ops.py       daily/gameday, lock, graceful, 텔레그램 알림
```

운영 설계:

- daily: 하루 1회, 오늘~+14일 재크롤
- gameday: 매분 launchd로 깨어나되 경기 윈도우 밖에서는 no-op
- 실패 시 DB 무변경 + 텔레그램 알림 best-effort

## 시드 / 마이그레이션

```bash
# migration
scripts/migrate.sh

# seed
python3 scripts/seed.py
```

원격/운영 DB에 실제로 seed가 반영됐는지는 dogfood 전 `stadiums` 10행, 잠실 OB/LG 2칸 여부를 확인한다.

## 구현 문서의 진실원천

이 프로젝트는 pslog와 Loopspace를 모두 dogfood했다. 현재 상태를 볼 때 우선순위는 다음과 같다.

1. 실제 코드와 테스트 결과
2. `.loopspace/state.md`, `.loopspace/journal.md` — 최신 스탬프/지도 Phase 기록
3. `DECISIONS.md` — 승격된 제품/기술 결정
4. `PLAN.md`, `docs/EXECUTION-PLAN.md` — 초기 pslog 계획과 전체 범위
5. `docs/tasks/*`, `handoffs/*` — task별 상세 기록

## 다음 개발 방향

우선순위:

1. [`docs/DOGFOOD-CHECKLIST.md`](docs/DOGFOOD-CHECKLIST.md)로 실기기/운영 검증
2. 발견된 문제를 UX, 데이터, 운영, 코드 결함으로 분류
3. 작은 task 단위로 수정
4. 장기적으로 홈/콘텐츠 화면에 서버 주도 섹션 레이어(`app_sections` + Flutter section renderer) 검토
