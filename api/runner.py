"""Validation, execution, caching, and serialization for DEGE simulations.

The Python layer does not implement economic equations. It validates a
request, launches the MATLAB/Octave bridge in ``model/``, and verifies the
structured result returned by Dynare.
"""

from __future__ import annotations

import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path
from typing import Any, Callable


REPO_ROOT = Path(__file__).resolve().parents[1]
MODEL_ROOT = REPO_ROOT / "model"
SAVED_RESULTS_ROOT = REPO_ROOT / "web" / "data"
SOLUTION_HORIZON = 80
ProgressCallback = Callable[[str, str], None]


DEFAULT_PARAMETERS: dict[str, Any] = {
    "dynamic": 1,
    "trade_bal": 0,
    "free_entry": 1,
    "trade_comp": 1,
    "elast_labor": 1,
    "pref": 0,
    "Nx": 0.2,
    "churnx": 0.05,
    "churnn": 0.15,
    "GOVA": 2.0,
    "GOVAc": 2.0,
    "WLVA": 0.6,
    "RKVA": 0.165,
    "gdp": 1.0,
    "Lbar": 1.0,
    "IMY": 0.15,
    "Xshare": 0.2,
    "Mshare": 0.6,
    "Cshare": 0.2,
    "bet": 0.96,
    "del": 0.1,
    "sig": 1.001,
    "frisch": 2.0,
    "th": 6.0,
    "gam": 4.0,
    "bk": 0.2,
    "v": 0.6494047,
    "ns": 0.98,
    "ttL": 0.272,
    "ttK": 0.147,
    "sI": 0.0,
    "psi_fric": 0.4,
    "revsub": 0,
}


STRUCTURE_OPTIONS: dict[str, list[dict[str, Any]]] = {
    "dynamic": [
        {"value": 1, "label": "1 — Heterogeneous firms with exporter dynamics"},
        {"value": 0, "label": "0 — Representative firm"},
    ],
    "trade_bal": [
        {"value": 0, "label": "0 — Bonds with steady-state imbalances (benchmark)"},
        {"value": 1, "label": "1 — Bonds with balanced steady state"},
        {"value": 2, "label": "2 — Financial autarky with balanced trade"},
        {"value": 3, "label": "3 — Financial autarky with steady-state imbalances"},
    ],
    "free_entry": [
        {"value": 1, "label": "1 — Free entry (benchmark)"},
        {"value": 0, "label": "0 — Fixed entry"},
    ],
    "trade_comp": [
        {"value": 1, "label": "1 — Match trade composition targets"},
        {"value": 0, "label": "0 — Equal trade intensity across goods"},
    ],
    "elast_labor": [
        {"value": 1, "label": "1 — Elastic labor supply (benchmark)"},
        {"value": 0, "label": "0 — Nearly inelastic labor supply"},
    ],
    "pref": [
        {"value": 0, "label": "0 — Cobb–Douglas consumption and leisure (benchmark)"},
        {"value": 1, "label": "1 — MaCurdy preferences"},
        {"value": 2, "label": "2 — Boppart–Krusell preferences"},
    ],
    "revsub": [
        {"value": 0, "label": "0 — Standard markups (benchmark)"},
        {"value": 1, "label": "1 — Revenue subsidy offsets markups"},
    ],
}


