from __future__ import annotations

import json
import math
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from api.runner import (  # noqa: E402
    RunnerError,
    load_saved_result,
    metadata,
    model_fingerprint,
    normalize_request,
    request_cache_key,
    validate_result,
)


class RequestValidationTests(unittest.TestCase):
    def test_unilateral_preset_constructs_home_path_only(self):
        request = normalize_request({"scenario": {"preset": "unilateral_10", "horizon": 3}})
        self.assertEqual(request["tariffPaths"]["tau21"], [1.1, 1.1, 1.1])
        self.assertEqual(request["tariffPaths"]["tau12"], [1.0, 1.0, 1.0])
        self.assertEqual(request["scenario"]["tariffScope"], "unilateral")

    def test_bilateral_preset_constructs_both_paths(self):
        request = normalize_request({"scenario": {"preset": "bilateral_10", "horizon": 2}})
        self.assertEqual(request["tariffPaths"]["tau21"], [1.1, 1.1])
        self.assertEqual(request["tariffPaths"]["tau12"], [1.1, 1.1])

    def test_custom_paths_are_preserved_exactly(self):
        request = normalize_request({"scenario": {
            "preset": "custom_path", "horizon": 3,
            "tau21Path": [1.0, 1.04, 1.08], "tau12Path": [1.0, 1.01, 1.02],
        }})
        self.assertEqual(request["tariffPaths"]["tau21"], [1.0, 1.04, 1.08])
        self.assertEqual(request["tariffPaths"]["tau12"], [1.0, 1.01, 1.02])

    def test_no_free_trade_transition_preset_exists(self):
        with self.assertRaises(RunnerError):
            normalize_request({"scenario": {"preset": "baseline"}})

    def test_custom_path_length_is_exact(self):
        with self.assertRaisesRegex(RunnerError, "exactly 3"):
            normalize_request({"scenario": {
                "preset": "custom_path", "horizon": 3,
                "tau21Path": [1.0], "tau12Path": [1.0],
            }})

    def test_categorical_switches_are_restricted(self):
        with self.assertRaisesRegex(RunnerError, "trade_bal"):
            normalize_request({"parameters": {"trade_bal": 8}})

    def test_trade_composition_shares_must_sum_to_one(self):
        with self.assertRaisesRegex(RunnerError, "must sum to one"):
            normalize_request({"parameters": {"Xshare": 0.4}})

    def test_all_series_request_serializes_stably(self):
        left = normalize_request({"scenario": {"horizon": 5}, "variables": ["*"]})
        right = normalize_request({"variables": ["*"], "scenario": {"horizon": 5}})
        fingerprint = model_fingerprint()
        self.assertEqual(request_cache_key(left, fingerprint), request_cache_key(right, fingerprint))
        json.dumps(left, allow_nan=False)


class SavedResultTests(unittest.TestCase):
    def test_metadata_covers_every_saved_solver_series(self):
        result = load_saved_result("unilateral_10")
        catalog = metadata()["variables"]
        self.assertEqual({item["name"] for item in catalog}, set(result["series"]))
        self.assertGreater(len(catalog), 100)

    def test_saved_examples_are_complete_and_finite(self):
        catalogs = []
        for preset in ("unilateral_10", "bilateral_10"):
            result = load_saved_result(preset)
            validate_result(result, require_complete=True)
            self.assertEqual(result["mode"], "saved model result")
            catalogs.append([item["name"] for item in result["variables"]])
            for series in result["series"].values():
                self.assertTrue(all(math.isfinite(value) for value in series["raw"]))
        self.assertEqual(catalogs[0], catalogs[1])

    def test_saved_tariff_paths_match_scenario_labels(self):
        unilateral = load_saved_result("unilateral_10")
        bilateral = load_saved_result("bilateral_10")
        self.assertEqual(unilateral["tariffPaths"]["tau21"][0], 1.0)
        self.assertTrue(all(value == 1.1 for value in unilateral["tariffPaths"]["tau21"][1:]))
        self.assertTrue(all(value == 1.0 for value in unilateral["tariffPaths"]["tau12"]))
        self.assertTrue(all(value == 1.1 for value in bilateral["tariffPaths"]["tau12"][1:]))

    def test_frontend_saved_files_load_with_matching_catalogs(self):
        names = []
        for filename in ("saved_unilateral_10.json", "saved_bilateral_10.json"):
            payload = json.loads((REPO_ROOT / "web" / "data" / filename).read_text(encoding="utf-8"))
            names.append([item["name"] for item in payload["variables"]])
            self.assertEqual(payload["status"], "ok")
        self.assertEqual(names[0], names[1])


if __name__ == "__main__":
    unittest.main()
