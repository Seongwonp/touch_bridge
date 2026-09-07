# backend/school_gateway.py
"""수원대학교 AI API Gateway(OpenAI 호환) 클라이언트.

- Base URL 예: https://factchat-cloud.mindlogic.ai/v1/gateway
- 텍스트: POST {base}/chat/completions/  (응답: choices[0].message.content)
- 인증: Authorization: Bearer <SCHOOL_API_KEY>
- 호출 제한: 회원당 60초 120건, 본문 25MB, 크레딧 차감 — 재시도는 하지 않는다.

보안 원칙:
- API 키·Authorization 헤더·사용자 발화·이미지 원문을 로그/예외 메시지에 넣지 않는다.
- Base URL은 https만 허용한다.
- 리다이렉트를 따라가지 않는다(allow_redirects=False) — 3xx 응답을 따라가면
  Authorization 헤더가 다른 호스트로 전송될 수 있다.

주의: 게이트웨이가 제공자 네이티브 전체 API를 지원하는 것은 아니다.
사진 입력(image_url data URI)은 OpenAI 호환 형식으로 구성했지만
**실호출 검증 전까지 미검증 상태**다 (docs/WORK_LOG.md 참조).
"""

import base64
import json
import logging
import time
from dataclasses import dataclass
from urllib.parse import urlparse

import requests

logger = logging.getLogger("touch_bridge.backend.school_gateway")

# 엔드포인트별 전체 타임아웃보다 안쪽으로 잡는다
# (/parse-command 30초, /vision-mapping 45초).
TEXT_TIMEOUT_SECONDS = 25
VISION_TIMEOUT_SECONDS = 40
_CONNECT_TIMEOUT_SECONDS = 5

DEFAULT_MODEL = "gemini-3.8-flash"


class SchoolGatewayError(Exception):
    """게이트웨이 호출 실패. kind로 원인을 분류한다.

    kind: config | auth | rate_limit | server | timeout | network | bad_response
    메시지에는 키·사용자 입력이 절대 포함되지 않는다.
    """

    def __init__(self, kind: str, detail: str, status_code: int | None = None):
        super().__init__(f"school_gateway {kind}: {detail}")
        self.kind = kind
        self.detail = detail
        self.status_code = status_code


@dataclass(frozen=True)
class SchoolGatewayConfig:
    api_key: str
    base_url: str
    text_model: str
    vision_model: str

    @classmethod
    def from_env(cls, environ) -> "SchoolGatewayConfig":
        text_model = (environ.get("SCHOOL_API_MODEL") or DEFAULT_MODEL).strip()
        return cls(
            api_key=(environ.get("SCHOOL_API_KEY") or "").strip(),
            base_url=(environ.get("SCHOOL_API_BASE_URL") or "").strip().rstrip("/"),
            text_model=text_model,
            # 사진용 모델은 별도 지정 가능(미지정 시 텍스트 모델과 동일).
            vision_model=(
                environ.get("SCHOOL_API_VISION_MODEL") or text_model
            ).strip(),
        )

    def missing_fields(self) -> list[str]:
        """설정 오류 목록. 비어 있으면 유효한 설정이다. 값 자체는 반환하지 않는다."""
        problems = []
        if not self.api_key:
            problems.append("SCHOOL_API_KEY")
        if not self.base_url:
            problems.append("SCHOOL_API_BASE_URL")
        else:
            parsed = urlparse(self.base_url)
            # 키가 실리는 요청이므로 https 이외(평문 http 포함)는 거부한다.
            if parsed.scheme != "https" or not parsed.netloc:
                problems.append("SCHOOL_API_BASE_URL(https URL이어야 함)")
        return problems


