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

# 음식 이름은 긴 것부터 대조한다 — "국밥"이 "밥"/"국"보다, "냉동만두"가
# "만두"보다 먼저 맞아야 한다. (dict 선언 순서에 의존하지 않는다.)
_FOOD_ITEMS_LONGEST_FIRST = sorted(
    FOOD_BASE_SECONDS.items(), key=lambda item: len(item[0]), reverse=True
)

# 한글 숫자 → 아라비아 숫자. "십일"=11, "삼십오"=35, "백이십"=120처럼 합성한다.
_KO_DIGIT = {'일': 1, '이': 2, '삼': 3, '사': 4, '오': 5, '육': 6, '칠': 7, '팔': 8, '구': 9}
_KO_UNIT = {'십': 10, '백': 100}
_KO_NUMERAL_RE = re.compile(r'([일이삼사오육칠팔구십백]+)(?=분|초)')


def _ko_numeral_to_int(word: str):
    """'십일'→11, '이십'→20, '삼십오'→35, '백'→100. 해석 불가면 None."""
    total = 0
    current = 0
    for ch in word:
        if ch in _KO_DIGIT:
            if current:
                return None  # "일이분" 같은 비문
            current = _KO_DIGIT[ch]
        elif ch in _KO_UNIT:
            unit = _KO_UNIT[ch]
            total += (current or 1) * unit
            current = 0
        else:
            return None
    return total + current


def normalize_korean_numbers(text: str) -> str:
    """분·초 앞의 한글 숫자를 아라비아 숫자로 바꾼다 ("십일분삼십초"→"11분30초")."""
    def repl(m):
        value = _ko_numeral_to_int(m.group(1))
        return m.group(1) if value is None else str(value)
    return _KO_NUMERAL_RE.sub(repl, text)


def normalize_text(text: str) -> str:
    normalized = text.replace(" ", "")
    for wrong, right in _TYPO_REPLACEMENTS:
        normalized = normalized.replace(wrong, right)
    return normalize_korean_numbers(normalized)


# 부정·거절 표현. 공백을 지운 문자열에서 토큰 포함 여부를 보면 "30초 동안 해줘"의
# "안해", "국에 밥 말아 데워줘"의 "말아"가 오탐된다(재리뷰 P2). 원문 어절 단위로
# 본다. 앱 `MicrowaveCommandService.hasNegation`과 같은 규칙.
_NEG_SUFFIX_RE = re.compile(
    r'(하지마|하지말|하지않|하지마세요|않을래|않을게|안할래|안할게|싫어|싫은데|말래|안돼|안되|않아|말고)(요|여|야)?$'
)
_NEG_PREFIX_RE = re.compile(r'^(안|못)(해|할|되|돼)')
_PUNCT_RE = re.compile(r'[.,!?~…]+')


def has_negation(text: str) -> bool:
    """실행을 막아야 하는 부정·거절 표현이 있는지 (원문 어절 기준).

    어절은 문장부호를 뗀 뒤 본다("시작하지마."). "만두말고"처럼 조사가 붙은 경우는
    어미 규칙(…말고)으로 잡는다.
    """
    words = [w for w in _PUNCT_RE.sub(" ", text).split() if w]
    for i, w in enumerate(words):
        if w in ("안", "못"):
            return True  # "안 할래", "못 해"
        if _NEG_PREFIX_RE.match(w):
            return True  # "안해줘", "못하겠어"
        if _NEG_SUFFIX_RE.search(w):
            return True  # "시작하지마", "안할래"
        if w == "말고":
            return True  # "만두 말고 밥"
        # "누르지 말아" — 앞 어절이 '지'로 끝날 때만 부정. "밥 말아 데워줘"는 아님.
        if (w.startswith("말아") or w.startswith("마세요") or w == "마") and i > 0 and words[i - 1].endswith("지"):
            return True
    return False


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
    
    # 소수 시간("1.5분")도 정확히 계산한다. "1.5분"에서 "5분"만 뽑던 오류(재리뷰).
    # 패턴 1: X분 Y초 (예: 7분 30초)
    match1 = re.search(r'(\d+(?:\.\d+)?)분(\d+(?:\.\d+)?)초', text)
    if match1:
        return int(round(float(match1.group(1)) * 60 + float(match1.group(2))))

    # 패턴 2: X분 (예: 5분, 1.5분)
    match2 = re.search(r'(\d+(?:\.\d+)?)분', text)
    if match2:
        return int(round(float(match2.group(1)) * 60))

    # 패턴 3: Y초 (예: 90초)
    match3 = re.search(r'(\d+(?:\.\d+)?)초', text)
    if match3:
        return int(round(float(match3.group(1))))

    # 한글 숫자는 normalize_text가 이미 아라비아 숫자로 바꿨다("십일분"→"11분").
    return None


# 무확인 실행을 허용하는 "시간 요청" 문법 전체. 정규화(공백 제거·오타 보정·한글 숫자
# 변환) 뒤의 문장이 이 정규식에 **전체 일치**할 때만 바로 실행한다. 그 외("1분 후
# 시작", "1분 설명 후 시작")는 시간이 보여도 확인을 받는다. 남은 글자 수로 판단하던
# 방식은 "후" 한 글자를 놓쳤다(재리뷰).
_TIME_TOKEN = r'(?:\d+(?:\.\d+)?분)?(?:\d+(?:\.\d+)?초)?'
_PLAIN_TIME_REQUEST_RE = re.compile(
    r'^(?P<time>' + _TIME_TOKEN + r')'
    r'(?:으로|로|만|동안|정도|쯤)?'
    r'(?:전자레인지)?'
    r'(?:데워주세요|데워줘|데워|데우자|시작해주세요|시작해줘|시작해|시작|조리해줘|조리|가열해줘|가열|해주세요|해줘|해)?'
    r'(?:요)?$'
)


