# backend/validation.py
"""AI 응답 스키마 검증/정화.

사용자 발화는 프롬프트에 escape 없이 삽입되므로, 주입된 지시가 AI 응답을
오염시킬 수 있다(예: needs_confirmation=false 유도, 임의 message 낭독,
존재하지 않는 버튼 ID). 응답 message는 그대로 시각장애인 사용자에게 TTS로
낭독되고 commands는 물리 버튼 누름으로 이어지므로, 서버가 마지막 방어선으로
스키마를 강제한다 — 화이트리스트에 없는 값은 안전한 기본값으로 강등한다.
"""

import re

ALLOWED_ACTIONS = {
    "MICROWAVE_CONTROL",
    "WASHER_CONTROL",
    "AC_CONTROL",
    "EMERGENCY_STOP",
    "NAVIGATE",
    "IMMEDIATE_PRESS",
    "NONE",
}

ALLOWED_TARGETS = {"connection", "mapping", "settings"}

# 논리 버튼 ID: BT-01, BT-W03, BT-A05 형식만 허용
_BUTTON_ID_RE = re.compile(r"^BT-[A-Z]?\d{2}$")

MAX_MESSAGE_LEN = 200
MAX_COMMANDS = 12
MAX_SECONDS = 20 * 60  # 20분 — 전자레인지 상한(microwave_logic clamp와 정합)


def _clean_message(value, fallback=""):
    if not isinstance(value, str):
        return fallback
    cleaned = value.strip()
    # 제어문자 제거 (TTS로 낭독되는 문자열)
    cleaned = "".join(ch for ch in cleaned if ch.isprintable())
    return cleaned[:MAX_MESSAGE_LEN] if cleaned else fallback


def sanitize_command_response(data):
    """AI가 만든 명령 JSON을 안전한 스키마로 강제한다.

    dict가 아니면 안전한 NONE 응답을 돌려준다. 항상 새 dict를 반환한다.
    """
    if not isinstance(data, dict):
        data = {}

    action = data.get("action")
    if action not in ALLOWED_ACTIONS:
        action = "NONE"

    raw_commands = data.get("commands")
    commands = []
    if isinstance(raw_commands, list):
        for item in raw_commands[:MAX_COMMANDS]:
            if isinstance(item, str) and _BUTTON_ID_RE.match(item):
                commands.append(item)

    # 실행형 액션인데 유효한 버튼이 하나도 없으면 실행 불가 — NONE으로 강등해
    # 하류(앱)가 빈 시퀀스를 실행 시도하지 않게 한다.
    if action in {"MICROWAVE_CONTROL", "WASHER_CONTROL", "AC_CONTROL", "IMMEDIATE_PRESS"} and not commands:
        action = "NONE"

    target = data.get("target")
    if target not in ALLOWED_TARGETS:
        target = None
    if action != "NAVIGATE":
        target = None

    try:
        seconds = int(data.get("inferred_seconds", 0))
    except (TypeError, ValueError):
        seconds = 0
    seconds = max(0, min(seconds, MAX_SECONDS))

    try:
        confidence = float(data.get("confidence", 0.5))
    except (TypeError, ValueError):
        confidence = 0.0
    confidence = max(0.0, min(confidence, 1.0))

    needs_confirmation = data.get("needs_confirmation") is True

    return {
        "action": action,
        "commands": commands,
        "target": target,
        "inferred_seconds": seconds,
        "confidence": confidence,
        "needs_confirmation": needs_confirmation,
        "message": _clean_message(
            data.get("message"), fallback="명령을 이해하지 못했습니다. 다시 말씀해 주세요."
        ),
        "confirmation_message": _clean_message(data.get("confirmation_message")),
    }
