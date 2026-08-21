import json
import os
import time
import uuid
import logging
import asyncio
from collections import defaultdict, deque
from contextlib import asynccontextmanager

from fastapi import FastAPI, UploadFile, File, HTTPException, Header, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from dotenv import load_dotenv
import google.generativeai as genai
from fastapi.middleware.cors import CORSMiddleware

# 모듈화된 로직 임포트
from prompts import MICROWAVE_SYSTEM_PROMPT
from microwave_logic import infer_food_command, check_simple_rules
from database import init_db, get_device_profile
from validation import sanitize_command_response

# .env 파일 로드
load_dotenv()

logger = logging.getLogger("touch_bridge.backend")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s"
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """서버 시작 시 DB 초기화 (deprecated on_event 대체)"""
    await init_db()
    logger.info("Database initialized.")
    yield


app = FastAPI(lifespan=lifespan)

# CORS: 데모 편의상 origin은 열어두되, credentials는 쓰지 않는다
# ("*" + allow_credentials=True 조합은 스펙 위반이며 불필요한 노출).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── 인증 ─────────────────────────────────────────────────────────────────────
# BACKEND_API_KEY가 설정돼 있으면 모든 API 요청에 X-API-Key 헤더를 요구한다.
# 미설정 시(로컬 개발) 개방 — 배포 시 반드시 설정할 것.
# 이 서버는 Gemini API 키를 대신 소비하는 프록시라, 무인증 공개는 곧
# 요금 폭탄 표면이다.
_API_KEY = os.getenv("BACKEND_API_KEY", "").strip()


async def require_api_key(x_api_key: str = Header(default=None)):
    if not _API_KEY:
        return  # 개발 모드
    if x_api_key != _API_KEY:
        raise HTTPException(status_code=401, detail="유효하지 않은 API 키입니다.")


# ── 간단 레이트리밋 (인메모리, 프로세스 단위) ────────────────────────────────
# 외부 의존성 없이 IP별 슬라이딩 윈도우로 제한한다. 다중 워커/서버 환경에서는
# 공유 저장소 기반으로 교체 필요(현재 데모 규모에는 충분).
_RATE_WINDOW_SECONDS = 60
_RATE_LIMIT_DEFAULT = 60      # 일반 요청: 분당 60회
_RATE_LIMIT_VISION = 10       # Vision(비용 큰 요청): 분당 10회
_rate_buckets: dict = defaultdict(deque)


def _rate_limited(key: str, limit: int) -> bool:
    now = time.monotonic()
    bucket = _rate_buckets[key]
    while bucket and now - bucket[0] > _RATE_WINDOW_SECONDS:
        bucket.popleft()
    if len(bucket) >= limit:
        return True
    bucket.append(now)
    return False


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    path = request.url.path
    if path.startswith(("/parse-command", "/vision-mapping", "/device-profile")):
        client_ip = request.client.host if request.client else "unknown"
        limit = _RATE_LIMIT_VISION if path.startswith("/vision-mapping") else _RATE_LIMIT_DEFAULT
        if _rate_limited(f"{client_ip}:{'v' if limit == _RATE_LIMIT_VISION else 'd'}", limit):
            logger.warning("rate_limited ip=%s path=%s", client_ip, path)
            return JSONResponse(
                status_code=429,
                content={"detail": "요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요."},
            )
    return await call_next(request)


# Gemini AI 설정
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
_MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")

# 음성 명령 해석용: 전자레인지 시스템 프롬프트를 system_instruction으로.
# (이전에는 get_interpret_prompt("")로 빈 '사용자 입력: ""' 꼬리까지 들어갔다.)
ai_model = genai.GenerativeModel(
    model_name=_MODEL_NAME,
    system_instruction=MICROWAVE_SYSTEM_PROMPT,
)

# Vision 매핑용: 명령 JSON 스키마 지시가 vision 프롬프트와 충돌하지 않도록
# system_instruction 없는 별도 모델을 쓴다.
vision_model = genai.GenerativeModel(model_name=_MODEL_NAME)


@app.middleware("http")
async def request_logging_middleware(request, call_next):
    request_id = str(uuid.uuid4())[:8]
    start = time.perf_counter()
    logger.info("request.start id=%s method=%s path=%s", request_id, request.method, request.url.path)
    try:
        response = await call_next(request)
    except Exception:
        elapsed = int((time.perf_counter() - start) * 1000)
        logger.exception("request.error id=%s elapsed_ms=%d", request_id, elapsed)
        raise
    elapsed = int((time.perf_counter() - start) * 1000)
    logger.info(
        "request.end id=%s status=%s elapsed_ms=%d",
        request_id,
        response.status_code,
        elapsed,
    )
    return response


@app.get("/")
async def root():
    return {
        "service": "touch_bridge_backend",
        "status": "ok",
        "docs": "/docs",
        "health": "/healthz",
    }


@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


@app.get("/device-profile/{device_id}", dependencies=[Depends(require_api_key)])
async def fetch_profile(device_id: str):
    """기기 ID(QR/NFC)로 등록된 매핑 프로필 가져오기"""
    profile = await get_device_profile(device_id)
    if not profile:
        raise HTTPException(status_code=404, detail="등록되지 않은 기기입니다.")
    return profile


