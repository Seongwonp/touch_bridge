import json
import os
import time
import uuid
import logging
import asyncio
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv
import google.generativeai as genai
from fastapi.middleware.cors import CORSMiddleware

# 모듈화된 로직 임포트
from prompts import get_interpret_prompt
from microwave_logic import infer_food_command, check_simple_rules
from database import init_db, get_device_profile, save_device_profile

# .env 파일 로드
load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logger = logging.getLogger("touch_bridge.backend")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s"
)

@app.on_event("startup")
async def startup_event():
    """서버 시작 시 DB 초기화"""
    await init_db()
    logger.info("Database initialized.")

# Gemini AI 설정
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
ai_model = genai.GenerativeModel(
    model_name=os.getenv("GEMINI_MODEL", "gemini-1.5-flash"),
    system_instruction=get_interpret_prompt("") # 시스템 프롬프트로 이동
)

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

@app.get("/device-profile/{device_id}")
async def fetch_profile(device_id: str):
    """기기 ID(QR/NFC)로 등록된 매핑 프로필 가져오기"""
    profile = await get_device_profile(device_id)
    if not profile:
        raise HTTPException(status_code=404, detail="등록되지 않은 기기입니다.")
    return profile

def interpret_with_ai(text: str):
    """Gemini를 사용하여 텍스트를 앱 명령 JSON으로 변환"""
    try:
        response = ai_model.generate_content(f"사용자 입력: \"{text}\"")
        if not response.text:
            raise ValueError("Empty response from AI")
            
        json_str = response.text.strip().replace('```json', '').replace('```', '')
        return json.loads(json_str)
    except Exception as e:
        err_msg = str(e)
        logger.error(f"AI 해석 오류: {err_msg}")
        
        # 할당량 초과 시 구체적인 메시지 제공
        if "exhausted" in err_msg.lower() or "429" in err_msg:
            return {
                "action": "NONE",
                "commands": [],
                "target": None,
                "inferred_seconds": 0,
                "confidence": 0.0,
                "needs_confirmation": False,
                "message": "죄송합니다. 현재 AI 서비스 사용량이 많아 잠시 후 다시 이용해 주세요."
            }
            
        return {
            "action": "NONE",
            "commands": [],
            "target": None,
            "inferred_seconds": 0,
            "confidence": 0.0,
            "needs_confirmation": False,
            "message": "명령을 분석하는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
        }

class CommandRequest(BaseModel):
    text: str

@app.post("/parse-command")
async def parse_command(req: CommandRequest):
    text = req.text.strip()
    logger.info("parse_command text=%s", text)
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

    # 3. AI 해석 (Gemini)
    result = interpret_with_ai(text)
    result.setdefault("commands", [])
    result.setdefault("target", None)
    result.setdefault("inferred_seconds", 0)
    result.setdefault("confidence", 0.5)
    result.setdefault("needs_confirmation", False)
    return result

@app.post("/vision-mapping")
async def vision_mapping(image: UploadFile = File(...), save_as_id: str = None):
    image_bytes = await image.read()
    
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
            asyncio.to_thread(ai_model.generate_content, [{"mime_type": mime_type, "data": image_bytes}, prompt]),
            timeout=45
        )
        
        if not response.text:
            logger.error("AI 응답이 비어있습니다.")
            raise HTTPException(status_code=500, detail="AI가 이미지를 분석하지 못했습니다. (빈 응답)")

        text = response.text.strip().replace('```json', '').replace('```', '')
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            logger.error(f"JSON 파싱 실패: {text}")
            raise HTTPException(status_code=500, detail="AI 응답 형식이 올바르지 않습니다.")
        
        # 만약 ID가 주어지면 DB에 저장
        if save_as_id:
            await save_device_profile(
                save_as_id, 
                data.get("device_type", "전자레인지"), 
                data.get("description", "AI 분석 프로필"),
                data.get("grid"),
                data.get("buttons")
            )
            
        return data
    except asyncio.TimeoutError:
        logger.error("Vision 분석 타임아웃")
        raise HTTPException(status_code=504, detail="이미지 분석 시간이 초과되었습니다.")
    except Exception as e:
        err_msg = str(e)
        logger.error(f"Vision 오류: {err_msg}")
        if "exhausted" in err_msg.lower() or "429" in err_msg:
            raise HTTPException(status_code=429, detail="AI 서비스 할당량을 모두 사용했습니다. 잠시 후 다시 시도해주세요.")
        raise HTTPException(status_code=500, detail=f"이미지 분석 실패: {err_msg}")

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
