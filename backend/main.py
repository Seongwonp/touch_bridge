import json
import os
import io
import librosa
import numpy as np
import torch
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
from transformers import MoonshineForConditionalGeneration, AutoProcessor
from dotenv import load_dotenv
import google.generativeai as genai

# .env 파일 로드
load_dotenv()

app = FastAPI()

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

# 전자레인지 버튼 규격 (3x3 그리드 기준)
# BT-01: 10초, BT-02: 30초, BT-03: 1분
# BT-04: 5분, BT-05: 시작, BT-06: 취소/정지
# BT-07: 해동, BT-08: 우유, BT-09: 자동조리
MICROWAVE_MAPPING = {
    "10초": "BT-01",
    "30초": "BT-02",
    "1분": "BT-03",
    "5분": "BT-04",
    "시작": "BT-05",
    "정지": "BT-06",
    "취소": "BT-06",
    "해동": "BT-07",
    "우유": "BT-08",
    "자동": "BT-09"
}

def check_simple_rules(text: str):
    """자주 쓰는 간단한 명령은 AI 없이 즉시 처리"""
    text = text.replace(" ", "")
    
    if "30초시작" in text or "삼십초시작" in text:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-02", "BT-05"],
            "message": "30초 조리를 시작합니다."
        }
    if "1분시작" in text or "일분시작" in text:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-03", "BT-05"],
            "message": "1분 조리를 시작합니다."
        }
    if "취소" in text or "정지" in text or "그만" in text:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-06"],
            "message": "조리를 중단합니다."
        }
    return None

def interpret_with_ai(text: str):
    """Gemini를 사용하여 텍스트를 앱 명령 JSON으로 변환"""
    prompt = f"""
    당신은 스마트 가전 제어 비서입니다. 
    사용자의 한국어 음성 인식 텍스트를 분석하여 명령 JSON으로 변환하세요.
    
    [전자레인지 규격 (3x3)]
    - BT-01: 10초 추가
    - BT-02: 30초 추가
    - BT-03: 1분 추가
    - BT-04: 5분 추가
    - BT-05: 시작
    - BT-06: 취소/정지
    - BT-07: 해동 모드
    - BT-08: 우유/데우기
    - BT-09: 자동 조리
    
    [명령 종류]
    1. MICROWAVE_CONTROL: 전자레인지 조작 (commands: 버튼 ID 리스트)
       예: "햇반 데워줘" -> 햇반은 700W 기준 2분, 1000W 기준 1분 30초입니다. 
           표준 2분으로 설정하여 ["BT-03", "BT-03", "BT-05"] 또는 ["BT-02", "BT-02", "BT-02", "BT-02", "BT-05"]
    2. EMERGENCY_STOP: 위험 상황 시 즉시 모든 기기 정지
    3. NAVIGATE: 화면 이동 (target: connection, mapping, settings)
    4. NONE: 이해할 수 없는 경우
    
    [응답 형식]
    반드시 아래와 같은 순수한 JSON 형식으로만 답변하세요:
    {{
        "action": "MICROWAVE_CONTROL" | "EMERGENCY_STOP" | "NAVIGATE" | "NONE",
        "commands": ["BT-xx", ...] | null,
        "target": "connection" | "mapping" | "settings" | null,
        "message": "사용자에게 들려줄 친절한 안내 메시지 (한국어)"
    }}
    
    사용자 입력: "{text}"
    """
    
    try:
        response = ai_model.generate_content(prompt)
        json_str = response.text.strip().replace('```json', '').replace('```', '')
        return json.loads(json_str)
    except Exception as e:
        print(f"AI 해석 오류: {e}")
        return {"action": "NONE", "message": "명령을 분석하는 중 오류가 발생했습니다."}


class CommandRequest(BaseModel):
    text: str


@app.post("/parse-command")
async def parse_command(req: CommandRequest):
    text = req.text.strip()
    if not text:
        return {"action": "NONE", "commands": [], "target": None, "message": "명령이 비어 있습니다."}

    rule_result = check_simple_rules(text)
    if rule_result:
        if "target" not in rule_result:
            rule_result["target"] = None
        if "commands" not in rule_result:
            rule_result["commands"] = []
        return rule_result

    result = interpret_with_ai(text)
    result.setdefault("commands", [])
    result.setdefault("target", None)
    result.setdefault("message", "명령을 분석했습니다.")
    return result


@app.post("/vision-mapping")
async def vision_mapping(image: UploadFile = File(...)):
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="이미지 파일만 허용됩니다.")

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="빈 이미지입니다.")

    prompt = """
이 이미지는 가전기기의 터치패드 사진입니다.
사진에 보이는 버튼들을 분석하여 3×3 그리드(row 0~2, col 0~2)에 매핑해주세요.
(0,0)은 왼쪽 위, (2,2)는 오른쪽 아래입니다.

반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트는 포함하지 마세요:
{
  "device_type": "전자레인지",
  "description": "전자레인지 터치패드입니다. 시작, 취소 등 6개 버튼을 인식했습니다.",
  "buttons": [
    {"row": 0, "col": 0, "label": "시작"},
    {"row": 0, "col": 1, "label": "취소"},
    {"row": 0, "col": 2, "label": "+30초"}
  ]
}
버튼이 없는 위치는 포함하지 마세요. 라벨은 간결한 한국어로 작성하세요.
"""

    try:
        response = ai_model.generate_content([
            {"mime_type": image.content_type, "data": image_bytes},
            prompt,
        ])
        text = (response.text or "").strip()
        if text.startswith("```json"):
            text = text[7:]
            text = text[:text.rfind("```")].strip()
        elif text.startswith("```"):
            text = text[3:]
            text = text[:text.rfind("```")].strip()
        data = json.loads(text)
    except Exception as e:
        print(f"vision_mapping error: {e}")
        raise HTTPException(status_code=500, detail="AI 이미지 분석에 실패했습니다.")

    return {
        "device_type": data.get("device_type", "기기"),
        "description": data.get("description", ""),
        "buttons": data.get("buttons", []),
    }

@app.post("/voice-command")
async def process_voice(file: UploadFile = File(...)):
    audio_bytes = await file.read()
    audio_data, _ = librosa.load(io.BytesIO(audio_bytes), sr=processor.feature_extractor.sampling_rate)
    
    inputs = processor(audio_data, return_tensors="pt", sampling_rate=processor.feature_extractor.sampling_rate)
    inputs = inputs.to(device, torch_dtype)
    
    token_limit_factor = 13 / processor.feature_extractor.sampling_rate
    seq_lens = inputs.attention_mask.sum(dim=-1)
    max_length = int((seq_lens * token_limit_factor).max().item())
    
    generated_ids = model.generate(**inputs, max_length=max_length)
    recognized_text = processor.decode(generated_ids[0], skip_special_tokens=True)
    
    print(f"인식된 텍스트: {recognized_text}")
    
    if not recognized_text.strip():
        return {"action": "NONE", "message": "음성이 인식되지 않았습니다."}

    # 1. 간단한 규칙 먼저 체크
    rule_result = check_simple_rules(recognized_text)
    if rule_result:
        rule_result["text"] = recognized_text
        return rule_result

    # 2. AI 해석
    result = interpret_with_ai(recognized_text)
    result["text"] = recognized_text
    
    return result

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
