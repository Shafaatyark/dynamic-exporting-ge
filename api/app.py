"""FastAPI boundary for saved and newly solved DEGE simulations."""

from __future__ import annotations

import os
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .runner import (
    RunnerError,
    load_saved_result,
    metadata,
    normalize_request,
    resolve_engine,
    run_simulation,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
WEB_ROOT = REPO_ROOT / "web"
MAX_WORKERS = max(1, min(8, int(os.environ.get("DEGE_MAX_WORKERS", "1"))))
EXECUTOR = ThreadPoolExecutor(max_workers=MAX_WORKERS, thread_name_prefix="dege-solver")
JOB_LOCK = threading.Lock()
JOBS: dict[str, dict[str, Any]] = {}


def _cors_origins() -> list[str]:
    configured = os.environ.get("DEGE_CORS_ORIGINS", "*")
    origins = [item.strip() for item in configured.split(",") if item.strip()]
    return origins or ["*"]


app = FastAPI(
    title="Dynamic Exporting GE Simulation API",
    version="0.1.0",
    description=(
        "A thin request-validation and process boundary around the public "
        "Octave/MATLAB and Dynare model."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


def _safe_error(exc: RunnerError) -> dict[str, Any]:
    payload: dict[str, Any] = {"message": str(exc)}
    if exc.job_id:
        payload["diagnosticId"] = exc.job_id
    return payload


def _record_progress(public_job_id: str, phase: str, message: str) -> None:
    with JOB_LOCK:
        job = JOBS.get(public_job_id)
        if job is not None:
            job.update({"phase": phase, "message": message})


def _execute_job(public_job_id: str, payload: dict[str, Any]) -> None:
    with JOB_LOCK:
        JOBS[public_job_id].update(
            {"status": "running", "phase": "starting", "message": "Starting model worker"}
        )
    try:
        result = run_simulation(
            payload,
            progress=lambda phase, message: _record_progress(public_job_id, phase, message),
        )
    except RunnerError as exc:
        with JOB_LOCK:
            JOBS[public_job_id].update(
                {
                    "status": "failed",
                    "phase": "failed",
                    "message": str(exc),
                    "diagnosticId": exc.job_id,
                }
            )
        return
    except Exception:
        # Unexpected details stay in the server log; the public response is stable.
        with JOB_LOCK:
            JOBS[public_job_id].update(
                {
                    "status": "failed",
                    "phase": "failed",
                    "message": "The simulation failed unexpectedly. Check the backend log.",
                }
            )
        return

    with JOB_LOCK:
        JOBS[public_job_id].update(
            {
                "status": "complete",
                "phase": "complete",
                "message": result.get("message", "Model result ready"),
                "result": result,
            }
        )


@app.get("/api/health")
def health() -> dict[str, Any]:
    try:
        engine, _ = resolve_engine()
        solver = {"available": True, "engine": engine}
    except RunnerError as exc:
        solver = {"available": False, "message": str(exc)}
    return {
        "status": "ok",
        "solver": solver,
        "maximumConcurrentJobs": MAX_WORKERS,
    }


@app.get("/api/metadata")
def get_metadata() -> dict[str, Any]:
    return metadata()


@app.post("/api/validate")
def validate(payload: dict[str, Any]) -> dict[str, Any]:
    try:
        return normalize_request(payload)
    except RunnerError as exc:
        raise HTTPException(status_code=400, detail=_safe_error(exc)) from exc


@app.get("/api/saved/{preset}")
def saved_result(preset: str) -> dict[str, Any]:
    try:
        return load_saved_result(preset)
    except RunnerError as exc:
        raise HTTPException(status_code=404, detail=_safe_error(exc)) from exc


@app.post("/api/simulate")
def simulate(payload: dict[str, Any]) -> dict[str, Any]:
    """Synchronous endpoint for command-line clients and small deployments."""
    try:
        return run_simulation(payload)
    except RunnerError as exc:
        raise HTTPException(status_code=422, detail=_safe_error(exc)) from exc


@app.post("/api/jobs", status_code=202)
def create_job(payload: dict[str, Any]) -> dict[str, Any]:
    try:
        normalize_request(payload)
    except RunnerError as exc:
        raise HTTPException(status_code=400, detail=_safe_error(exc)) from exc

    public_job_id = uuid.uuid4().hex
    with JOB_LOCK:
        JOBS[public_job_id] = {
            "id": public_job_id,
            "status": "queued",
            "phase": "queued",
            "message": "Simulation queued",
        }
    # The worker normalizes once more immediately before execution. Preserve
    # the original custom-path fields rather than submitting a lossy summary.
    EXECUTOR.submit(_execute_job, public_job_id, payload)
    return JOBS[public_job_id].copy()


@app.get("/api/jobs/{job_id}")
def get_job(job_id: str) -> dict[str, Any]:
    with JOB_LOCK:
        job = JOBS.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail={"message": "Unknown simulation job."})
        return job.copy()


if WEB_ROOT.exists():
    app.mount("/", StaticFiles(directory=WEB_ROOT, html=True), name="web")
else:
    @app.get("/")
    def index_missing() -> dict[str, str]:
        raise HTTPException(status_code=404, detail="web/index.html not found")
