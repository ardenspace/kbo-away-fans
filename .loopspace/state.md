# Loopspace State
version: 1
run_status: executing
current_phase: 2
current_task: 2.7

## Project Facts
- test: cd app && flutter test
- build/run: cd app && flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... (Phase 2 추가: --dart-define=NCP_MAP_CLIENT_ID=...)
- analyze: cd app && flutter analyze
- stack: Flutter (Dart) + riverpod codegen(@Riverpod/build_runner) + go_router; 백엔드 = 셀프호스팅 Supabase(anon key, --dart-define 주입); 지도 = flutter_naver_map; 위치는 mock 주입 가능한 provider 추상화 뒤; seed = python3 scripts/seed.py (원격 맥미니 DB, 멱등 upsert)

## Tasks
| id  | status  | attempts | risk  |
|-----|---------|----------|-------|
| 1.1 | done    | 1        | light |
| 1.2 | done    | 1        | heavy |
| 1.3 | done    | 1        | heavy |
| 1.4 | done    | 1        | heavy |
| 1.5 | done    | 1        | heavy |
| 1.6 | done    | 1        | light |
| 1.7 | done    | 1        | light |
| 2.1 | done    | 1        | light |
| 2.2 | done    | 1        | light |
| 2.3 | done    | 1        | light |
| 2.4 | done    | 1        | heavy |
| 2.5 | done    | 1        | heavy |
| 2.6 | done    | 1        | light |
| 2.7 | done    | 1        | light |
