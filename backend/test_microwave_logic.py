"""규칙·음식 추론 경로의 안전 계약 — 실제 API 핸들러(main.parse_command) 기준.

2026-09 외부 코드 리뷰(1차·재리뷰)에서 발견된 문제를 고정한다:
- 규칙/음식 추론 결과가 스키마 검증(sanitize)을 거치지 않아 "300분 데워줘"가
  61회 누름·확인 없음으로 통과했다. → 테스트는 라우팅을 재작성하지 않고
  main.parse_command를 직접 호출한다(운영 코드에서 sanitize가 빠지면 실패해야 한다).
- 시간 규칙이 부분 문자열 대조라 "11분 시작"→1분, "십일분"→1분, "일분 삼십초"→1분.
- 부정어("하지마", "안 할래")가 붙어도 시작 규칙이 실행됐고, 반대로 공백을 지운
  토큰 검사는 "30초 동안 해줘"(안해)·"밥 말아 데워줘"(말아)를 오탐했다.
- 음식 사전이 선언 순서라 "국밥"→"밥", 긴 이름 우선 뒤에는 "냉동피자"에 60초가 또 붙었다.
- "5초 시작"이 5초라고 답하면서 10초 버튼을 눌렀다.

규칙·음식 경로는 네트워크를 타지 않는다. AI 경로는 여기서 다루지 않는다.
"""

import asyncio
import unittest
from unittest.mock import patch

import main
from main import CommandRequest
from microwave_logic import (
    MAX_SECONDS,
    check_simple_rules,
    commands_total_seconds,
    has_negation,
    infer_food_command,
    normalize_korean_numbers,
    parse_time_from_text,
)
from validation import MAX_COMMANDS

_SCHEMA_KEYS = ("action", "commands", "target", "inferred_seconds",
                "confidence", "needs_confirmation", "message", "confirmation_message")


def route(text):
    """실제 FastAPI 핸들러를 호출한다 (규칙·음식 경로는 AI를 부르지 않는다)."""
    return asyncio.run(main.parse_command(CommandRequest(text=text)))


class ParseCommandSchemaTest(unittest.TestCase):
    def test_rule_and_food_results_pass_sanitizer(self):
        for text in ["30초 시작", "취소", "시작", "데워줘", "만두 데워줘", "5분 돌려줘", "300분 데워줘"]:
            result = route(text)
            for key in _SCHEMA_KEYS:
                self.assertIn(key, result, f"{text}: {key}")
            self.assertLessEqual(len(result["commands"]), MAX_COMMANDS, text)
            self.assertLessEqual(result["inferred_seconds"], MAX_SECONDS, text)

    def test_inferred_seconds_matches_buttons(self):
        for text in ["30초 시작", "11분 시작", "5초 시작", "만두 데워줘", "300분 데워줘", "2분 30초 시작"]:
            result = route(text)
            self.assertEqual(
                result["inferred_seconds"], commands_total_seconds(result["commands"]), text,
            )


class TimeParsingTest(unittest.TestCase):
    def test_full_match_not_substring(self):
        self.assertEqual(route("11분 시작")["inferred_seconds"], 660)
        self.assertEqual(route("1분 시작")["inferred_seconds"], 60)
        self.assertEqual(route("30초 시작")["inferred_seconds"], 30)
        self.assertEqual(route("2분 30초 시작해줘")["inferred_seconds"], 150)
        self.assertEqual(route("130초 시작")["inferred_seconds"], 130)

    def test_korean_numerals_compose(self):
        self.assertEqual(normalize_korean_numbers("십일분삼십초"), "11분30초")
        self.assertEqual(normalize_korean_numbers("삼십오초"), "35초")
        self.assertEqual(normalize_korean_numbers("백이십초"), "120초")
        self.assertEqual(parse_time_from_text("삼십초"), 30)
        self.assertEqual(parse_time_from_text("십일분"), 660)
        self.assertEqual(route("십일분 시작")["inferred_seconds"], 660)
        self.assertEqual(route("일분 삼십초 시작")["inferred_seconds"], 90)
        self.assertEqual(route("삼십초 시작")["commands"], ["BT-02", "BT-05"])

    def test_time_with_extra_context_asks_confirmation(self):
        for text in ["1분 설명 후 시작", "1분 후 시작", "1분 뒤에 시작해줘"]:
            result = route(text)
            self.assertTrue(result["needs_confirmation"], text)
            self.assertEqual(result["inferred_seconds"], 60, text)

    def test_plain_time_requests_execute_directly(self):
        for text in ["1분 시작", "5분 돌려줘", "30초 동안 해줘", "2분 데워줘", "1분 30초 시작해줘"]:
            self.assertFalse(route(text)["needs_confirmation"], text)

    def test_decimal_minutes_are_computed_exactly(self):
        result = route("1.5분 시작")
        self.assertEqual(result["inferred_seconds"], 90)
        self.assertEqual(result["commands"], ["BT-03", "BT-02", "BT-05"])
        self.assertFalse(result["needs_confirmation"])
        # 버튼으로 맞출 수 없는 소수 시간은 확인
        result = route("0.2분 시작")
        self.assertTrue(result["needs_confirmation"])
        self.assertEqual(result["inferred_seconds"], 10)

    def test_unrepresentable_seconds_ask_confirmation(self):
        result = route("5초 시작")
        self.assertTrue(result["needs_confirmation"])
        self.assertEqual(result["inferred_seconds"], 10)
        self.assertEqual(result["commands"], ["BT-01", "BT-05"])


