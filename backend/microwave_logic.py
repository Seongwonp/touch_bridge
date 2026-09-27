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

# 전자레인지 1회 설정 상한(초). validation.MAX_SECONDS와 같은 값이어야 한다.
MAX_SECONDS = 20 * 60

# 부정·취소 의도 토큰. 이 단어가 있으면 규칙/음식 추론은 실행 명령을 만들지
# 않는다 — "30초 시작하지마", "만두 말고 밥" 같은 문장을 부분 일치로 잘못
# 실행하던 문제. (취소·정지 자체는 별도 규칙이 먼저 처리한다.)
_NEGATION_TOKENS = ("하지마", "하지말", "말고", "말아", "안해", "안돼", "아니야", "아냐")

# 음식 이름은 긴 것부터 대조한다 — "국밥"이 "밥"/"국"보다, "냉동만두"가
# "만두"보다 먼저 맞아야 한다. (dict 선언 순서에 의존하지 않는다.)
_FOOD_ITEMS_LONGEST_FIRST = sorted(
    FOOD_BASE_SECONDS.items(), key=lambda item: len(item[0]), reverse=True
)

# 한글 숫자 (분·초 공용)
_KO_NUM = {
    '일': 1, '이': 2, '삼': 3, '사': 4, '오': 5, '육': 6, '칠': 7, '팔': 8, '구': 9,
    '십': 10, '이십': 20, '삼십': 30, '사십': 40, '오십': 50,
}


def normalize_text(text: str) -> str:
    normalized = text.replace(" ", "")
    for wrong, right in _TYPO_REPLACEMENTS:
        normalized = normalized.replace(wrong, right)
    return normalized


def has_negation(text: str) -> bool:
    """실행을 막아야 하는 부정·거절 표현이 있는지."""
    t = normalize_text(text)
    return any(token in t for token in _NEGATION_TOKENS)


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
    
    # 한글 숫자 처리 (일분, 이분, 삼십초...) — 긴 표현("삼십")부터 대조한다.
    for k, v in sorted(_KO_NUM.items(), key=lambda kv: len(kv[0]), reverse=True):
        if f"{k}분" in text:
            m = v * 60
            # 뒤에 초가 더 있는지 확인
            sec_match = re.search(fr'{k}분(\d+)초', text)
            if sec_match:
                return m + int(sec_match.group(1))
            return m
    for k, v in sorted(_KO_NUM.items(), key=lambda kv: len(kv[0]), reverse=True):
        if f"{k}초" in text:
            return v

    return None


def clamp_seconds(seconds: int) -> int:
    """설정 시간을 [10, MAX_SECONDS] 범위로 자른다."""
    return max(10, min(int(seconds), MAX_SECONDS))

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

    # 부정·거절 표현이 있으면 여기서 실행 명령을 만들지 않는다. 문맥 해석은
    # AI 경로에 맡긴다("만두 말고 밥 데워줘"처럼 뜻이 있는 문장도 있으므로).
    if has_negation(text):
        return None

    # 0순위: 명시적인 시간이 포함되어 있는지 확인
    explicit_seconds = parse_time_from_text(text)
    if explicit_seconds and explicit_seconds > 0:
        if explicit_seconds > MAX_SECONDS:
            # 상한을 넘는 요청은 자르되, 말한 시간과 달라지므로 확인을 받는다.
            clamped = clamp_seconds(explicit_seconds)
            return {
                "action": "MICROWAVE_CONTROL",
                "commands": seconds_to_commands(clamped),
                "inferred_seconds": clamped,
                "confidence": 0.9,
                "needs_confirmation": True,
                "message": (
                    f"한 번에 {format_duration(MAX_SECONDS)}까지만 설정할 수 있습니다. "
                    f"{format_duration(clamped)}으로 시작할까요?"
                ),
                "confirmation_message": f"알겠습니다. {format_duration(clamped)} 조리를 시작할게요.",
            }
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

    for food, base in _FOOD_ITEMS_LONGEST_FIRST:
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
                    "needs_confirmation": True,
                    "message": "해동 모드로 3분 조리를 시작할까요? 전자레인지 작동하면 될까요?",
                    "confirmation_message": "알겠습니다. 해동 모드로 3분 조리를 시작할게요.",
                }
                
            seconds = clamp_seconds(seconds)
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

# "<시간>시작(해/해줘/해라/해주세요)" 전체 일치. 부분 문자열 대조는
# "11분시작"이 "1분시작"에 걸리는 오류가 있었다.
_TIMED_START_RE = re.compile(r'^(?P<time>.+?)(?:으로|로)?시작(?:해|해줘|해라|해주세요|해주라|하자)?$')


def check_simple_rules(text: str):
    t = normalize_text(text)

    # 1) 취소·정지는 다른 어떤 규칙보다 먼저 본다. "1분 시작 취소"는 시작이 아니라 취소다.
    if any(k in t for k in ["취소", "정지", "그만", "멈춰"]):
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": ["BT-06"],
            "inferred_seconds": 0,
            "confidence": 1.0,
            "message": "조리를 중단합니다."
        }

    # 2) 부정·거절 표현("30초 시작하지마")은 규칙으로 실행하지 않는다.
    if has_negation(text):
        return None

    # 3) "<시간> 시작" — 문장 전체가 시간+시작 형태일 때만. 시간은 공용 파서로.
    timed = _TIMED_START_RE.match(t)
    if timed:
        seconds = parse_time_from_text(timed.group("time"))
        if seconds and seconds > 0:
            if seconds > MAX_SECONDS:
                clamped = clamp_seconds(seconds)
                return {
                    "action": "MICROWAVE_CONTROL",
                    "commands": seconds_to_commands(clamped),
                    "inferred_seconds": clamped,
                    "confidence": 0.9,
                    "needs_confirmation": True,
                    "message": (
                        f"한 번에 {format_duration(MAX_SECONDS)}까지만 설정할 수 있습니다. "
                        f"{format_duration(clamped)}으로 시작할까요?"
                    ),
                    "confirmation_message": f"알겠습니다. {format_duration(clamped)} 조리를 시작할게요.",
                }
            return {
                "action": "MICROWAVE_CONTROL",
                "commands": seconds_to_commands(seconds),
                "inferred_seconds": seconds,
                "confidence": 0.99,
                "message": f"{format_duration(seconds)} 조리를 시작합니다."
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
