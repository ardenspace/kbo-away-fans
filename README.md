# kbo-away-fans

KBO 원정 팬을 위한 구장 주변 가이드 앱 (Flutter).

## 구조

- `lib/design/` — 디자인 토큰 (색·간격·타이포·모션). 토큰 파일 밖 raw 리터럴 금지.
- `lib/ui/shared/` — 공유 컴포넌트 (`REGISTRY.md` 로스터와 짝 유지).
- `lib/features/` — 화면·기능 단위 코드.
- `content-pipeline/` — 서버 없는 콘텐츠 파이프라인 (크롤링 → 검증 → 정적 JSON 배포).
- `.wellbegun/` — 파이프라인 문서 (spec/plan/decisions).

## 개발

```sh
flutter pub get
flutter analyze   # 경고 0 유지
flutter test
```

### 클론 후 1회: pre-commit 훅 설치

git hook은 클론으로 전파되지 않으므로 저장소 내 훅 경로를 지정한다:

```sh
git config core.hooksPath scripts/hooks
```

이후 커밋마다 `check-hardcoded-values.sh`(토큰 밖 raw 디자인 값)와
`check-registry-sync.sh`(공유 폴더 ↔ REGISTRY.md 로스터 동기화)가 실행되어 위반 커밋을 막는다.
Claude Code 세션에서는 `.claude/settings.json`의 PostToolUse 훅이 편집 직후에도 같은 검사를 돌린다.
