"""텔레그램 실패 알림 (task-006, E5).

크롤 실패 시에만 1건 전송. 알림은 **best-effort** — 토큰/chat_id 가 없거나
전송이 실패해도 예외를 올리지 않는다(알림 실패가 크롤 운영을 더 망가뜨리면 안 됨).
"""
from __future__ import annotations

import requests

from .config import config

_API = "https://api.telegram.org/bot{token}/sendMessage"
_TIMEOUT = 10


def send_telegram(text: str) -> bool:
    """텔레그램으로 text 전송. 성공 True, (미설정·실패 포함) 미전송 False.

    예외를 삼킨다 — 호출부는 반환값을 신경 쓸 필요 없이 안전하다.
    """
    token = config.TELEGRAM_BOT_TOKEN
    chat_id = config.TELEGRAM_CHAT_ID
    if not token or not chat_id:
        print("[notify] 텔레그램 env 미설정 — 알림 스킵 (TELEGRAM_BOT_TOKEN/CHAT_ID)")
        return False
    try:
        resp = requests.post(
            _API.format(token=token),
            json={"chat_id": chat_id, "text": text},
            timeout=_TIMEOUT,
        )
        resp.raise_for_status()
        return True
    except Exception as e:  # noqa: BLE001 — best-effort, 절대 못 올림
        print(f"[notify] 텔레그램 전송 실패(무시): {e}")
        return False
