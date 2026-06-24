# Handoff: feat/task-007-flutter-scaffold — @arden

## 2026-06-24

- [x] task-007 (deep) Flutter 스캐폴드: init + Supabase 클라이언트 + 네비 골격 (E1·E9)

### 마지막 커밋
- feat(task-007): Flutter 스캐폴드 — Supabase + Riverpod + go_router

### 진행
- ✅ Step 0: Flutter 3.44.3 Homebrew 설치
- ✅ Step 1: flutter create app/ (com.ardenspace.kboawayfans)
- ✅ Step 2: pubspec.yaml — supabase_flutter·go_router·flutter_riverpod·riverpod_annotation
- ✅ Step 3: main.dart — Supabase.initialize(dart-define) + ProviderScope
- ✅ Step 4: core/supabase_client.dart — supabaseClientProvider
- ✅ Step 5: router/router.dart — go_router 4개 루트
- ✅ Step 6: feature 플레이스홀더 + .gitkeep
- ✅ Step 7: flutter analyze No issues found

### 결정
- **publishableKey**: supabase_flutter 최신 API에서 anonKey → publishableKey 로 변경됨
- **번들ID**: com.ardenspace.kboawayfans (repo명과 일치, 사용자 확정)
- **Flutter 설치**: Homebrew cask 방식 채택

### 블로커
- 없음
