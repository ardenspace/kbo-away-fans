#!/usr/bin/env bash
# task-001 — Supabase Postgres 백업 (pg_dump, gzip). cron 1일 1회 (E1, spec §5).
# 컨테이너 내부 pg_dump 사용 → 호스트에 psql/시크릿 불필요.
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

BACKUP_DIR="${BACKUP_DIR:-/Users/arden/code/kbo-away-fans/backups}"
KEEP="${KEEP:-14}"           # 최신 N개 보존
CONTAINER="${CONTAINER:-supabase-db}"

mkdir -p "$BACKUP_DIR"
ts="$(date +%Y%m%d-%H%M%S)"
out="$BACKUP_DIR/kbo-pg-$ts.sql.gz"

docker exec "$CONTAINER" pg_dump -U postgres -d postgres | gzip > "$out"

# 보존 정책: 최신 KEEP개 초과분 삭제
ls -1t "$BACKUP_DIR"/kbo-pg-*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do rm -f "$old"; done

echo "[$(date)] backup ok: $out ($(du -h "$out" | cut -f1))"
