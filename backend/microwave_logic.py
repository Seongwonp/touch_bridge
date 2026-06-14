import re

FOOD_BASE_SECONDS = {
    "냉동만두": 180,
    "만두": 120,
    "즉석밥": 90,
    "햇반": 120,
    "밥": 90,
    "국밥": 120,
    "떡": 60,
    "빵": 30,
    "우유": 60,
    "피자": 60,
    "국": 120,
    "반찬": 60,
    "커피": 30,
    "해동": 300,
    "냉동피자": 150,
    "계란찜": 180,
    "고구마": 300,
    "감자": 300,
    "편의점도시락": 120,
    "도시락": 90,
    "삼각김밥": 30,
}

_TYPO_REPLACEMENTS = (
    ("대워", "데워"),
    ("데와", "데워"),
    ("덥혀", "데워"),
    ("따듯", "따뜻"),
    ("뜨겁게", "데워"),
    ("돌려", "데워"),
)


def normalize_text(text: str) -> str:
    normalized = text.replace(" ", "")
    for wrong, right in _TYPO_REPLACEMENTS:
        normalized = normalized.replace(wrong, right)
    return normalized


def format_duration(seconds: int) -> str:
    minutes, remainder = divmod(max(0, seconds), 60)
    parts = []
    if minutes:
        parts.append(f"{minutes}분")
    if remainder or not parts:
        parts.append(f"{remainder}초")
    return " ".join(parts)


def parse_time_from_text(text: str):
    """문장에서 'X분 Y초' 패턴을 추출하여 초 단위로 반환"""
    text = normalize_text(text)
    
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
    t = normalize_text(text)
    
    # 0순위: 명시적인 시간이 포함되어 있는지 확인
    explicit_seconds = parse_time_from_text(text)
    if explicit_seconds and explicit_seconds > 0:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": seconds_to_commands(explicit_seconds),
            "inferred_seconds": explicit_seconds,
            "confidence": 1.0,
            "message": f"{format_duration(explicit_seconds)} 설정을 시작합니다."
        }

    warming_intent = any(
        token in t
        for token in ["데워", "따뜻", "데우", "돌려", "중탕", "가열", "전자레인지"]
    )

    for food, base in FOOD_BASE_SECONDS.items():
        if food in t:
            seconds = base
            if any(k in t for k in ["2인분", "두개", "2개", "많이", "듬뿍", "둘", "3개", "세개"]):
                seconds = int(seconds * 1.8)
            if any(k in t for k in ["조금", "약하게", "살짝", "반만", "절반", "반개", "하나", "한개", "1개"]):
                seconds = int(seconds * 0.6)
            if "냉동" in t and food != "냉동만두":
                seconds += 60
            
            if "해동" in t:
                return {
                    "action": "MICROWAVE_CONTROL",
                    "commands": ["BT-07", "BT-03", "BT-03", "BT-03", "BT-05"],
                    "inferred_seconds": 180,
                    "confidence": 0.95,
                    "needs_confirmation": true,
                    "message": "해동 모드로 3분 조리를 시작할까요? 전자레인지 작동하면 될까요?",
                    "confirmation_message": "알겠습니다. 해동 모드로 3분 조리를 시작할게요.",
                }
                
            seconds = max(10, min(seconds, 1200))
            return {
                "action": "MICROWAVE_CONTROL",
                "commands": seconds_to_commands(seconds),
                "inferred_seconds": seconds,
                "confidence": 0.85,
                "needs_confirmation": True,
                "message": f"{food}은 {format_duration(seconds)}로 데워도 될까요? 전자레인지 작동하면 될까요?",
                "confirmation_message": f"알겠습니다. {food} 1개 {format_duration(seconds)} 조리를 시작할게요."
            }

    if warming_intent:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": [],
            "inferred_seconds": 0,
            "confidence": 0.62,
            "needs_confirmation": True,
            "message": "무엇을 데워드릴까요? 만두, 즉석밥, 우유처럼 음식 이름을 말씀해 주세요.",
        }

    return None

def check_simple_rules(text: str):
    t = normalize_text(text)
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
    if t in ["시작", "시작해", "시작해줘", "돌려줘", "작동"]:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-02", "BT-05"],
            "inferred_seconds": 30,
            "confidence": 0.95,
            "needs_confirmation": True,
            "message": "30초로 시작할까요? 전자레인지 작동하면 될까요?",
            "confirmation_message": "알겠습니다. 30초 조리를 시작할게요.",
        }

    if t in ["데워줘", "데워"]:
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": [],
            "inferred_seconds": 0,
            "confidence": 0.62,
            "needs_confirmation": True,
            "message": "무엇을 데워드릴까요? 만두, 즉석밥, 우유처럼 음식 이름을 말씀해 주세요.",
        }
        
    return None
