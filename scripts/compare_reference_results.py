"""Compare every raw model series in two serialized solver results."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


def compare(reference_path: Path, candidate_path: Path, atol: float, rtol: float) -> None:
    reference = json.loads(reference_path.read_text(encoding="utf-8"))
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    ref_names = set(reference["series"])
    candidate_names = set(candidate["series"])
    if ref_names != candidate_names:
        raise ValueError(
            f"Variable mismatch: missing={sorted(ref_names - candidate_names)}, "
            f"extra={sorted(candidate_names - ref_names)}"
        )
    failures = []
    largest = (0.0, "")
    for name in sorted(ref_names):
        expected = reference["series"][name]["raw"]
        actual = candidate["series"][name]["raw"]
        if len(expected) != len(actual):
            failures.append(f"{name}: dimensions {len(expected)} != {len(actual)}")
            continue
        for period, (left, right) in enumerate(zip(expected, actual)):
            if not (math.isfinite(left) and math.isfinite(right)):
                failures.append(f"{name}[{period}]: non-finite value")
                continue
            error = abs(left - right)
            largest = max(largest, (error, f"{name}[{period}]"))
            if error > atol + rtol * abs(left):
                failures.append(f"{name}[{period}]: {right} vs {left} (abs error {error})")
    if failures:
        preview = "\n".join(failures[:20])
        raise ValueError(f"{len(failures)} comparisons exceeded tolerance:\n{preview}")
    print(f"All {len(ref_names)} raw series agree; largest absolute error {largest[0]:.3g} at {largest[1]}.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", type=Path, help="Trusted source MATLAB result JSON")
    parser.add_argument("candidate", type=Path, help="Public solver result JSON")
    parser.add_argument("--atol", type=float, default=1e-8)
    parser.add_argument("--rtol", type=float, default=1e-7)
    args = parser.parse_args()
    compare(args.reference, args.candidate, args.atol, args.rtol)


if __name__ == "__main__":
    main()
