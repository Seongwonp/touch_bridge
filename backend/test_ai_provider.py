# backend/test_ai_provider.py
"""제공자 선택·학교 경로 해석 mock 테스트 — 외부 키/네트워크 없이 실행 가능.

실행: python -m unittest test_ai_provider -v  (backend/ 디렉토리에서)
"""

import unittest
from unittest import mock

import ai_provider
from microwave_logic import check_simple_rules
from school_gateway import SchoolGatewayConfig, SchoolGatewayError
from validation import ALLOWED_ACTIONS

VALID_CFG = SchoolGatewayConfig.from_env({
    "SCHOOL_API_KEY": "test-key",
    "SCHOOL_API_BASE_URL": "https://factchat-cloud.mindlogic.ai/v1/gateway",
    "SCHOOL_API_MODEL": "gemini-3.8-flash",
})


class ResolveProviderTest(unittest.TestCase):
    def test_default_is_google_for_backward_compat(self):
        self.assertEqual(ai_provider.resolve_provider({}), ("google", True))

    def test_school_is_accepted_case_insensitively(self):
        self.assertEqual(
            ai_provider.resolve_provider({"AI_PROVIDER": " School "}),
            ("school", True),
        )

    def test_unknown_value_is_flagged_not_silently_defaulted(self):
        provider, valid = ai_provider.resolve_provider({"AI_PROVIDER": "openai"})
        self.assertEqual(provider, "openai")
        self.assertFalse(valid)


class InterpretWithSchoolTest(unittest.TestCase):
    @mock.patch.object(ai_provider.school_gateway, "chat_text")
    def test_success_passes_through_sanitizer(self, chat_text):
        chat_text.return_value = (
            '```json\n'
            '{"action": "MICROWAVE_CONTROL", "commands": ["BT-02", "BT-05"],'
            ' "inferred_seconds": 30, "confidence": 0.9,'
            ' "message": "30초 조리를 시작합니다."}\n```'
        )

        result = ai_provider.interpret_with_school(VALID_CFG, "30초 데워줘")

        self.assertEqual(result["action"], "MICROWAVE_CONTROL")
        self.assertEqual(result["commands"], ["BT-02", "BT-05"])
        # 시스템 프롬프트가 함께 전달됐는지 확인.
        self.assertIn("system_prompt", chat_text.call_args.kwargs)
        self.assertTrue(chat_text.call_args.kwargs["system_prompt"])

    @mock.patch.object(ai_provider.school_gateway, "chat_text")
    def test_injected_garbage_is_sanitized(self, chat_text):
        # 프롬프트 주입으로 이상한 액션/버튼이 와도 sanitizer가 강등해야 한다.
        chat_text.return_value = (
            '{"action": "HACK", "commands": ["rm -rf", "BT-99x"],'
            ' "needs_confirmation": "false", "message": "x"}'
        )

        result = ai_provider.interpret_with_school(VALID_CFG, "테스트")

        self.assertIn(result["action"], ALLOWED_ACTIONS)
        self.assertEqual(result["action"], "NONE")
        self.assertEqual(result["commands"], [])

    @mock.patch.object(ai_provider.school_gateway, "chat_text")
    def test_gateway_failures_return_safe_response_without_commands(self, chat_text):
        # 어떤 실패든: 실행 명령 없음 + 사람 말 안내 + Google 우회 없음.
        for kind in ("auth", "rate_limit", "timeout", "network", "server",
                     "bad_response", "config"):
            chat_text.side_effect = SchoolGatewayError(kind, "detail")

            result = ai_provider.interpret_with_school(VALID_CFG, "테스트")

            self.assertEqual(result["action"], "NONE", kind)
            self.assertEqual(result["commands"], [], kind)
            self.assertFalse(result["needs_confirmation"], kind)
            self.assertTrue(result["message"], kind)

    @mock.patch.object(ai_provider.school_gateway, "chat_text")
    def test_bad_model_json_returns_safe_response(self, chat_text):
        chat_text.return_value = "이건 JSON이 아니에요"
        result = ai_provider.interpret_with_school(VALID_CFG, "테스트")
        self.assertEqual(result["action"], "NONE")
        self.assertEqual(result["commands"], [])

    def test_school_modules_never_import_google_sdk(self):
        # 구조적 보장: 학교 경로 모듈은 google SDK를 import하지 않는다 —
        # "실패 시 Google로 조용히 우회"가 코드상 불가능함을 회귀로 고정.
        import ast
        import inspect

        import school_gateway as sg_module

        for module in (ai_provider, sg_module):
            tree = ast.parse(inspect.getsource(module))
            imported = []
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    imported.extend(alias.name for alias in node.names)
                elif isinstance(node, ast.ImportFrom):
                    imported.append(node.module or "")
            self.assertFalse(
                any("google" in name for name in imported),
                f"{module.__name__}가 google SDK를 import함: {imported}",
            )


class VisionWithSchoolTest(unittest.TestCase):
    @mock.patch.object(ai_provider.school_gateway, "chat_vision")
    def test_success_passes_through_vision_sanitizer(self, chat_vision):
        chat_vision.return_value = (
            '{"grid": {"rows": 3, "cols": 3}, "device_type": "전자레인지",'
            ' "buttons": ['
            '  {"button_id": "BT-05", "label": "시작", "row": 1, "col": 1,'
            '   "x": 0.5, "y": 0.6, "confidence": 0.9},'
            '  {"button_id": "BT-06", "label": "저신뢰", "x": 0.1, "y": 0.1,'
            '   "confidence": 0.2}'
            ']}'
        )

        result = ai_provider.vision_with_school(
            VALID_CFG, prompt="p", image_bytes=b"img", mime_type="image/jpeg"
        )

        # 저신뢰 버튼은 sanitizer가 걸러야 한다 (기존 계약 유지).
        self.assertEqual([b["button_id"] for b in result["buttons"]], ["BT-05"])
        self.assertEqual(result["grid"], {"rows": 3, "cols": 3})

    @mock.patch.object(ai_provider.school_gateway, "chat_vision")
    def test_failure_raises_for_http_mapping(self, chat_vision):
        chat_vision.side_effect = SchoolGatewayError("rate_limit", "d", 429)
        with self.assertRaises(SchoolGatewayError):
            ai_provider.vision_with_school(
                VALID_CFG, prompt="p", image_bytes=b"img", mime_type="image/jpeg"
            )

    def test_gateway_error_http_mapping(self):
        cases = {
            "auth": 502,
            "rate_limit": 429,
            "timeout": 504,
            "server": 502,
            "bad_response": 502,
            "config": 503,
        }
        for kind, expected_status in cases.items():
            status, detail = ai_provider.gateway_error_to_http(
                SchoolGatewayError(kind, "d")
            )
            self.assertEqual(status, expected_status, kind)
            self.assertTrue(detail)


class RuleFirstRegressionTest(unittest.TestCase):
    def test_simple_rule_handles_canonical_phrase_without_ai(self):
        # "30초 시작"류는 규칙에서 끝난다 — main.py의 처리 순서
        # (규칙 → 음식 추론 → AI)에서 AI까지 내려가지 않음을 뒷받침하는 회귀.
        result = check_simple_rules("30초 시작")
        self.assertIsNotNone(result)
        self.assertEqual(result["action"], "MICROWAVE_CONTROL")
        self.assertIn("BT-05", result["commands"])


if __name__ == "__main__":
    unittest.main()