class SafetyCapTest(unittest.TestCase):
    def test_over_cap_is_clamped_and_needs_confirmation(self):
        result = route("300분 데워줘")
        self.assertEqual(result["inferred_seconds"], MAX_SECONDS)
        self.assertTrue(result["needs_confirmation"])
        self.assertEqual(result["commands"][-1], "BT-05")

    def test_over_cap_via_start_rule_also_confirms(self):
        result = route("100분 시작")
        self.assertEqual(result["inferred_seconds"], MAX_SECONDS)
        self.assertTrue(result["needs_confirmation"])


class NegationAndCancelTest(unittest.TestCase):
    def test_negation_detection_by_word(self):
        for text in ["30초 시작하지마", "30초 시작하지마.", "1분 시작 안 할래", "만두 말고",
                     "만두말고 밥 데워줘", "3번 누르지 말아", "안해줘", "못 하겠어요"]:
            self.assertTrue(has_negation(text), text)
        for text in ["30초 동안 해줘", "국에 밥 말아 데워줘", "30초 시작", "만두 데워줘"]:
            self.assertFalse(has_negation(text), text)

    def test_negated_start_is_not_executed_by_rules_or_food(self):
        for text in ["30초 시작하지마", "30초 시작하지마.", "1분 시작 안 할래", "만두 말고", "만두말고 밥 데워줘"]:
            self.assertIsNone(check_simple_rules(text), text)
            self.assertIsNone(infer_food_command(text), text)

    def test_negated_sentence_goes_to_ai_path(self):
        # 실제 핸들러 기준: 부정 문장은 규칙·음식이 아니라 AI 경로로 간다. AI 호출은
        # mock으로 대체해 네트워크 없이 경로만 확인한다.
        sentinel = {"action": "NONE", "commands": [], "target": None, "inferred_seconds": 0,
                    "confidence": 0.0, "needs_confirmation": False,
                    "message": "AI-PATH", "confirmation_message": ""}
        with patch.object(main, "_interpret_with_ai_sync", return_value=sentinel) as ai:
            for text in ["30초 시작하지마.", "만두말고 밥 데워줘", "1분 시작 안 할래"]:
                result = route(text)
                self.assertEqual(result["message"], "AI-PATH", text)
            self.assertEqual(ai.call_count, 3)

    def test_false_positive_sentences_still_route(self):
        self.assertEqual(route("30초 동안 해줘")["inferred_seconds"], 30)
        result = route("국에 밥 말아 데워줘")
        self.assertEqual(result["action"], "MICROWAVE_CONTROL")
        self.assertTrue(result["needs_confirmation"])

    def test_cancel_wins_over_start(self):
        self.assertEqual(route("1분 시작 취소")["commands"], ["BT-06"])
        self.assertEqual(route("30초 시작 그만")["commands"], ["BT-06"])


class FoodDictionaryTest(unittest.TestCase):
    def test_longest_food_name_wins(self):
        self.assertEqual(route("국밥 데워줘")["inferred_seconds"], 120)
        self.assertEqual(route("냉동만두 데워줘")["inferred_seconds"], 180)
        self.assertEqual(route("즉석밥 데워줘")["inferred_seconds"], 90)
        self.assertEqual(route("편의점도시락 데워줘")["inferred_seconds"], 120)

    def test_frozen_prefix_is_not_double_counted(self):
        self.assertEqual(route("냉동피자 데워줘")["inferred_seconds"], 150)
        # 사전에 냉동 항목이 없는 음식은 냉동 보정 60초가 붙는다.
        self.assertEqual(route("냉동 떡 데워줘")["inferred_seconds"], 120)

    def test_food_inference_still_asks_confirmation(self):
        result = route("만두 데워줘")
        self.assertTrue(result["needs_confirmation"])
        self.assertEqual(result["inferred_seconds"], 120)


if __name__ == "__main__":
    unittest.main()