PARAMETER_LABELS = {
    "gam": "Source substitution elasticity (γ)",
    "th": "Within-source variety elasticity (θ)",
    "bet": "Discount factor (β)",
    "del": "Capital depreciation rate (δ)",
    "sig": "Risk aversion (σ)",
    "frisch": "Frisch labor-supply elasticity (φ)",
    "bk": "Boppart–Krusell parameter (κ)",
    "v": "Fixed-cost distribution shape (ν)",
    "ns": "Firm survival rate (nₛ)",
    "Nx": "Exporter participation target (Nₓ)",
    "churnx": "Exporter churn target (χₓ)",
    "churnn": "Potential-exporter churn target (χₙ)",
    "GOVA": "Gross output to value added (GO/VA)",
    "GOVAc": "Consumption gross output to value added (GOᶜ/VA)",
    "WLVA": "Labor share of value added (wL/VA)",
    "RKVA": "Capital share target (rK/VA)",
    "gdp": "Relative GDP target (Y)",
    "Lbar": "Time endowment (L̄)",
    "IMY": "Imports-to-GDP target (IM/Y)",
    "Xshare": "Investment-goods export share (Xᵢ/X)",
    "Mshare": "Materials export share (Xₘ/X)",
    "Cshare": "Consumption-goods export share (X꜀/X)",
    "ttL": "Labor income tax rate (τₗ)",
    "ttK": "Capital income tax rate (τₖ)",
    "sI": "Investment subsidy rate (sᵢ)",
    "psi_fric": "Investment adjustment cost (ψ)",
    "dynamic": "Firm dynamics",
    "trade_bal": "Trade-balance regime",
    "free_entry": "Firm entry",
    "trade_comp": "Trade composition",
    "elast_labor": "Labor supply",
    "pref": "Household preferences",
    "revsub": "Markup treatment",
}


PARAMETER_ORDER = [
    "gam", "th", "bet", "del", "sig", "frisch", "bk", "v", "ns", "Nx",
    "churnx", "churnn", "GOVA", "GOVAc", "WLVA", "RKVA", "gdp",
    "Lbar", "IMY", "Xshare", "Mshare", "Cshare", "ttL", "ttK", "sI",
    "psi_fric", "dynamic", "trade_bal", "free_entry", "trade_comp",
    "elast_labor", "pref", "revsub",
]


PARAMETER_BOUNDS: dict[str, tuple[float | None, float | None, bool, bool]] = {
    "Nx": (0.0, 1.0, False, False),
    "churnx": (0.0, 1.0, False, False),
    "churnn": (0.0, 1.0, False, False),
    "GOVA": (1.0, None, False, False),
    "GOVAc": (1.0, None, False, False),
    "WLVA": (0.0, 1.0, False, False),
    "RKVA": (0.0, 1.0, True, False),
    "gdp": (0.0, None, False, False),
    "Lbar": (0.0, None, False, False),
    "IMY": (0.0, 1.0, False, False),
    "Xshare": (0.0, 1.0, True, True),
    "Mshare": (0.0, 1.0, True, True),
    "Cshare": (0.0, 1.0, True, True),
    "bet": (0.0, 1.0, False, False),
    "del": (0.0, 1.0, True, False),
    "sig": (0.0, None, False, False),
    "frisch": (0.0, None, False, False),
    "th": (1.0, None, False, False),
    "gam": (1.0, None, False, False),
    "bk": (0.0, 1.0, False, False),
    "v": (0.0, 1.0, False, False),
    "ns": (0.0, 1.0, False, False),
    "ttL": (-1.0, 1.0, False, False),
    "ttK": (-1.0, 1.0, False, False),
    "sI": (-1.0, 1.0, False, False),
    "psi_fric": (0.0, None, True, False),
}


SCENARIO_PRESETS = [
    {
        "id": "unilateral_10",
        "label": "Free trade to a 10% unilateral Home tariff",
        "description": "Raises τ₂₁ from 1.00 to 1.10 and keeps τ₁₂ at 1.00.",
        "savedResult": "saved_unilateral_10.json",
    },
    {
        "id": "bilateral_10",
        "label": "Free trade to a 10% bilateral tariff",
        "description": "Raises both τ₂₁ and τ₁₂ from 1.00 to 1.10.",
        "savedResult": "saved_bilateral_10.json",
    },
    {
        "id": "custom_path",
        "label": "Custom tariff paths",
        "description": "Uses explicit positive gross tariff paths supplied by the user.",
        "savedResult": None,
    },
]


REBATE_OPTIONS = [
    {"value": "lumpsum", "label": "Lump-sum transfer"},
    {"value": "invsub", "label": "Investment subsidy"},
    {"value": "labtax", "label": "Labor-tax reduction"},
    {"value": "captax", "label": "Capital-tax reduction"},
]


