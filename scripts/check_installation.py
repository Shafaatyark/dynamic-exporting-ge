"""Check a local MATLAB/Dynare installation without modifying the machine."""

from __future__ import annotations

import argparse
import glob
import importlib.util
import json
import os
import platform
import re
import shutil
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


MINIMUM_DYNARE_VERSION = "7.1"


@dataclass(frozen=True)
class Discovery:
    available: bool
    path: str | None
    source: str
    version: str | None = None
    certified: bool | None = None


def _first_existing_file(candidates: Iterable[tuple[str, str]]) -> Discovery:
    for candidate, source in candidates:
        path = Path(candidate).expanduser()
        if path.is_file():
            return Discovery(True, str(path.resolve()), source)
    return Discovery(False, None, "not found")


def _first_dynare_dir(candidates: Iterable[tuple[str, str]]) -> Discovery:
    existing: list[tuple[Path, str]] = []
    for candidate, source in candidates:
        path = Path(candidate).expanduser()
        if path.is_dir() and (path / "dynare.m").is_file():
            existing.append((path.resolve(), source))
    if not existing:
        return Discovery(False, None, "not found", certified=False)

    supported = [item for item in existing if _is_supported_dynare(_version_from_dynare_path(item[0]))]
    pool = supported or existing
    path, source = max(pool, key=lambda item: _version_key(_version_from_dynare_path(item[0])))
    version = _version_from_dynare_path(path)
    return Discovery(
        True,
        str(path),
        source,
        version=version,
        certified=_is_supported_dynare(version),
    )


def _version_from_dynare_path(path: Path) -> str | None:
    for part in reversed(path.parts):
        if part and part[0].isdigit() and any(character == "." for character in part):
            return part
    version_file = path / "dynare_version.m"
    if version_file.is_file():
        match = re.search(r"v\s*=\s*['\"]([^'\"]+)['\"]", version_file.read_text(encoding="utf-8"))
        if match:
            return match.group(1)
    return None


def _version_key(version: str | None) -> tuple[int, ...]:
    return tuple(int(part) for part in re.findall(r"\d+", version or "")) or (0,)


def _is_supported_dynare(version: str | None) -> bool:
    return bool(version) and "unstable" not in version.lower() and _version_key(version) >= _version_key(MINIMUM_DYNARE_VERSION)


def find_matlab() -> Discovery:
    candidates: list[tuple[str, str]] = []
    configured = os.environ.get("DEGE_MATLAB_EXE")
    if configured:
        candidates.append((configured, "DEGE_MATLAB_EXE"))
    on_path = shutil.which("matlab")
    if on_path:
        candidates.append((on_path, "PATH"))

    system = platform.system()
    patterns: list[str]
    if system == "Windows":
        patterns = [r"C:\Program Files\MATLAB\R*\bin\matlab.exe"]
    elif system == "Darwin":
        patterns = ["/Applications/MATLAB_R*.app/bin/matlab"]
    else:
        patterns = ["/usr/local/MATLAB/R*/bin/matlab", "/opt/MATLAB/R*/bin/matlab"]
    for pattern in patterns:
        for path in sorted(glob.glob(pattern), reverse=True):
            candidates.append((path, "common install location"))
    return _first_existing_file(candidates)


def find_octave() -> Discovery:
    candidates: list[tuple[str, str]] = []
    configured = os.environ.get("DEGE_OCTAVE_EXE")
    if configured:
        candidates.append((configured, "DEGE_OCTAVE_EXE"))
    for command in ("octave-cli", "octave"):
        on_path = shutil.which(command)
        if on_path:
            candidates.append((on_path, "PATH"))
    return _first_existing_file(candidates)


def find_dynare() -> Discovery:
    candidates: list[tuple[str, str]] = []
    for variable in ("DEGE_DYNARE_PATH", "DYNARE_MATLAB_PATH"):
        configured = os.environ.get(variable)
        if configured:
            candidates.append((configured, variable))

    system = platform.system()
    patterns: list[str]
    if system == "Windows":
        patterns = [
            rf"C:\dynare\{MINIMUM_DYNARE_VERSION}\matlab",
            rf"C:\Program Files\Dynare\{MINIMUM_DYNARE_VERSION}\matlab",
            r"C:\dynare\*\matlab",
            r"C:\Program Files\Dynare\*\matlab",
        ]
    elif system == "Darwin":
        patterns = [
            f"/Applications/Dynare/{MINIMUM_DYNARE_VERSION}/matlab",
            "/Applications/Dynare/*/matlab",
            "/opt/homebrew/opt/dynare/lib/dynare/matlab",
        ]
    else:
        patterns = [
            "/usr/lib/dynare/matlab",
            "/usr/share/dynare/matlab",
            "/usr/local/lib/dynare/matlab",
            "/opt/dynare/*/matlab",
        ]
    for pattern in patterns:
        for path in sorted(glob.glob(pattern), reverse=True):
            candidates.append((path, "common install location"))
    return _first_dynare_dir(candidates)


def installation_report(engine: str = "matlab") -> dict[str, object]:
    matlab = find_matlab()
    octave = find_octave()
    dynare = find_dynare()
    python_ok = sys.version_info >= (3, 10)
    dependencies = {
        name: importlib.util.find_spec(name) is not None
        for name in ("fastapi", "uvicorn")
    }
    selected = matlab if engine == "matlab" else octave
    warnings: list[str] = []
    if dynare.available and not dynare.certified:
        warnings.append(
            f"Dynare {dynare.version or 'version unknown'} was found; Dynare {MINIMUM_DYNARE_VERSION} or newer is required."
        )
    return {
        "ready": python_ok and selected.available and dynare.available and bool(dynare.certified),
        "requestedEngine": engine,
        "python": {
            "available": python_ok,
            "path": sys.executable,
            "version": platform.python_version(),
        },
        "matlab": asdict(matlab),
        "octave": asdict(octave),
        "dynare": asdict(dynare),
        "apiDependencies": dependencies,
        "warnings": warnings,
    }


def print_report(report: dict[str, object]) -> None:
    print("Dynamic Exporting GE local installation check")
    print(f"Python 3.10+ : {'ready' if report['python']['available'] else 'missing'} ({report['python']['version']})")
    for key, title in (("matlab", "MATLAB"), ("octave", "GNU Octave"), ("dynare", "Dynare")):
        item = report[key]
        status = item["path"] if item["available"] else "not found"
        print(f"{title:<13}: {status}")
    dependencies = report["apiDependencies"]
    missing = [name for name, available in dependencies.items() if not available]
    print(f"Python API   : {'ready' if not missing else 'install needed (' + ', '.join(missing) + ')'}")
    for warning in report["warnings"]:
        print(f"Warning      : {warning}")
    print("Ready to run : " + ("yes" if report["ready"] else "no"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="Emit a machine-readable report.")
    parser.add_argument("--engine", choices=("matlab", "octave"), default="matlab")
    args = parser.parse_args()

    report = installation_report(args.engine)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print_report(report)
    return 0 if report["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
