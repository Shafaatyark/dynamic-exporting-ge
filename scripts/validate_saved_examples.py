"""Validate dimensions, values, catalogs, and tariffs in saved examples."""

from __future__ import annotations

import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from api.runner import load_saved_result  # noqa: E402


def _validate_tariffs(preset: str, result: dict) -> None:
    tau21 = result["tariffPaths"]["tau21"]
    tau12 = result["tariffPaths"]["tau12"]
    expected_path_length = result["scenario"]["horizon"] + 1
    if len(tau21) != expected_path_length or len(tau12) != expected_path_length:
        raise ValueError(f"{preset}: tariff paths do not contain the initial plus transition periods")
    if abs(tau21[0] - 1.0) > 1e-12 or any(abs(value - 1.1) > 1e-12 for value in tau21[1:]):
        raise ValueError(f"{preset}: Home gross tariff is not the saved 10% transition")
    expected_tau12 = 1.1 if preset == "bilateral_10" else 1.0
    if abs(tau12[0] - 1.0) > 1e-12 or any(abs(value - expected_tau12) > 1e-12 for value in tau12[1:]):
        raise ValueError(f"{preset}: Foreign gross tariff path is incorrect")


def main() -> None:
    catalogs = []
    for preset in ("unilateral_10", "bilateral_10"):
        result = load_saved_result(preset)
        if result.get("dynareVersion") != "7.1":
            raise ValueError(f"{preset}: saved result was not generated with Dynare 7.1")
        _validate_tariffs(preset, result)
        catalog = [item["name"] for item in result["variables"]]
        catalogs.append(catalog)
        print(f"{preset}: Dynare {result['dynareVersion']}, {len(result['periods'])} periods, {len(catalog)} complete finite series")
    if catalogs[0] != catalogs[1]:
        raise ValueError("Saved examples have different variable catalogs")


if __name__ == "__main__":
    main()