CORE_VARIABLES = ["tau21", "im1", "ex12"]
VARIABLE_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")


class RunnerError(RuntimeError):
    """Raised for safe request, engine, or result failures."""

    def __init__(self, message: str, *, job_id: str | None = None):
        super().__init__(message)
        self.job_id = job_id


def metadata() -> dict[str, Any]:
    parameters = []
    for name in PARAMETER_ORDER:
        item: dict[str, Any] = {
            "name": name,
            "label": PARAMETER_LABELS[name],
            "value": DEFAULT_PARAMETERS[name],
            "group": "structure" if name in STRUCTURE_OPTIONS else "parameters",
            "control": "select" if name in STRUCTURE_OPTIONS else "number",
        }
        if name in STRUCTURE_OPTIONS:
            item["options"] = STRUCTURE_OPTIONS[name]
        parameters.append(item)

    return {
        "parameters": parameters,
        "parameterDefaults": DEFAULT_PARAMETERS,
        "variables": saved_variable_catalog(),
        "defaultVariables": CORE_VARIABLES,
        "scenarioPresets": SCENARIO_PRESETS,
        "rebateOptions": REBATE_OPTIONS,
        "limits": {"solutionHorizon": SOLUTION_HORIZON},
        "notes": {
            "saved": "Saved examples are model results, not newly solved simulations.",
            "live": "Fresh simulations require the optional Octave/Dynare or MATLAB/Dynare API.",
        },
    }


def normalize_request(payload: dict[str, Any] | None) -> dict[str, Any]:
    if payload is not None and not isinstance(payload, dict):
        raise RunnerError("The request body must be a JSON object.")
    payload = payload or {}
    scenario_raw = payload.get("scenario") or {}
    parameters_raw = payload.get("parameters") or {}
    if not isinstance(scenario_raw, dict) or not isinstance(parameters_raw, dict):
        raise RunnerError("scenario and parameters must be JSON objects.")

    scenario = dict(scenario_raw)
    preset = str(scenario.get("preset", "unilateral_10")).strip()
    if preset not in {item["id"] for item in SCENARIO_PRESETS}:
        raise RunnerError(f"Unknown scenario preset: {preset}")

    horizon = _int_in_range(scenario.get("horizon", SOLUTION_HORIZON), "horizon", 1, 600)
    if horizon != SOLUTION_HORIZON:
        raise RunnerError(f"horizon is fixed at {SOLUTION_HORIZON} transition periods.")
    initial_tau21 = _positive_float(scenario.get("initialTau21", 1.0), "initialTau21")
    initial_tau12 = _positive_float(scenario.get("initialTau12", 1.0), "initialTau12")
    target_rate = _finite_float(scenario.get("targetRatePercent", 10.0), "targetRatePercent")
    if not -99.0 < target_rate <= 500.0:
        raise RunnerError("targetRatePercent must be greater than -99 and at most 500.")

    path_profile = str(scenario.get("pathProfile", "step")).strip().lower()
    if path_profile not in {"step", "linear", "frontloaded"}:
        raise RunnerError("pathProfile must be step, linear, or frontloaded.")

    rebate_type = str(scenario.get("rebateType", "lumpsum")).strip().lower()
    if rebate_type not in {item["value"] for item in REBATE_OPTIONS}:
        raise RunnerError("rebateType must be lumpsum, invsub, labtax, or captax.")

    tau21, tau12, scope = build_tariff_paths(
        {
            **scenario,
            "preset": preset,
            "horizon": horizon,
            "initialTau21": initial_tau21,
            "initialTau12": initial_tau12,
            "targetRatePercent": target_rate,
            "pathProfile": path_profile,
        }
    )

    parameters = _validate_parameters(parameters_raw)
    variables = _validate_variables(payload.get("variables", ["*"]))

    return {
        "scenario": {
            "preset": preset,
            "pathProfile": path_profile,
            "horizon": horizon,
            "initialTau21": initial_tau21,
            "initialTau12": initial_tau12,
            "targetRatePercent": target_rate,
            "rebateType": rebate_type,
            "tariffScope": scope,
            "description": str(scenario.get("description", "")).strip(),
        },
        "parameters": parameters,
        "variables": variables,
        "tariffPaths": {"tau21": tau21, "tau12": tau12},
    }


