from __future__ import annotations

import importlib
import unittest
from unittest.mock import patch


api_module = importlib.import_module("api.app")


class ApiBoundaryTests(unittest.TestCase):
    def setUp(self):
        with api_module.JOB_LOCK:
            api_module.JOBS.clear()

    def test_saved_endpoint_returns_labeled_model_result(self):
        result = api_module.saved_result("unilateral_10")
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["mode"], "saved model result")
        self.assertEqual(len(result["series"]), 132)

    def test_custom_paths_reach_async_worker_without_loss(self):
        tau21_path = [1.0, 1.05, 1.1]
        tau12_path = [1.0]
        payload = {
            "scenario": {
                "preset": "custom_path",
                "horizon": 80,
                "tau21Path": tau21_path,
                "tau12Path": tau12_path,
            }
        }
        with patch.object(api_module.EXECUTOR, "submit") as submit:
            response = api_module.create_job(payload)
        submitted_payload = submit.call_args.args[2]
        self.assertEqual(submitted_payload["scenario"]["tau21Path"], tau21_path)
        self.assertEqual(submitted_payload["scenario"]["tau12Path"], tau12_path)
        self.assertEqual(response["status"], "queued")


if __name__ == "__main__":
    unittest.main()
