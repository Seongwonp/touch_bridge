# backend/ai_provider.py
"""AI 제공자 선택과 학교 게이트웨이 경로의 명령 해석/사진 분석.

제공자 선택은 환경 변수 AI_PROVIDER로 **명시적으로** 한다:
- "google" (기본값): 기존 google.generativeai 직접 호출 (main.py의 기존 경로)
- "school": 수원대학교 API Gateway (school_gateway.py)

원칙: 학교 API를 선택한 상태에서 호출이 실패하면 Google로 조용히 우회하지
않는다 — 실패는 실패로 보고한다(실행 명령이 없는 안전 응답 또는 HTTP 오류).

이 모듈은 fastapi/genai를 import하지 않아 외부 키 없이 단위 테스트가 가능하다.
"""

import logging

import school_gateway
from prompts import MICROWAVE_SYSTEM_PROMPT
from school_gateway import SchoolGatewayConfig, SchoolGatewayError
from validation import sanitize_command_response, sanitize_vision_mapping_response

logger = logging.getLogger("touch_bridge.backend.ai_provider")

PROVIDER_GOOGLE = "google"
PROVIDER_SCHOOL = "school"
_VALID_PROVIDERS = {PROVIDER_GOOGLE, PROVIDER_SCHOOL}


def resolve_provider(environ) -> tuple[str, bool]:
    """(provider, is_valid)를 돌려준다.

    - 미설정 → ("google", True): 기존 배포와의 호환 기본값.
    - 알 수 없는 값 → (원문 소문자, False): 조용히 기본값으로 덮지 않는다 —
      호출 시점에 설정 오류로 실패시켜 오설정을 드러낸다.
    """
    raw = (environ.get("AI_PROVIDER") or PROVIDER_GOOGLE).strip().lower()
    return raw, raw in _VALID_PROVIDERS


# 실패 시 사용자에게 읽어줄 문구 — 실행 명령(commands)은 절대 포함하지 않는다.
_FAIL_MESSAGES = {
    "config": "AI 서비스 설정에 문제가 있습니다. 보호자나 관리자에게 확인을 요청해 주세요.",
    "auth": "AI 서비스 인증에 문제가 있습니다. 보호자나 관리자에게 확인을 요청해 주세요.",
    "rate_limit": "죄송합니다. 현재 AI 서비스 사용량이 많아 잠시 후 다시 이용해 주세요.",
    "timeout": "분석 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.",
    "network": "AI 서비스에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.",
    "server": "AI 서비스가 일시적으로 불안정합니다. 잠시 후 다시 시도해 주세요.",
    "bad_response": "명령을 분석하는 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.",
}


def _safe_none_response(message: str) -> dict:
    """실행 명령이 없는 안전 실패 응답 (sanitize_command_response 스키마와 동일)."""
    return {
        "action": "NONE",
        "commands": [],
        "target": None,
        "inferred_seconds": 0,
        "confidence": 0.0,
        "needs_confirmation": False,
        "message": message,
        "confirmation_message": "",
    }


def interpret_with_school(config: SchoolGatewayConfig, text: str) -> dict:
    """학교 게이트웨이로 음성 명령 텍스트를 해석한다.

    항상 sanitize_command_response를 통과한 dict(또는 안전 실패 응답)를 돌려준다.
    어떤 실패에서도 Google로 우회하지 않는다.
    """
    try:
        content = school_gateway.chat_text(
            config,
            system_prompt=MICROWAVE_SYSTEM_PROMPT,
            user_content=f'사용자 입력: "{text}"',
        )
        return sanitize_command_response(school_gateway.parse_model_json(content))
    except SchoolGatewayError as e:
        logger.error(
            "ai.call provider=school kind=%s status=%s result=fail(parse)",
            e.kind,
            e.status_code,
        )
        return _safe_none_response(
            _FAIL_MESSAGES.get(e.kind, _FAIL_MESSAGES["bad_response"])
        )


def vision_with_school(
    config: SchoolGatewayConfig,
    *,
    prompt: str,
    image_bytes: bytes,
    mime_type: str,
) -> dict:
    """학교 게이트웨이로 사진을 분석한다.

    성공 시 sanitize_vision_mapping_response를 통과한 dict를 돌려주고,
    실패 시 SchoolGatewayError를 그대로 올린다 — 호출부(main.py)가 HTTP
    상태 코드로 매핑한다. Google로 우회하지 않는다.

    ⚠ 게이트웨이의 사진 입력 지원은 실호출 검증 전까지 **미검증**이다.
    """
    content = school_gateway.chat_vision(
        config,
        prompt=prompt,
        image_bytes=image_bytes,
        mime_type=mime_type,
    )
    return sanitize_vision_mapping_response(school_gateway.parse_model_json(content))


def gateway_error_to_http(e: SchoolGatewayError) -> tuple[int, str]:
    """Vision 경로용: SchoolGatewayError → (HTTP 상태, 사용자 메시지)."""
    mapping = {
        "config": (503, _FAIL_MESSAGES["config"]),
        "auth": (502, "AI 게이트웨이 인증 오류입니다. 관리자에게 확인을 요청해 주세요."),
        "rate_limit": (429, "AI 서비스 호출 제한을 초과했습니다. 잠시 후 다시 시도해 주세요."),
        "timeout": (504, "이미지 분석 시간이 초과되었습니다."),
        "network": (502, "AI 서비스에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요."),
        "server": (502, "AI 서비스가 일시적으로 불안정합니다. 잠시 후 다시 시도해 주세요."),
        "bad_response": (502, "AI 응답 형식이 올바르지 않습니다."),
    }
    return mapping.get(e.kind, (502, "이미지 분석에 실패했습니다."))