def build_tariff_paths(scenario: dict[str, Any]) -> tuple[list[float], list[float], str]:
    preset = str(scenario.get("preset", "unilateral_10"))
    horizon = _int_in_range(scenario.get("horizon", SOLUTION_HORIZON), "horizon", 1, 600)
    if horizon != SOLUTION_HORIZON:
        raise RunnerError(f"horizon is fixed at {SOLUTION_HORIZON} transition periods.")
    initial_tau21 = _positive_float(scenario.get("initialTau21", 1.0), "initialTau21")
    initial_tau12 = _positive_float(scenario.get("initialTau12", 1.0), "initialTau12")
    target_rate = _finite_float(scenario.get("targetRatePercent", 10.0), "targetRatePercent")
    target_tau = 1.0 + target_rate / 100.0
    if target_tau <= 0:
        raise RunnerError("targetRatePercent implies a nonpositive gross tariff.")

    if preset == "unilateral_10":
        tau21 = _profile_path(initial_tau21, target_tau, horizon, scenario.get("pathProfile", "step"))
        tau12 = [initial_tau12] * horizon
        scope = "unilateral"
    elif preset == "bilateral_10":
        tau21 = _profile_path(initial_tau21, target_tau, horizon, scenario.get("pathProfile", "step"))
        tau12 = _profile_path(initial_tau12, target_tau, horizon, scenario.get("pathProfile", "step"))
        scope = "bilateral"
    elif preset == "custom_path":
        tau21 = _carry_forward_path(scenario.get("tau21Path"), horizon, "tau21Path")
        tau12 = _carry_forward_path(scenario.get("tau12Path"), horizon, "tau12Path")
        scope = "bilateral" if any(abs(x - initial_tau12) > 1e-12 for x in tau12) else "unilateral"
    else:
        raise RunnerError(f"Unknown scenario preset: {preset}")

    return tau21, tau12, scope


