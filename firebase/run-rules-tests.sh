#!/usr/bin/env bash
# Firestore 보안 규칙 단위 테스트 러너.
#
#   npm --prefix firebase test        규칙 테스트 1회 실행 (에뮬레이터 자동 기동·종료)
#   npm --prefix firebase run emulator  에뮬레이터만 띄워 둔 채 대기 (수동 확인용)
#
# 에뮬레이터는 Java 런타임을 요구한다. 개발자 머신마다 JDK 위치가 다르므로
# 사용자의 셸 설정을 건드리는 대신 여기서 PATH 를 주입한다 — PATH 에 쓸 수 있는
# java 가 이미 있으면 그것을 그대로 쓰고, 없을 때만 흔한 설치 경로를 뒤진다.
# (macOS 의 /usr/bin/java 는 JVM 이 없어도 존재하는 스텁이라 `command -v` 로는
#  판별되지 않는다. 그래서 실제 실행 결과로 본다.)
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"

if ! java -version >/dev/null 2>&1; then
  for java_home in \
      "${JAVA_HOME:-}" \
      /opt/homebrew/opt/openjdk@21 \
      /opt/homebrew/opt/openjdk \
      /usr/local/opt/openjdk@21 \
      /usr/local/opt/openjdk \
      /usr/lib/jvm/java-21-openjdk-amd64 \
      /usr/lib/jvm/default-java; do
    if [ -n "$java_home" ] && [ -x "$java_home/bin/java" ]; then
      export JAVA_HOME="$java_home"
      export PATH="$java_home/bin:$PATH"
      break
    fi
  done
fi

if ! java -version >/dev/null 2>&1; then
  cat >&2 <<'MSG'
FAIL: Java 런타임을 찾지 못했습니다. Firestore 에뮬레이터는 JDK 17 이상을 요구합니다.
      macOS  : brew install openjdk@21
      Debian : sudo apt-get install -y openjdk-21-jre-headless
      다른 위치에 설치했다면 JAVA_HOME 을 지정하고 다시 실행하세요.
      (README 의 "개발 > Firestore 규칙 테스트" 절 참조)
MSG
  exit 1
fi

firebase_bin="$repo_root/firebase/node_modules/.bin/firebase"
if [ ! -x "$firebase_bin" ]; then
  echo "FAIL: firebase-tools 가 없습니다. npm ci --prefix firebase 를 먼저 실행하세요." >&2
  exit 1
fi

# demo- 접두 프로젝트 id 는 firebase-tools 가 "에뮬레이터 전용"으로 취급한다 —
# 로그인도, 실제 Firebase 프로젝트도 필요 없고 어떤 요청도 클라우드로 나가지 않는다.
project_id="demo-kbo-away-fans"

if [ "${1:-}" = "--serve" ]; then
  exec "$firebase_bin" emulators:start --only firestore --project "$project_id"
fi

exec "$firebase_bin" emulators:exec --only firestore --project "$project_id" \
  "node --test 'firebase/test/*.test.mjs'"
