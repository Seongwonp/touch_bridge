# backend/test_school_gateway.py
"""학교 API Gateway 클라이언트 mock 테스트 — 외부 키/네트워크 없이 실행 가능.

실행: python -m unittest test_school_gateway -v  (backend/ 디렉토리에서)
"""

import json
import unittest
from unittest import mock

import requests

import school_gateway
from school_gateway import SchoolGatewayConfig, SchoolGatewayError

FAKE_KEY = "test-key-should-never-leak"

VALID_ENV = {
    "SCHOOL_API_KEY": FAKE_KEY,
    "SCHOOL_API_BASE_URL": "https://factchat-cloud.mindlogic.ai/v1/gateway",
    "SCHOOL_API_MODEL": "gemini-3.8-flash",
}


def _response(status=200, payload=None, text_body=None):
    resp = mock.Mock(spec=requests.Response)
    resp.status_code = status
    if payload is not None:
        resp.json.return_value = payload
    else:
        resp.json.side_effect = ValueError("not json")
        resp.text = text_body or ""
    return resp


def _ok_payload(content="안녕하세요! 무엇을 도와드릴까요?", model="gemini-3.8-flash"):
    return {
        "model": model,
        "choices": [{"message": {"role": "assistant", "content": content}}],
    }


class ConfigTest(unittest.TestCase):
    def test_from_env_reads_and_normalizes(self):
        cfg = SchoolGatewayConfig.from_env({
            **VALID_ENV,
            "SCHOOL_API_BASE_URL": VALID_ENV["SCHOOL_API_BASE_URL"] + "/",
        })
        self.assertEqual(cfg.api_key, FAKE_KEY)
        # 끝 슬래시는 정규화된다 (chat/completions/ 경로 결합용)
        self.assertEqual(cfg.base_url, VALID_ENV["SCHOOL_API_BASE_URL"])
        self.assertEqual(cfg.text_model, "gemini-3.8-flash")
        # 사진 모델 미지정 시 텍스트 모델과 동일
        self.assertEqual(cfg.vision_model, "gemini-3.8-flash")
        self.assertEqual(cfg.missing_fields(), [])

    def test_vision_model_can_be_overridden(self):
        cfg = SchoolGatewayConfig.from_env({
            **VALID_ENV,
            "SCHOOL_API_VISION_MODEL": "vision-model-x",
        })
        self.assertEqual(cfg.vision_model, "vision-model-x")

    def test_missing_key_and_url_are_reported(self):
        cfg = SchoolGatewayConfig.from_env({})
        problems = cfg.missing_fields()
        self.assertIn("SCHOOL_API_KEY", problems)
        self.assertIn("SCHOOL_API_BASE_URL", problems)

    def test_http_url_is_rejected(self):
        # 키가 실리는 요청이므로 평문 http는 설정 오류로 거부한다.
        cfg = SchoolGatewayConfig.from_env({
            **VALID_ENV,
            "SCHOOL_API_BASE_URL": "http://factchat-cloud.mindlogic.ai/v1/gateway",
        })
        self.assertTrue(any("https" in p for p in cfg.missing_fields()))

    def test_model_defaults_to_gateway_verified_model(self):
        cfg = SchoolGatewayConfig.from_env({
            "SCHOOL_API_KEY": FAKE_KEY,
            "SCHOOL_API_BASE_URL": VALID_ENV["SCHOOL_API_BASE_URL"],
        })
        self.assertEqual(cfg.text_model, "gemini-3.8-flash")


