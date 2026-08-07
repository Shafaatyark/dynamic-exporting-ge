from __future__ import annotations

import json
import unittest
from pathlib import Path
from unittest.mock import patch

from api.runner import normalize_request
from scripts import check_installation


REPO_ROOT = Path(__file__).resolve().parents[1]


class LocalSetupTests(unittest.TestCase):
    def test_configured_matlab_and_dynare_are_detected(self):
        matlab = check_installation.Discovery(True, "/software/matlab", "DEGE_MATLAB_EXE")
        dynare = check_installation.Discovery(
            True, "/software/dynare/6.4/matlab", "DEGE_DYNARE_PATH", "6.4", True
        )
        octave = check_installation.Discovery(False, None, "not found")
        with (
            patch.object(check_installation, "find_matlab", return_value=matlab),
            patch.object(check_installation, "find_dynare", return_value=dynare),
            patch.object(check_installation, "find_octave", return_value=octave),
        ):
            report = check_installation.installation_report("matlab")

        self.assertTrue(report["ready"])
        self.assertEqual(report["matlab"]["source"], "DEGE_MATLAB_EXE")
        self.assertEqual(report["dynare"]["version"], "6.4")
        self.assertTrue(report["dynare"]["certified"])

    def test_noncertified_dynare_version_is_reported(self):
        path = Path("/software/dynare/7.1/matlab")
        self.assertEqual(check_installation._version_from_dynare_path(path), "7.1")

    def test_downloadable_example_is_a_complete_unilateral_request(self):
        path = REPO_ROOT / "web" / "data" / "example_request.json"
        payload = json.loads(path.read_text(encoding="utf-8"))
        request = normalize_request(payload)
        self.assertEqual(request["scenario"]["preset"], "unilateral_10")
        self.assertEqual(request["scenario"]["horizon"], 80)
        self.assertEqual(request["variables"], ["*"])
        self.assertTrue(all(value == 1.1 for value in request["tariffPaths"]["tau21"]))
        self.assertTrue(all(value == 1.0 for value in request["tariffPaths"]["tau12"]))


if __name__ == "__main__":
    unittest.main()
