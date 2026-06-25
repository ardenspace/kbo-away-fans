"""task-006 운영 래퍼 단위 테스트 (stdlib unittest — 무의존).

실행: crawler/.venv/bin/python -m unittest crawler.tests.test_ops -v
DoD 커버: 윈도우 게이트 / flock 중복방지 / graceful(실패 exit+알림) / 알림 best-effort.
"""
from __future__ import annotations

import datetime as dt
import fcntl
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from crawler import notify, ops

UTC = dt.timezone.utc


def _at(h: int, m: int = 0) -> dt.datetime:
    """2026-06-25 KST h:m → UTC aware datetime."""
    return dt.datetime(2026, 6, 25, h, m, tzinfo=ops.KST).astimezone(UTC)


class WindowGateTest(unittest.TestCase):
    def test_no_games_is_outside(self):
        self.assertIsNone(ops.game_window([]))
        self.assertFalse(ops.in_window(_at(18), []))

    def test_window_spans_pre30_to_post60(self):
        games = [_at(18, 30), _at(14)]  # 14:00, 18:30 경기
        start, end = ops.game_window(games)
        self.assertEqual(start, _at(13, 30))  # 첫경기 -30분
        self.assertEqual(end, _at(19, 30))    # 막경기 +1h

    def test_inside_and_outside(self):
        games = [_at(18, 30)]
        self.assertTrue(ops.in_window(_at(18, 0), games))   # 30분 전 = 경계 안
        self.assertTrue(ops.in_window(_at(19, 30), games))  # +1h = 경계 안
        self.assertFalse(ops.in_window(_at(17, 59), games))  # 윈도우 직전
        self.assertFalse(ops.in_window(_at(19, 31), games))  # 윈도우 직후


class FlockTest(unittest.TestCase):
    def test_second_acquire_skips(self):
        with tempfile.TemporaryDirectory() as d:
            lock = Path(d) / "t.lock"
            holder = open(lock, "w")
            fcntl.flock(holder, fcntl.LOCK_EX | fcntl.LOCK_NB)  # 1번째가 점유
            try:
                with ops.flock_or_skip(lock) as acquired:
                    self.assertFalse(acquired)  # 2번째는 즉시 양보
            finally:
                holder.close()

    def test_acquire_when_free(self):
        with tempfile.TemporaryDirectory() as d:
            with ops.flock_or_skip(Path(d) / "t.lock") as acquired:
                self.assertTrue(acquired)


class GracefulTest(unittest.TestCase):
    @mock.patch.object(ops, "send_telegram")
    @mock.patch.object(ops, "run", side_effect=RuntimeError("HTML 404"))
    def test_failure_exits_nonzero_and_notifies(self, _run, m_notify):
        rc = ops.main(["--mode", "daily"])
        self.assertEqual(rc, 1)            # 실패 exit
        m_notify.assert_called_once()      # 알림 1건
        self.assertIn("실패", m_notify.call_args[0][0])

    @mock.patch.object(ops, "send_telegram")
    @mock.patch.object(ops, "run", return_value={"upserted": 5, "skipped": []})
    def test_success_exits_zero_no_notify(self, _run, m_notify):
        rc = ops.main(["--mode", "daily"])
        self.assertEqual(rc, 0)
        m_notify.assert_not_called()       # 성공은 무알림

    @mock.patch.object(ops, "send_telegram")
    @mock.patch.object(ops, "run", side_effect=AssertionError("크롤 돌면 안 됨"))
    @mock.patch.object(ops.db, "load_scheduled_at_on", return_value=[])
    @mock.patch.object(ops.db, "connect")
    def test_gameday_outside_window_is_noop(self, _conn, _load, _run, m_notify):
        rc = ops.main(["--mode", "gameday"])  # 경기 없음 → no-op, run 미호출
        self.assertEqual(rc, 0)
        m_notify.assert_not_called()


class NotifyBestEffortTest(unittest.TestCase):
    def test_missing_env_returns_false_no_crash(self):
        with mock.patch.object(notify.config, "TELEGRAM_BOT_TOKEN", ""), \
             mock.patch.object(notify.config, "TELEGRAM_CHAT_ID", ""):
            self.assertFalse(notify.send_telegram("x"))  # 크래시 없이 False

    def test_send_failure_is_swallowed(self):
        with mock.patch.object(notify.config, "TELEGRAM_BOT_TOKEN", "t"), \
             mock.patch.object(notify.config, "TELEGRAM_CHAT_ID", "c"), \
             mock.patch.object(notify.requests, "post", side_effect=Exception("net")):
            self.assertFalse(notify.send_telegram("x"))  # 예외 삼킴


if __name__ == "__main__":
    unittest.main()