def _post_chat(
    config: SchoolGatewayConfig,
    payload: dict,
    *,
    timeout_seconds: int,
) -> dict:
    """chat/completions 호출 공통부. 성공 시 응답 JSON(dict)을 반환한다."""
    problems = config.missing_fields()
    if problems:
        raise SchoolGatewayError("config", "누락/잘못된 설정: " + ", ".join(problems))

    url = f"{config.base_url}/chat/completions/"
    started = time.perf_counter()
    try:
        response = requests.post(
            url,
            headers={
                "Authorization": f"Bearer {config.api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=(_CONNECT_TIMEOUT_SECONDS, timeout_seconds),
            # 3xx를 따라가면 Authorization이 다른 호스트로 전송될 수 있다.
            allow_redirects=False,
        )
    except requests.Timeout as e:
        raise SchoolGatewayError("timeout", "게이트웨이 응답 시간 초과") from e
    except requests.RequestException as e:
        # 예외 문자열에 URL/헤더가 섞일 수 있으므로 원문을 전달하지 않는다.
        raise SchoolGatewayError("network", "게이트웨이 연결 실패") from e

    elapsed_ms = int((time.perf_counter() - started) * 1000)
    status = response.status_code

    if 300 <= status < 400:
        # 리다이렉트는 따르지 않고 실패로 처리한다(인증 정보 보호).
        logger.error(
            "school_gateway.redirect_refused status=%d elapsed_ms=%d", status, elapsed_ms
        )
        raise SchoolGatewayError("network", "게이트웨이가 리다이렉트를 반환함", status)
    if status in (401, 403):
        logger.error("school_gateway.auth_failed status=%d", status)
        raise SchoolGatewayError("auth", "게이트웨이 인증 실패", status)
    if status == 429:
        logger.warning("school_gateway.rate_limited")
        raise SchoolGatewayError("rate_limit", "게이트웨이 호출 제한 초과", status)
    if status >= 500:
        logger.error("school_gateway.server_error status=%d", status)
        raise SchoolGatewayError("server", "게이트웨이 서버 오류", status)
    if status != 200:
        logger.error("school_gateway.unexpected_status status=%d", status)
        raise SchoolGatewayError("server", "게이트웨이 예상 밖 응답 코드", status)

    try:
        data = response.json()
    except ValueError as e:
        raise SchoolGatewayError("bad_response", "게이트웨이 응답이 JSON이 아님", status) from e
    if not isinstance(data, dict):
        raise SchoolGatewayError("bad_response", "게이트웨이 응답 구조가 예상과 다름", status)

    # 관측: 학교 API를 실제로 썼는지 로그로 구별한다. 키/본문은 기록하지 않는다.
    logger.info(
        "ai.call provider=school model_req=%s model_resp=%s status=ok elapsed_ms=%d",
        payload.get("model"),
        data.get("model"),
        elapsed_ms,
    )
    return data


def _extract_content(data: dict) -> str:
    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        raise SchoolGatewayError("bad_response", "choices가 비어 있음")
    message = choices[0].get("message") if isinstance(choices[0], dict) else None
    content = message.get("content") if isinstance(message, dict) else None
    if not isinstance(content, str) or not content.strip():
        raise SchoolGatewayError("bad_response", "응답 텍스트가 비어 있음")
    return content


def chat_text(
    config: SchoolGatewayConfig,
    *,
    system_prompt: str,
    user_content: str,
    timeout_seconds: int = TEXT_TIMEOUT_SECONDS,
) -> str:
    """텍스트 채팅 1회 호출 → 응답 텍스트. 재시도하지 않는다."""
    payload = {
        "model": config.text_model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_content},
        ],
        "stream": False,
    }
    return _extract_content(_post_chat(config, payload, timeout_seconds=timeout_seconds))


def chat_vision(
    config: SchoolGatewayConfig,
    *,
    prompt: str,
    image_bytes: bytes,
    mime_type: str,
    timeout_seconds: int = VISION_TIMEOUT_SECONDS,
) -> str:
    """사진 + 프롬프트 1회 호출 → 응답 텍스트.

    OpenAI 호환 image_url(data URI) 형식으로 구성한다.
    **게이트웨이의 사진 입력 지원은 실호출 검증 전까지 미검증** — 미지원이면
    게이트웨이 오류로 실패하며, 다른 제공자로 조용히 우회하지 않는다.
    """
    encoded = base64.b64encode(image_bytes).decode("ascii")
    payload = {
        "model": config.vision_model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime_type};base64,{encoded}"},
                    },
                ],
            }
        ],
        "stream": False,
    }
    return _extract_content(_post_chat(config, payload, timeout_seconds=timeout_seconds))


def parse_model_json(content: str) -> dict:
    """모델 응답 텍스트에서 JSON 오브젝트를 파싱한다(``` 펜스 허용).

    파싱 실패는 SchoolGatewayError(bad_response)로 통일한다 — 사용자 발화나
    응답 본문을 예외 메시지에 싣지 않는다.
    """
    stripped = content.strip().replace("```json", "").replace("```", "").strip()
    try:
        data = json.loads(stripped)
    except json.JSONDecodeError as e:
        raise SchoolGatewayError("bad_response", "모델 응답이 JSON 형식이 아님") from e
    if not isinstance(data, dict):
        raise SchoolGatewayError("bad_response", "모델 응답 JSON이 오브젝트가 아님")
    return data
