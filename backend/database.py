# backend/database.py
import os
import asyncio
import json
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ConnectionFailure
from dotenv import load_dotenv

load_dotenv()

MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017/")
DB_NAME = "touch_bridge"

client = AsyncIOMotorClient(MONGO_URI)
db = client[DB_NAME]
collection = db["device_profiles"]

# 인메모리 폴백 (DB 연결 실패 시 사용)
_MEMORY_DB = {}

async def init_db():
    """DB 연결 확인 및 인덱스 설정"""
    # 샘플 데이터 정의
    samples = [
        {
            "device_id": "MW-BASE-001",
            "device_type": "전자레인지",
            "description": "기본형 전자레인지 프로필",
            "grid": {"rows": 3, "cols": 3, "originX": 0, "originY": 0, "pitchX": 1, "pitchY": 1},
            "buttons": [
                {"button_id": "BT-01", "row": 2, "col": 0, "label": "10초"},
                {"button_id": "BT-02", "row": 2, "col": 1, "label": "30초"},
                {"button_id": "BT-03", "row": 2, "col": 2, "label": "1분"},
                {"button_id": "BT-05", "row": 0, "col": 0, "label": "시작"},
                {"button_id": "BT-06", "row": 0, "col": 1, "label": "취소"}
            ]
        },
        {
            "device_id": "MW-LUX-777",
            "device_type": "전자레인지",
            "description": "고급형 다기능 전자레인지",
            "grid": {"rows": 4, "cols": 3, "originX": 0, "originY": 0, "pitchX": 1.2, "pitchY": 1.2},
            "buttons": [
                {"button_id": "BT-01", "row": 3, "col": 0, "label": "10초"},
                {"button_id": "BT-02", "row": 3, "col": 1, "label": "30초"},
                {"button_id": "BT-03", "row": 3, "col": 2, "label": "1분"},
                {"button_id": "BT-04", "row": 2, "col": 0, "label": "5분"},
                {"button_id": "BT-07", "row": 1, "col": 0, "label": "해동"},
                {"button_id": "BT-08", "row": 1, "col": 1, "label": "우유"},
                {"button_id": "BT-05", "row": 0, "col": 0, "label": "시작"},
                {"button_id": "BT-06", "row": 0, "col": 1, "label": "취소"}
            ]
        }
    ]

    try:
        # 연결 확인
        await asyncio.wait_for(client.admin.command('ping'), timeout=2.0)
        print("MongoDB 연결 성공!")
        
        # device_id에 유니크 인덱스 생성
        await collection.create_index("device_id", unique=True)
        
        for sample in samples:
            await collection.update_one(
                {"device_id": sample["device_id"]},
                {"$setOnInsert": sample},
                upsert=True
            )
        print(f"샘플 데이터 {len(samples)}종 확인/삽입 완료.")
            
    except Exception as e:
        print(f"MongoDB 초기화 실패 (인메모리 모드 사용): {e}")
        for sample in samples:
            _MEMORY_DB[sample["device_id"]] = sample

async def get_device_profile(device_id: str):
    """기기 ID로 프로필 조회"""
    try:
        profile = await collection.find_one({"device_id": device_id}, {"_id": 0})
        if profile: return profile
    except Exception:
        pass
    
    return _MEMORY_DB.get(device_id)

async def save_device_profile(device_id, device_type, description, grid, buttons):
    """새로운 기기 프로필 저장"""
    profile = {
        "device_id": device_id,
        "device_type": device_type,
        "description": description,
        "grid": grid,
        "buttons": buttons
    }
    
    try:
        await collection.replace_one({"device_id": device_id}, profile, upsert=True)
        return True
    except Exception:
        _MEMORY_DB[device_id] = profile
        return True