def is_plain_time_request(normalized: str) -> bool:
    """정규화된 문장이 '시간 + 요청 어미'만으로 이루어졌는지."""
    m = _PLAIN_TIME_REQUEST_RE.match(normalized)
    return bool(m and m.group("time"))


def clamp_seconds(seconds: int) -> int:
    """설정 시간을 [10, MAX_SECONDS] 범위로 자른다."""
    return max(10, min(int(seconds), MAX_SECONDS))


def commands_total_seconds(commands) -> int:
    """버튼 시퀀스가 실제로 설정하는 초. 안내 문구와 inferred_seconds는 이 값을 쓴다
    ("5초 시작"은 10초 버튼이 눌리므로 5초라고 말하면 안 된다)."""
    table = {"BT-01": 10, "BT-02": 30, "BT-03": 60, "BT-04": 300}
    return sum(table.get(c, 0) for c in commands)

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
        clamped = clamp_seconds(explicit_seconds)
        commands = seconds_to_commands(clamped)
        actual = commands_total_seconds(commands)
        if explicit_seconds > MAX_SECONDS:
            # 상한을 넘는 요청은 자르되, 말한 시간과 달라지므로 확인을 받는다.
            return {
                "action": "MICROWAVE_CONTROL",
                "commands": commands,
                "inferred_seconds": actual,
                "confidence": 0.9,
                "needs_confirmation": True,
                "message": (
                    f"한 번에 {format_duration(MAX_SECONDS)}까지만 설정할 수 있습니다. "
                    f"{format_duration(actual)}으로 시작할까요?"
                ),
                "confirmation_message": f"알겠습니다. {format_duration(actual)} 조리를 시작할게요.",
            }
        # 지원 문법에 전체 일치하지 않는 문장("1분 후 시작", "1분 설명 후 시작")이나
        # 버튼 단위로 맞출 수 없는 시간("5초")은 바로 실행하지 않고 확인을 받는다.
        if not is_plain_time_request(t) or actual != explicit_seconds:
            return {
                "action": "MICROWAVE_CONTROL",
                "commands": commands,
                "inferred_seconds": actual,
                "confidence": 0.8,
                "needs_confirmation": True,
                "message": f"{format_duration(actual)}으로 시작할까요? 전자레인지 작동하면 될까요?",
                "confirmation_message": f"알겠습니다. {format_duration(actual)} 조리를 시작할게요.",
            }
        return {
            "action": "MICROWAVE_CONTROL",
            "commands": commands,
            "inferred_seconds": actual,
            "confidence": 1.0,
            "message": f"{format_duration(actual)} 설정을 시작합니다."
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
            # 사전에 "냉동…"으로 등록된 음식은 이미 냉동 기준 시간이다(재리뷰 P2:
            # 냉동피자 150초에 60초가 또 붙던 회귀).
            if "냉동" in t and not food.startswith("냉동"):
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
            commands = seconds_to_commands(seconds)
            seconds = commands_total_seconds(commands)
            return {
                "action": "MICROWAVE_CONTROL",
                "commands": commands,
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

# "<시간>시작(해/해줘/해라/해주세요)" 전체 일치. 시간 자리는 분·초 표현만 허용한다
# — `.+?`로 두면 "1분 설명 후 시작"도 시간 규칙에 걸린다(재리뷰 P1). 부분 문자열
# 대조는 "11분시작"이 "1분시작"에 걸리는 오류가 있었다. 한글 숫자는 normalize_text가
# 미리 숫자로 바꾼다("십일분"→"11분").
_TIMED_START_RE = re.compile(
    r'^(?P<time>(?:\d+(?:\.\d+)?분)?(?:\d+(?:\.\d+)?초)?)(?:으로|로|만|동안)?시작(?:해|해줘|해라|해주세요|해주라|하자)?$'
)


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
    if timed and timed.group("time"):
        seconds = parse_time_from_text(timed.group("time"))
        if seconds and seconds > 0:
            clamped = clamp_seconds(seconds)
            commands = seconds_to_commands(clamped)
            actual = commands_total_seconds(commands)
            if seconds > MAX_SECONDS or actual != seconds:
                # 상한 초과 또는 버튼 단위로 맞출 수 없는 시간("5초 시작"→10초):
                # 말한 시간과 달라지므로 확인을 받는다.
                return {
                    "action": "MICROWAVE_CONTROL",
                    "commands": commands,
                    "inferred_seconds": actual,
                    "confidence": 0.9,
                    "needs_confirmation": True,
                    "message": (
                        (f"한 번에 {format_duration(MAX_SECONDS)}까지만 설정할 수 있습니다. "
                         if seconds > MAX_SECONDS else "")
                        + f"{format_duration(actual)}으로 시작할까요?"
                    ),
                    "confirmation_message": f"알겠습니다. {format_duration(actual)} 조리를 시작할게요.",
                }
            return {
                "action": "MICROWAVE_CONTROL",
                "commands": commands,
                "inferred_seconds": actual,
                "confidence": 0.99,
                "message": f"{format_duration(actual)} 조리를 시작합니다."
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