def run_simulation(
    payload: dict[str, Any],
    *,
    timeout: int | None = None,
    progress: ProgressCallback | None = None,
) -> dict[str, Any]:
    _progress(progress, "validating", "Validating request")
    request = normalize_request(payload)
    fingerprint = model_fingerprint()
    engine, executable = resolve_engine()
    runtime_fingerprint = solver_runtime_fingerprint(engine, executable)
    cache_key = request_cache_key(request, fingerprint, runtime_fingerprint)
    cache_file = cache_root() / f"{cache_key}.json"

    _progress(progress, "cache_lookup", "Checking successful-result cache")
    if cache_file.exists():
        cached = json.loads(cache_file.read_text(encoding="utf-8"))
        validate_result(cached, require_complete=request["variables"] == ["*"])
        cached["cacheHit"] = True
        cached["message"] = "Loaded a previously solved result from the model cache."
        _progress(progress, "complete", "Cached model result ready")
        return cached

    job_id = uuid.uuid4().hex
    job_dir = jobs_root() / job_id
    job_dir.mkdir(parents=True, exist_ok=False)
    request_file = job_dir / "request.json"
    output_file = job_dir / "result.json"
    stdout_file = job_dir / "solver_stdout.txt"
    stderr_file = job_dir / "solver_stderr.txt"
    request_file.write_text(json.dumps(request, indent=2, allow_nan=False), encoding="utf-8")

    command = engine_command(engine, executable, request_file, output_file)
    timeout = timeout or _positive_timeout(os.environ.get("DEGE_SOLVER_TIMEOUT", "1800"))
    _progress(progress, "solver_running", f"Running {engine} and Dynare")

    try:
        completed = subprocess.run(
            command,
            cwd=REPO_ROOT,
            text=True,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise RunnerError(f"The solver exceeded the {timeout}-second timeout.", job_id=job_id) from exc
    except OSError as exc:
        raise RunnerError(f"Could not start the {engine} process: {exc}", job_id=job_id) from exc

    stdout_file.write_text(completed.stdout or "", encoding="utf-8")
    stderr_file.write_text(completed.stderr or "", encoding="utf-8")
    if not output_file.exists():
        detail = _last_nonempty_line(completed.stderr) or _last_nonempty_line(completed.stdout)
        suffix = f" Last solver message: {detail}" if detail else ""
        raise RunnerError(
            f"{engine} did not produce a result (exit code {completed.returncode}).{suffix}",
            job_id=job_id,
        )

    try:
        result = json.loads(output_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RunnerError("The solver returned unreadable JSON.", job_id=job_id) from exc

    if completed.returncode != 0 or result.get("status") == "error":
        message = str(result.get("message") or f"{engine} failed with exit code {completed.returncode}.")
        raise RunnerError(message, job_id=job_id)

    result.pop("stack", None)
    result["status"] = "ok"
    result["mode"] = "live simulation"
    result["engine"] = engine
    result["cacheHit"] = False
    result["modelVersion"] = fingerprint[:12]
    validate_result(result, require_complete=request["variables"] == ["*"])

    _progress(progress, "serializing", "Validating and caching solver output")
    cache_file.parent.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(json.dumps(result, separators=(",", ":"), allow_nan=False), encoding="utf-8")
    _progress(progress, "complete", "Live model result ready")
    return result


def load_saved_result(preset: str) -> dict[str, Any]:
    mapping = {
        "unilateral_10": SAVED_RESULTS_ROOT / "saved_unilateral_10.json",
        "bilateral_10": SAVED_RESULTS_ROOT / "saved_bilateral_10.json",
    }
    path = mapping.get(preset)
    if path is None:
        raise RunnerError("No saved model result exists for this scenario.")
    try:
        result = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RunnerError(f"Could not load saved model result: {path.name}") from exc
    validate_result(result, require_complete=True)
    return result


def saved_variable_catalog() -> list[dict[str, Any]]:
    try:
        result = load_saved_result("unilateral_10")
        return list(result["variables"])
    except RunnerError:
        return [
            {"name": name, "label": name, "type": "unknown", "defaultTransform": "raw"}
            for name in CORE_VARIABLES
        ]


def validate_result(result: dict[str, Any], *, require_complete: bool) -> None:
    if not isinstance(result, dict):
        raise RunnerError("Result must be a JSON object.")
    periods = result.get("periods")
    series = result.get("series")
    catalog = result.get("variables")
    if not isinstance(periods, list) or not periods:
        raise RunnerError("Result periods are missing or empty.")
    if not isinstance(series, dict) or not isinstance(catalog, list):
        raise RunnerError("Result series or variable catalog is missing.")

    catalog_names = {str(item.get("name")) for item in catalog if isinstance(item, dict) and item.get("name")}
    if require_complete and catalog_names != set(series):
        missing = sorted(catalog_names - set(series))
        extra = sorted(set(series) - catalog_names)
        raise RunnerError(f"Result variable completeness failed; missing={missing}, extra={extra}.")

    expected = len(periods)
    for name, item in series.items():
        if not isinstance(item, dict):
            raise RunnerError(f"Series {name} is not an object.")
        for transform in ("raw", "level", "log_change", "percent_change", "rate_percent"):
            values = item.get(transform)
            if not isinstance(values, list) or len(values) != expected:
                raise RunnerError(f"Series {name}.{transform} must contain {expected} values.")
            if not all(_is_finite_number(value) for value in values):
                raise RunnerError(f"Series {name}.{transform} contains a non-finite value.")
    if result.get("missingVariables") not in (None, []):
        raise RunnerError("The solver reported missing requested variables.")


def model_fingerprint() -> str:
    digest = hashlib.sha256()
    files = sorted(path for path in MODEL_ROOT.iterdir() if path.suffix.lower() in {".m", ".mod"})
    if not files:
        raise RunnerError("No public model source files were found.")
    for path in files:
        digest.update(path.name.encode("utf-8"))
        digest.update(path.read_bytes())
    return digest.hexdigest()


def request_cache_key(request: dict[str, Any], fingerprint: str, runtime_fingerprint: str = "") -> str:
    canonical = json.dumps(request, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(f"{fingerprint}\n{runtime_fingerprint}\n{canonical}".encode("utf-8")).hexdigest()


def solver_runtime_fingerprint(engine: str, executable: str) -> str:
    digest = hashlib.sha256()
    digest.update(engine.encode("utf-8"))
    digest.update(str(Path(executable).expanduser().resolve()).encode("utf-8"))
    dynare_path = os.environ.get("DEGE_DYNARE_PATH") or os.environ.get("DYNARE_MATLAB_PATH") or ""
    digest.update(dynare_path.encode("utf-8"))
    version_file = Path(dynare_path).expanduser() / "dynare_version.m" if dynare_path else None
    if version_file and version_file.is_file():
        digest.update(version_file.read_bytes())
    return digest.hexdigest()


def jobs_root() -> Path:
    configured = os.environ.get("DEGE_JOB_ROOT")
    return Path(configured).expanduser().resolve() if configured else Path(tempfile.gettempdir()) / "dege-jobs"


def cache_root() -> Path:
    configured = os.environ.get("DEGE_CACHE_ROOT")
    return Path(configured).expanduser().resolve() if configured else Path(tempfile.gettempdir()) / "dege-cache"


def resolve_engine() -> tuple[str, str]:
    requested = os.environ.get("DEGE_ENGINE", "auto").strip().lower()
    if requested not in {"auto", "octave", "matlab"}:
        raise RunnerError("DEGE_ENGINE must be auto, octave, or matlab.")

    if requested in {"auto", "octave"}:
        configured = os.environ.get("DEGE_OCTAVE_EXE")
        octave = configured or shutil.which("octave-cli") or shutil.which("octave")
        if octave:
            return "octave", octave
        if requested == "octave":
            raise RunnerError("GNU Octave was not found. Set DEGE_OCTAVE_EXE or add it to PATH.")

    configured = os.environ.get("DEGE_MATLAB_EXE")
    matlab = configured or shutil.which("matlab")
    if matlab:
        return "matlab", matlab
    raise RunnerError(
        "Neither GNU Octave nor MATLAB was found. Configure DEGE_OCTAVE_EXE or DEGE_MATLAB_EXE."
    )


def engine_command(engine: str, executable: str, request_file: Path, output_file: Path) -> list[str]:
    expression = (
        "addpath(fullfile(pwd,'model')); "
        f"dege_run_from_json({_matlab_quote(str(request_file))}, {_matlab_quote(str(output_file))});"
    )
    if engine == "octave":
        return [executable, "--quiet", "--no-gui", "--eval", expression]
    return [executable, "-batch", expression]


def _validate_parameters(parameters: dict[str, Any]) -> dict[str, Any]:
    clean: dict[str, Any] = {}
    for name, value in parameters.items():
        if name == "tauij":
            raise RunnerError("tauij is controlled by the scenario and cannot be overridden.")
        if name not in DEFAULT_PARAMETERS:
            raise RunnerError(f"Unknown model parameter: {name}")
        if name in STRUCTURE_OPTIONS:
            numeric = _finite_float(value, name)
            integer = int(numeric)
            allowed = {int(item["value"]) for item in STRUCTURE_OPTIONS[name]}
            if numeric != integer or integer not in allowed:
                allowed_text = ", ".join(str(item) for item in sorted(allowed))
                raise RunnerError(f"{name} must be one of: {allowed_text}.")
            clean[name] = integer
            continue
        numeric = _finite_float(value, name)
        if name in PARAMETER_BOUNDS:
            _check_bounds(name, numeric, PARAMETER_BOUNDS[name])
        clean[name] = numeric

    combined = {**DEFAULT_PARAMETERS, **clean}
    shares = combined["Xshare"] + combined["Mshare"] + combined["Cshare"]
    if abs(shares - 1.0) > 1e-9:
        raise RunnerError("Xshare, Mshare, and Cshare must sum to one.")
    return clean


def _validate_variables(value: Any) -> list[str]:
    if value is None:
        return ["*"]
    if not isinstance(value, list):
        raise RunnerError("variables must be a list of solver variable names.")
    variables: list[str] = []
    for raw in value:
        name = str(raw).strip()
        if not name:
            continue
        if name != "*" and not VARIABLE_PATTERN.fullmatch(name):
            raise RunnerError(f"Invalid solver variable name: {name}")
        if name not in variables:
            variables.append(name)
    if not variables:
        raise RunnerError("variables cannot be empty.")
    if "*" in variables and variables != ["*"]:
        raise RunnerError("The all-variables token '*' cannot be combined with named variables.")
    return variables


def _profile_path(initial: float, target: float, horizon: int, profile: Any) -> list[float]:
    profile = str(profile or "step").lower()
    if profile == "linear":
        if horizon == 1:
            return [target]
        return [initial + (target - initial) * (i / (horizon - 1)) for i in range(horizon)]
    if profile == "frontloaded":
        return [initial + (target - initial) * (1.0 - math.exp(-0.18 * (i + 1))) for i in range(horizon)]
    return [target] * horizon


def _carry_forward_path(value: Any, horizon: int, field_name: str) -> list[float]:
    if not isinstance(value, list) or not value:
        raise RunnerError(f"{field_name} must be a nonempty list for custom paths.")
    path = [_positive_float(item, field_name) for item in value]
    if len(path) > horizon:
        raise RunnerError(f"{field_name} must contain at most {horizon} values.")
    path.extend([path[-1]] * (horizon - len(path)))
    return path


def _check_bounds(
    name: str,
    value: float,
    bounds: tuple[float | None, float | None, bool, bool],
) -> None:
    lower, upper, lower_inclusive, upper_inclusive = bounds
    if lower is not None and (value < lower if lower_inclusive else value <= lower):
        operator = "at least" if lower_inclusive else "greater than"
        raise RunnerError(f"{name} must be {operator} {lower}.")
    if upper is not None and (value > upper if upper_inclusive else value >= upper):
        operator = "at most" if upper_inclusive else "less than"
        raise RunnerError(f"{name} must be {operator} {upper}.")


def _finite_float(value: Any, field_name: str) -> float:
    if isinstance(value, bool):
        raise RunnerError(f"{field_name} must be numeric, not boolean.")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise RunnerError(f"{field_name} must be numeric.") from exc
    if not math.isfinite(number):
        raise RunnerError(f"{field_name} must be finite.")
    return number


def _positive_float(value: Any, field_name: str) -> float:
    number = _finite_float(value, field_name)
    if number <= 0:
        raise RunnerError(f"{field_name} must be positive.")
    return number


def _int_in_range(value: Any, field_name: str, lower: int, upper: int) -> int:
    if isinstance(value, bool):
        raise RunnerError(f"{field_name} must be an integer.")
    try:
        number = int(value)
    except (TypeError, ValueError) as exc:
        raise RunnerError(f"{field_name} must be an integer.") from exc
    try:
        exact = float(value)
    except (TypeError, ValueError) as exc:
        raise RunnerError(f"{field_name} must be an integer.") from exc
    if exact != number or number < lower or number > upper:
        raise RunnerError(f"{field_name} must be an integer between {lower} and {upper}.")
    return number


def _positive_timeout(value: Any) -> int:
    timeout = _int_in_range(value, "DEGE_SOLVER_TIMEOUT", 1, 86400)
    return timeout


def _is_finite_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def _matlab_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _last_nonempty_line(value: str | None) -> str:
    lines = [line.strip() for line in (value or "").splitlines() if line.strip()]
    return lines[-1][:500] if lines else ""


def _progress(callback: ProgressCallback | None, phase: str, message: str) -> None:
    if callback is not None:
        callback(phase, message)
