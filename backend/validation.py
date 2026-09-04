# backend/validation.py
"""AI 응답 스키마 검증/정화.

사용자 발화는 프롬프트에 escape 없이 삽입되므로, 주입된 지시가 AI 응답을
오염시킬 수 있다(예: needs_confirmation=false 유도, 임의 message 낭독,
존재하지 않는 버튼 ID). 응답 message는 그대로 시각장애인 사용자에게 TTS로
낭독되고 commands는 물리 버튼 누름으로 이어지므로, 서버가 마지막 방어선으로
스키마를 강제한다 — 화이트리스트에 없는 값은 안전한 기본값으로 강등한다.
"""

import math
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
MAX_VISION_BUTTONS = 50
MIN_VISION_CONFIDENCE = 0.65


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


def sanitize_vision_mapping_response(data):
    """Vision 모델 출력을 물리 매핑 전 단계의 안전한 좌표 스키마로 강제한다.

    버튼 중심 x/y가 없는 항목은 row/col만으로 위치를 추측하지 않고 제거한다.
    AI 결과는 아직 사진 좌표일 뿐이므로 여기서 장치 mm 좌표를 만들지 않는다.
    """
    if not isinstance(data, dict):
        data = {}

    raw_grid = data.get("grid") if isinstance(data.get("grid"), dict) else {}
    try:
        rows = int(raw_grid.get("rows", 3))
        cols = int(raw_grid.get("cols", 3))
    except (TypeError, ValueError):
        rows, cols = 3, 3
    rows = max(1, min(rows, 20))
    cols = max(1, min(cols, 20))

    buttons = []
    raw_buttons = data.get("buttons")
    if isinstance(raw_buttons, list):
        used_ids = set()
        for raw in raw_buttons[:MAX_VISION_BUTTONS]:
            if not isinstance(raw, dict):
                continue
            button_id = raw.get("button_id")
            if not isinstance(button_id, str) or not _BUTTON_ID_RE.match(button_id):
                continue
            if button_id in used_ids:
                continue
            try:
                x = float(raw.get("x"))
                y = float(raw.get("y"))
                confidence = float(raw.get("confidence", 0.0))
            except (TypeError, ValueError):
                continue
            if not all(math.isfinite(value) for value in (x, y, confidence)):
                continue
            if not (0.0 <= x <= 1.0 and 0.0 <= y <= 1.0):
                continue
            confidence = max(0.0, min(confidence, 1.0))
            # 물리 동작으로 이어지는 좌표다. 낮은 신뢰 결과를 자동 매핑에 섞지
            # 않고 사용자가 수동으로 추가하도록 한다.
            if confidence < MIN_VISION_CONFIDENCE:
                continue
            try:
                row = int(raw.get("row", 0))
                col = int(raw.get("col", 0))
            except (TypeError, ValueError):
                row, col = 0, 0
            used_ids.add(button_id)
            buttons.append({
                "button_id": button_id,
                "label": _clean_message(raw.get("label"), fallback=button_id)[:40],
                "row": max(0, min(row, rows - 1)),
                "col": max(0, min(col, cols - 1)),
                "x": x,
                "y": y,
                "confidence": confidence,
            })

    return {
        "grid": {"rows": rows, "cols": cols},
        "device_type": _clean_message(data.get("device_type"))[:40],
        "description": _clean_message(data.get("description"))[:120],
        "buttons": buttons,
    }
