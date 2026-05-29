import re

FOOD_BASE_SECONDS = {
    "냉동만두": 180,
    "만두": 120,
    "햇반": 120,
    "밥": 90,
    "우유": 60,
    "피자": 60,
    "국": 120,
    "반찬": 60,
    "해동": 300,
}

def parse_time_from_text(text: str):
    """문장에서 'X분 Y초' 패턴을 추출하여 초 단위로 반환"""
    text = text.replace(" ", "")
    
    # 패턴 1: X분 Y초 (예: 7분 30초)
    match1 = re.search(r'(\d+)분(\d+)초', text)
    if match1:
        return int(match1.group(1)) * 60 + int(match1.group(2))
    
    # 패턴 2: X분 (예: 5분)
    match2 = re.search(r'(\d+)분', text)
    if match2:
        return int(match2.group(1)) * 60
    
    # 패턴 3: Y초 (예: 90초)
    match3 = re.search(r'(\d+)초', text)
    if match3:
        return int(match3.group(1))
    
    # 한글 숫자 처리 (일분, 이분, 삼분...)
    ko_num = {'일': 1, '이': 2, '삼': 3, '사': 4, '오': 5, '육': 6, '칠': 7, '팔': 8, '구': 9, '십': 10}
    for k, v in ko_num.items():
        if f"{k}분" in text:
            m = v * 60
            # 뒤에 초가 더 있는지 확인
            sec_match = re.search(fr'{k}분(\d+)초', text)
            if sec_match:
                return m + int(sec_match.group(1))
            return m
            
    return None

def seconds_to_commands(seconds: int):
    if seconds <= 0:
        return []
    remain = seconds
    commands = []
    # 5분 단위 (BT-04)
    while remain >= 300:
        commands.append("BT-04")
        remain -= 300
    # 1분 단위 (BT-03)
    while remain >= 60:
        commands.append("BT-03")
        remain -= 60
    # 30초 단위 (BT-02)
    while remain >= 30:
        commands.append("BT-02")
        remain -= 30
    # 10초 단위 (BT-01)
    while remain >= 10:
        commands.append("BT-01")
        remain -= 10
        
    if not commands:
        commands.append("BT-01")
    commands.append("BT-05")  # 시작 버튼 추가
    return commands

def infer_food_command(text: str):
    t = text.replace(" ", "")
    
    # 0순위: 명시적인 시간이 포함되어 있는지 확인
    explicit_seconds = parse_time_from_text(text)
    if explicit_seconds and explicit_seconds > 0:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": seconds_to_commands(explicit_seconds),
            "inferred_seconds": explicit_seconds,
            "confidence": 1.0,
            "message": f"{explicit_seconds // 60}분 {explicit_seconds % 60}초 설정을 시작합니다."
        }

    for food, base in FOOD_BASE_SECONDS.items():
        if food in t:
            seconds = base
            if any(k in t for k in ["2인분", "두개", "많이", "듬뿍"]):
                seconds = int(seconds * 1.8)
            if any(k in t for k in ["조금", "약하게", "살짝"]):
                seconds = int(seconds * 0.6)
            if "냉동" in t and food != "냉동만두":
                seconds += 60
            
            if "해동" in t:
                return {
                    "action": "MICROWAVE_CONTROL",
                    "commands": ["BT-07", "BT-03", "BT-03", "BT-03", "BT-05"],
                    "inferred_seconds": 180,
                    "confidence": 0.95,
                    "message": "해동 모드로 3분간 작동합니다. 시작할게요."
                }
                
            seconds = max(10, min(seconds, 1200))
            return {
                "action": "MICROWAVE_CONTROL",
                "commands": seconds_to_commands(seconds),
                "inferred_seconds": seconds,
                "confidence": 0.85,
                "message": f"{food} 조리를 위해 {seconds // 60}분 {seconds % 60}초 설정해 시작할게요."
            }
    return None

def check_simple_rules(text: str):
    t = text.replace(" ", "")
    if any(k in t for k in ["30초시작", "삼십초시작"]):
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-02", "BT-05"],
            "inferred_seconds": 30,
            "confidence": 0.99,
            "message": "30초 조리를 시작합니다."
        }
    if any(k in t for k in ["1분시작", "일분시작"]):
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-03", "BT-05"],
            "inferred_seconds": 60,
            "confidence": 0.99,
            "message": "1분 조리를 시작합니다."
        }
    if any(k in t for k in ["취소", "정지", "그만", "멈춰"]):
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-06"],
            "inferred_seconds": 0,
            "confidence": 1.0,
            "message": "조리를 중단합니다."
        }
    
    # 단순 "시작" 또는 "돌려줘"인 경우 (기본 30초 설정)
    if t in ["시작", "시작해", "시작해줘", "돌려줘", "데워줘", "작동"]:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-02", "BT-05"],
            "inferred_seconds": 30,
            "confidence": 0.95,
            "message": "30초 기본 조리를 시작합니다."
        }
        
    return None
