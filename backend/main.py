import json
import os
import io
import time
import uuid
import logging
import asyncio
import librosa
import numpy as np
import torch
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from transformers import MoonshineForConditionalGeneration, AutoProcessor
from dotenv import load_dotenv
import google.generativeai as genai

# 모듈화된 로직 임포트
from prompts import get_interpret_prompt
from microwave_logic import infer_food_command, check_simple_rules
from database import init_db, get_device_profile, save_device_profile

# .env 파일 로드
load_dotenv()

app = FastAPI()
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

# 1. Moonshine 모델 로드
print("AI 모델 로딩 중...")
model_id = 'UsefulSensors/moonshine-tiny-ko'
device = "cuda" if torch.cuda.is_available() else "cpu"
torch_dtype = torch.float16 if torch.cuda.is_available() else torch.float32

model = MoonshineForConditionalGeneration.from_pretrained(model_id).to(device).to(torch_dtype)
processor = AutoProcessor.from_pretrained(model_id)

# 2. Gemini AI 설정
genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))
ai_model = genai.GenerativeModel(os.getenv("GEMINI_MODEL", "gemini-3-flash-preview"))

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
    prompt = get_interpret_prompt(text)
    
    try:
        response = ai_model.generate_content(prompt)
        json_str = response.text.strip().replace('```json', '').replace('```', '')
        return json.loads(json_str)
    except Exception as e:
        logger.error(f"AI 해석 오류: {e}")
        return {
            "action": "NONE",
            "commands": [],
            "target": None,
            "inferred_seconds": 0,
            "confidence": 0.0,
            "needs_confirmation": False,
            "message": "명령을 분석하는 중 오류가 발생했습니다."
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
            asyncio.to_thread(ai_model.generate_content, [{"mime_type": image.content_type, "data": image_bytes}, prompt]),
            timeout=45
        )
        text = response.text.strip().replace('```json', '').replace('```', '')
        data = json.loads(text)
        
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
    except Exception as e:
        logger.error(f"Vision 오류: {e}")
        raise HTTPException(status_code=500, detail="이미지 분석 실패")

@app.post("/voice-command")
async def process_voice(file: UploadFile = File(...)):
    audio_bytes = await file.read()
    audio_data, _ = librosa.load(io.BytesIO(audio_bytes), sr=processor.feature_extractor.sampling_rate)
    
    inputs = processor(audio_data, return_tensors="pt", sampling_rate=processor.feature_extractor.sampling_rate)
    inputs = inputs.to(device, torch_dtype)
    
    generated_ids = model.generate(**inputs, max_length=128)
    recognized_text = processor.decode(generated_ids[0], skip_special_tokens=True)
    
    if not recognized_text.strip():
        return {"action": "NONE", "message": "음성이 인식되지 않았습니다."}

    # parse_command 로직 재사용
    req = CommandRequest(text=recognized_text)
    result = await parse_command(req)
    result["text"] = recognized_text
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
