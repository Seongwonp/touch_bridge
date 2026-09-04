import unittest

from validation import sanitize_vision_mapping_response


class VisionMappingValidationTest(unittest.TestCase):
    def test_keeps_only_unique_buttons_with_real_normalized_centers(self):
        result = sanitize_vision_mapping_response({
            "grid": {"rows": 3, "cols": 3},
            "buttons": [
                {"button_id": "BT-05", "label": "시작", "row": 1, "col": 1,
                 "x": 0.52, "y": 0.61, "confidence": 0.94},
                {"button_id": "BT-05", "label": "중복", "row": 0, "col": 0,
                 "x": 0.1, "y": 0.1, "confidence": 1.0},
                {"button_id": "BT-06", "label": "좌표 없음", "row": 2, "col": 2},
                {"button_id": "BT-07", "label": "낮은 신뢰도", "row": 2, "col": 0,
                 "x": 0.2, "y": 0.8, "confidence": 0.3},
                {"button_id": "INVALID", "label": "잘못된 ID", "x": 0.2,
                 "y": 0.2, "confidence": 0.8},
            ],
        })

        self.assertEqual(len(result["buttons"]), 1)
        self.assertEqual(result["buttons"][0]["button_id"], "BT-05")
        self.assertEqual(result["buttons"][0]["x"], 0.52)

    def test_rejects_out_of_range_centers_and_clamps_metadata(self):
        result = sanitize_vision_mapping_response({
            "grid": {"rows": 1000, "cols": -2},
            "buttons": [
                {"button_id": "BT-01", "x": 1.2, "y": 0.5,
                 "confidence": 4.0},
                {"button_id": "BT-02", "x": 0.2, "y": 0.5,
                 "row": 999, "col": -3, "confidence": 4.0},
            ],
        })

        self.assertEqual(result["grid"], {"rows": 20, "cols": 1})
        self.assertEqual([b["button_id"] for b in result["buttons"]], ["BT-02"])
        self.assertEqual(result["buttons"][0]["row"], 19)
        self.assertEqual(result["buttons"][0]["col"], 0)
        self.assertEqual(result["buttons"][0]["confidence"], 1.0)

    def test_rejects_non_finite_numbers(self):
        result = sanitize_vision_mapping_response({
            "buttons": [
                {"button_id": "BT-01", "x": float("nan"), "y": 0.2, "confidence": 0.9},
                {"button_id": "BT-02", "x": 0.1, "y": 0.2, "confidence": float("nan")},
            ]
        })

        self.assertEqual(result["buttons"], [])


if __name__ == "__main__":
    unittest.main()
