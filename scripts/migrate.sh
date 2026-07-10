#!/usr/bin/env bash
set -euo pipefail

# 맥미니 Supabase(Docker) 에 migration 적용
# psql 네이티브 미설치 환경: docker exec 경유
# 사용법: bash scripts/migrate.sh [--container <name>]

CONTAINER="${SUPABASE_DB_CONTAINER:-kbo-supabase-db}"
DIR="$(cd "$(dirname "$0")/.." && pwd)/supabase/migrations"

if ! docker inspect "$CONTAINER" &>/dev/null; then
  echo "❌ 컨테이너 '$CONTAINER' 를 찾을 수 없습니다."
  echo "   SUPABASE_DB_CONTAINER 환경변수로 컨테이너명을 지정하세요."
  exit 1
fi

echo "🗄  migration 시작 (container: $CONTAINER)"
for f in "$DIR"/*.sql; do
  echo "▶ $(basename "$f")"
  docker exec -i "$CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$f"
done
echo "✅ migration 완료"
