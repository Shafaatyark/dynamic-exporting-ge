"""Run the downloadable unilateral-tariff example through the local solver."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from api.runner import RunnerError, run_simulation  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--request",
        type=Path,
        default=REPO_ROOT / "web" / "data" / "example_request.json",
        help="JSON request to solve.",
    )
    parser.add_argument("--output", type=Path, help="Optional output JSON file.")
    args = parser.parse_args()

    payload = json.loads(args.request.read_text(encoding="utf-8"))
    print("Starting the genuine MATLAB/Dynare example simulation...")
    try:
        result = run_simulation(payload, progress=lambda phase, message: print(f"[{phase}] {message}"))
    except RunnerError as exc:
        print(f"Simulation failed: {exc}", file=sys.stderr)
        return 1

    if args.output:
        args.output.write_text(json.dumps(result, indent=2, allow_nan=False), encoding="utf-8")
        print(f"Result written to {args.output.resolve()}")
    print(
        f"Simulation complete: {len(result['periods'])} periods, "
        f"{len(result['series'])} model series, engine={result.get('engine', 'unknown')}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
