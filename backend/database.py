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

async def init_db():
    """DB 연결 확인 및 인덱스 설정"""
    try:
        # 연결 확인
        await client.admin.command('ping')
        print("MongoDB 연결 성공!")
        
        # device_id에 유니크 인덱스 생성
        await collection.create_index("device_id", unique=True)
        
        # 샘플 데이터 확인 및 삽입
        samples = [
            {
                "device_id": "MW-BASE-001",
                "device_type": "전자레인지",
                "description": "기본형 전자레인지 프로필 (MongoDB)",
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
            },
            {
                "device_id": "WM-DRUM-101",
                "device_type": "세탁기",
                "description": "드럼 세탁기 기본 프로필",
                "grid": {"rows": 2, "cols": 4, "originX": 10, "originY": 10, "pitchX": 2.0, "pitchY": 2.0},
                "buttons": [
                    {"button_id": "BT-05", "row": 0, "col": 0, "label": "전원/시작"},
                    {"button_id": "BT-06", "row": 0, "col": 1, "label": "일시정지"},
                    {"button_id": "BT-09", "row": 1, "col": 0, "label": "표준세탁"}
                ]
            }
        ]
        
        for sample in samples:
            await collection.update_one(
                {"device_id": sample["device_id"]},
                {"$setOnInsert": sample},
                upsert=True
            )
        print(f"샘플 데이터 {len(samples)}종 확인/삽입 완료.")
            
    except Exception as e:
        print(f"MongoDB 초기화 실패: {e}")
        print("주의: MongoDB가 실행 중이 아니면 로컬 테스트가 제한될 수 있습니다.")

async def get_device_profile(device_id: str):
    """기기 ID로 프로필 조회"""
    try:
        profile = await collection.find_one({"device_id": device_id}, {"_id": 0})
        return profile
    except Exception as e:
        print(f"조회 에러: {e}")
        return None

async def save_device_profile(device_id, device_type, description, grid, buttons):
    """새로운 기기 프로필 저장"""
    try:
        profile = {
            "device_id": device_id,
            "device_type": device_type,
            "description": description,
            "grid": grid,
            "buttons": buttons
        }
        await collection.replace_one({"device_id": device_id}, profile, upsert=True)
        return True
    except Exception as e:
        print(f"저장 에러: {e}")
        return False
