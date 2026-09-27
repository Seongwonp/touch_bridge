"""규칙·음식 추론 경로의 안전 계약.

2026-09 외부 코드 리뷰에서 발견된 문제를 고정한다:
- 규칙/음식 추론 결과가 스키마 검증(sanitize)을 거치지 않아 "300분 데워줘"가
  61회 누름·확인 없음으로 통과했다.
- 시간 규칙이 부분 문자열 대조라 "11분 시작"이 "1분시작"에 걸려 1분이 됐다.
- 부정어("하지마")·취소("취소")가 붙어도 시작 규칙이 먼저 맞아 실행됐다.
- 음식 사전이 선언 순서라 "국밥"이 "밥"으로 매칭됐다.
"""

import unittest

from microwave_logic import (
    MAX_SECONDS,
    check_simple_rules,
    infer_food_command,
    parse_time_from_text,
)
from validation import MAX_COMMANDS, sanitize_command_response


def _route(text):
    """main.parse_command의 규칙→음식 순서를 sanitize까지 포함해 재현한다.

    (main.py는 fastapi/genai 의존이 있어 테스트 환경에서 import하지 않는다.)
    """
    rule = check_simple_rules(text)
    if rule:
        return sanitize_command_response(rule)
    food = infer_food_command(text)
    if food:
        return sanitize_command_response(food)
    return None


class TimeParsingTest(unittest.TestCase):
    def test_full_match_not_substring(self):
        self.assertEqual(_route("11분 시작")["inferred_seconds"], 660)
        self.assertEqual(_route("1분 시작")["inferred_seconds"], 60)
        self.assertEqual(_route("30초 시작")["inferred_seconds"], 30)
        self.assertEqual(_route("삼십초 시작")["inferred_seconds"], 30)
        self.assertEqual(_route("2분 30초 시작해줘")["inferred_seconds"], 150)

    def test_korean_seconds(self):
        self.assertEqual(parse_time_from_text("삼십초"), 30)
        self.assertEqual(parse_time_from_text("십초만"), 10)


class SafetyCapTest(unittest.TestCase):
    def test_over_cap_is_clamped_and_needs_confirmation(self):
        result = _route("300분 데워줘")
        self.assertEqual(result["inferred_seconds"], MAX_SECONDS)
        self.assertTrue(result["needs_confirmation"])
        self.assertLessEqual(len(result["commands"]), MAX_COMMANDS)
        self.assertEqual(result["commands"][-1], "BT-05")

    def test_over_cap_via_start_rule_also_confirms(self):
        result = _route("100분 시작")
        self.assertEqual(result["inferred_seconds"], MAX_SECONDS)
        self.assertTrue(result["needs_confirmation"])

    def test_every_rule_result_passes_schema(self):
        for text in ["30초 시작", "취소", "시작", "데워줘", "만두 데워줘", "5분 돌려줘"]:
            result = _route(text)
            self.assertIsNotNone(result, text)
            for key in ("action", "commands", "target", "inferred_seconds",
                        "confidence", "needs_confirmation", "message",
                        "confirmation_message"):
                self.assertIn(key, result, f"{text}: {key}")
            self.assertLessEqual(len(result["commands"]), MAX_COMMANDS)


class NegationAndCancelTest(unittest.TestCase):
    def test_negated_start_is_not_executed_by_rules(self):
        self.assertIsNone(check_simple_rules("30초 시작하지마"))
        self.assertIsNone(infer_food_command("30초 시작하지마"))
        self.assertIsNone(_route("만두 말고"))

    def test_cancel_wins_over_start(self):
        result = _route("1분 시작 취소")
        self.assertEqual(result["commands"], ["BT-06"])
        result = _route("30초 시작 그만")
        self.assertEqual(result["commands"], ["BT-06"])

    def test_plain_sentences_unaffected(self):
        # 부정어가 아닌 일반 문장은 그대로 규칙 처리된다.
        self.assertEqual(_route("30초 시작")["commands"], ["BT-02", "BT-05"])


class FoodDictionaryTest(unittest.TestCase):
    def test_longest_food_name_wins(self):
        self.assertEqual(_route("국밥 데워줘")["inferred_seconds"], 120)
        self.assertEqual(_route("냉동만두 데워줘")["inferred_seconds"], 180)
        self.assertEqual(_route("즉석밥 데워줘")["inferred_seconds"], 90)
        self.assertEqual(_route("편의점도시락 데워줘")["inferred_seconds"], 120)

    def test_food_inference_still_asks_confirmation(self):
        result = _route("만두 데워줘")
        self.assertTrue(result["needs_confirmation"])
        self.assertEqual(result["inferred_seconds"], 120)


if __name__ == "__main__":
    unittest.main()
