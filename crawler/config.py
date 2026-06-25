"""환경 설정 로드.

크롤러는 Postgres 직결(127.0.0.1:5434)로 write 한다 — DECISIONS task-001(E1):
"크롤러 DB 접근 = Postgres 직결, 앱은 Kong/PostgREST 경유". seed.py 와 동일 경로.
postgres 슈퍼유저는 RLS 자동 우회 → 콘텐츠 테이블 write 가능(E10 키격리: 앱 anon 과 분리).
"""
import os
from pathlib import Path

from dotenv import load_dotenv

# repo 루트 .env 로드 (있으면)
_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(_ROOT / ".env")


class Config:
    # 예: postgres://postgres:<pw>@127.0.0.1:5434/postgres (.env.example 참조)
    DATABASE_URL = os.getenv("DATABASE_URL", "")

    def require_db(self) -> None:
        if not self.DATABASE_URL:
            raise RuntimeError("필수 env 누락: DATABASE_URL (.env 참조 — .env.example)")


config = Config()