class ChatTextTest(unittest.TestCase):
    def setUp(self):
        self.cfg = SchoolGatewayConfig.from_env(VALID_ENV)

    @mock.patch.object(school_gateway.requests, "post")
    def test_request_url_headers_and_payload(self, post):
        post.return_value = _response(payload=_ok_payload())

        school_gateway.chat_text(
            self.cfg, system_prompt="시스템 프롬프트", user_content='사용자 입력: "테스트"'
        )

        args, kwargs = post.call_args
        self.assertEqual(
            args[0],
            "https://factchat-cloud.mindlogic.ai/v1/gateway/chat/completions/",
        )
        self.assertEqual(kwargs["headers"]["Authorization"], f"Bearer {FAKE_KEY}")
        # 리다이렉트를 따라가면 인증 헤더가 다른 호스트로 샐 수 있다.
        self.assertFalse(kwargs["allow_redirects"])
        payload = kwargs["json"]
        self.assertEqual(payload["model"], "gemini-3.8-flash")
        self.assertFalse(payload["stream"])
        self.assertEqual(payload["messages"][0]["role"], "system")
        self.assertEqual(payload["messages"][0]["content"], "시스템 프롬프트")
        self.assertEqual(payload["messages"][1]["role"], "user")

    @mock.patch.object(school_gateway.requests, "post")
    def test_korean_utf8_content_round_trip(self, post):
        post.return_value = _response(
            payload=_ok_payload(content="만두는 보통 2분이면 괜찮아요.")
        )
        content = school_gateway.chat_text(
            self.cfg, system_prompt="s", user_content="만두"
        )
        self.assertEqual(content, "만두는 보통 2분이면 괜찮아요.")

    @mock.patch.object(school_gateway.requests, "post")
    def test_empty_choices_is_bad_response(self, post):
        post.return_value = _response(payload={"model": "m", "choices": []})
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(ctx.exception.kind, "bad_response")

    @mock.patch.object(school_gateway.requests, "post")
    def test_empty_content_is_bad_response(self, post):
        post.return_value = _response(
            payload={"choices": [{"message": {"content": "   "}}]}
        )
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(ctx.exception.kind, "bad_response")

    @mock.patch.object(school_gateway.requests, "post")
    def test_non_json_body_is_bad_response(self, post):
        post.return_value = _response(status=200, payload=None, text_body="<html>")
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(ctx.exception.kind, "bad_response")

    @mock.patch.object(school_gateway.requests, "post")
    def test_auth_failures(self, post):
        for status in (401, 403):
            post.return_value = _response(status=status, payload={})
            with self.assertRaises(SchoolGatewayError) as ctx:
                school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
            self.assertEqual(ctx.exception.kind, "auth")

    @mock.patch.object(school_gateway.requests, "post")
    def test_rate_limit(self, post):
        post.return_value = _response(status=429, payload={})
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(ctx.exception.kind, "rate_limit")

    @mock.patch.object(school_gateway.requests, "post")
    def test_server_error(self, post):
        post.return_value = _response(status=502, payload={})
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(ctx.exception.kind, "server")

    @mock.patch.object(school_gateway.requests, "post")
    def test_redirect_is_refused(self, post):
        post.return_value = _response(status=302, payload={})
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(ctx.exception.kind, "network")

    @mock.patch.object(school_gateway.requests, "post")
    def test_timeout_and_network(self, post):
        post.side_effect = requests.Timeout()
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(ctx.exception.kind, "timeout")

        post.side_effect = requests.ConnectionError()
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(ctx.exception.kind, "network")

    @mock.patch.object(school_gateway.requests, "post")
    def test_no_retry_on_failure(self, post):
        # 크레딧 차감·호출 제한이 있으므로 실패 시 재호출하지 않는다.
        post.return_value = _response(status=500, payload={})
        with self.assertRaises(SchoolGatewayError):
            school_gateway.chat_text(self.cfg, system_prompt="s", user_content="u")
        self.assertEqual(post.call_count, 1)

    @mock.patch.object(school_gateway.requests, "post")
    def test_error_messages_never_contain_key_or_user_text(self, post):
        post.return_value = _response(status=401, payload={})
        secret_utterance = "비밀 발화 내용"
        try:
            school_gateway.chat_text(
                self.cfg, system_prompt="s", user_content=secret_utterance
            )
            self.fail("expected SchoolGatewayError")
        except SchoolGatewayError as e:
            self.assertNotIn(FAKE_KEY, str(e))
            self.assertNotIn(secret_utterance, str(e))

    def test_config_error_does_not_call_network(self):
        bad = SchoolGatewayConfig.from_env({})
        with mock.patch.object(school_gateway.requests, "post") as post:
            with self.assertRaises(SchoolGatewayError) as ctx:
                school_gateway.chat_text(bad, system_prompt="s", user_content="u")
            self.assertEqual(ctx.exception.kind, "config")
            post.assert_not_called()


class ChatVisionTest(unittest.TestCase):
    def setUp(self):
        self.cfg = SchoolGatewayConfig.from_env({
            **VALID_ENV,
            "SCHOOL_API_VISION_MODEL": "gemini-vision-test",
        })

    @mock.patch.object(school_gateway.requests, "post")
    def test_vision_payload_uses_data_uri_and_vision_model(self, post):
        post.return_value = _response(payload=_ok_payload(content="{}"))

        school_gateway.chat_vision(
            self.cfg,
            prompt="버튼을 찾아줘",
            image_bytes=b"\xff\xd8fakejpeg",
            mime_type="image/jpeg",
        )

        payload = post.call_args.kwargs["json"]
        self.assertEqual(payload["model"], "gemini-vision-test")
        content = payload["messages"][0]["content"]
        self.assertEqual(content[0], {"type": "text", "text": "버튼을 찾아줘"})
        self.assertEqual(content[1]["type"], "image_url")
        url = content[1]["image_url"]["url"]
        self.assertTrue(url.startswith("data:image/jpeg;base64,"))


class ParseModelJsonTest(unittest.TestCase):
    def test_parses_fenced_json(self):
        data = school_gateway.parse_model_json(
            '```json\n{"action": "NONE", "message": "안녕하세요"}\n```'
        )
        self.assertEqual(data["message"], "안녕하세요")

    def test_invalid_json_raises_without_content_leak(self):
        with self.assertRaises(SchoolGatewayError) as ctx:
            school_gateway.parse_model_json("죄송해요, JSON이 아니에요: 비밀내용123")
        self.assertEqual(ctx.exception.kind, "bad_response")
        self.assertNotIn("비밀내용123", str(ctx.exception))

    def test_non_object_json_is_rejected(self):
        with self.assertRaises(SchoolGatewayError):
            school_gateway.parse_model_json(json.dumps(["list"]))


if __name__ == "__main__":
    unittest.main()