def _interpret_with_ai_sync(text: str):
    """Gemini를 사용하여 텍스트를 앱 명령 JSON으로 변환 (동기 — to_thread로 호출)"""
    try:
        response = ai_model.generate_content(f"사용자 입력: \"{text}\"")
        if not response.text:
            raise ValueError("Empty response from AI")

        json_str = response.text.strip().replace('```json', '').replace('```', '')
        # AI 응답은 신뢰할 수 없는 입력이다: 사용자 발화에 섞인 주입 지시가
        # message(TTS 낭독)나 needs_confirmation(확인 우회)을 오염시킬 수 있어
        # 서버에서 스키마를 강제한다.
        return sanitize_command_response(json.loads(json_str))
    except Exception as e:
        err_msg = str(e)
        logger.error("AI 해석 오류: %s", err_msg)

        # 할당량 초과 시 구체적인 메시지 제공
        if "exhausted" in err_msg.lower() or "429" in err_msg:
            message = "죄송합니다. 현재 AI 서비스 사용량이 많아 잠시 후 다시 이용해 주세요."
        else:
            message = "명령을 분석하는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
        return {
            "action": "NONE",
            "commands": [],
            "target": None,
            "inferred_seconds": 0,
            "confidence": 0.0,
            "needs_confirmation": False,
            "message": message,
        }


class CommandRequest(BaseModel):
    text: str


@app.post("/parse-command", dependencies=[Depends(require_api_key)])
async def parse_command(req: CommandRequest):
    text = req.text.strip()
    # 사용자 발화 원문은 개인정보일 수 있어 길이 제한 로그만 남긴다.
    logger.info("parse_command len=%d preview=%s", len(text), text[:20])
    if not text:
        return {"action": "NONE", "commands": [], "target": None, "message": "명령이 비어 있습니다."}

    # 1. 간단 규칙
    rule_result = check_simple_rules(text)
    if rule_result:
        return rule_result

    # 2. 음식 추론 (Heuristics)
    food_result = infer_food_command(text)
    if food_result:
        return food_result

    # 3. AI 해석 (Gemini) — 동기 SDK 호출이 이벤트 루프를 막지 않도록 스레드로.
    try:
        result = await asyncio.wait_for(
            asyncio.to_thread(_interpret_with_ai_sync, text), timeout=30
        )
    except asyncio.TimeoutError:
        logger.error("parse_command AI timeout")
        result = {
            "action": "NONE",
            "commands": [],
            "target": None,
            "inferred_seconds": 0,
            "confidence": 0.0,
            "needs_confirmation": False,
            "message": "분석 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.",
        }
    result.setdefault("commands", [])
    result.setdefault("target", None)
    result.setdefault("inferred_seconds", 0)
    result.setdefault("confidence", 0.5)
    result.setdefault("needs_confirmation", False)
    return result


# 업로드 상한 — Vision 입력은 사진 1장이면 충분하다.
_MAX_IMAGE_BYTES = 5 * 1024 * 1024


@app.post("/vision-mapping", dependencies=[Depends(require_api_key)])
async def vision_mapping(image: UploadFile = File(...)):
    # 주의: save_as_id 파라미터는 제거됨 — 무인증 프로필 덮어쓰기(임의 이미지로
    # 기존 기기의 시작↔취소 배치를 바꿔치기)가 가능했던 물리 안전 결함.
    # 프로필 저장이 필요해지면 별도의 인증된 관리자 경로로 추가할 것.
    image_bytes = await image.read()
    if len(image_bytes) > _MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="이미지가 너무 큽니다. 5MB 이하로 보내주세요.")

    # MIME 타입이 명확하지 않은 경우 기본값으로 보정
    mime_type = image.content_type
    if not mime_type or mime_type == "application/octet-stream":
        mime_type = "image/jpeg"

    prompt = """
이 이미지는 가전기기의 터치패드 사진입니다. 버튼들을 분석하여 rows×cols 그리드에 매핑해주세요.
반드시 아래 JSON 형식으로만 응답하세요:
{
  "grid": {"rows": 3, "cols": 3},
  "device_type": "전자레인지",
  "description": "분석된 기기 설명",
  "buttons": [
    {"row": 0, "col": 0, "button_id": "BT-05", "label": "시작"},
    ...
  ]
}
"""
    try:
        response = await asyncio.wait_for(
            asyncio.to_thread(
                vision_model.generate_content,
                [{"mime_type": mime_type, "data": image_bytes}, prompt],
            ),
            timeout=45,
        )

        if not response.text:
            logger.error("AI 응답이 비어있습니다.")
            raise HTTPException(status_code=500, detail="AI가 이미지를 분석하지 못했습니다. (빈 응답)")

        text = response.text.strip().replace('```json', '').replace('```', '')
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            logger.error("JSON 파싱 실패: %s", text[:200])
            raise HTTPException(status_code=500, detail="AI 응답 형식이 올바르지 않습니다.")

        return data
    except asyncio.TimeoutError:
        logger.error("Vision 분석 타임아웃")
        raise HTTPException(status_code=504, detail="이미지 분석 시간이 초과되었습니다.")
    except HTTPException:
        raise
    except Exception as e:
        err_msg = str(e)
        logger.error("Vision 오류: %s", err_msg)
        if "exhausted" in err_msg.lower() or "429" in err_msg:
            raise HTTPException(status_code=429, detail="AI 서비스 할당량을 모두 사용했습니다. 잠시 후 다시 시도해주세요.")
        raise HTTPException(status_code=500, detail="이미지 분석에 실패했습니다.")


@app.post("/voice-command")
async def process_voice(file: UploadFile = File(...)):
    raise HTTPException(
        status_code=503,
        detail="클라우드 경량 모드에서는 /voice-command를 지원하지 않습니다. "
               "앱에서 STT 후 /parse-command를 사용하세요.",
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
