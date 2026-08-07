# Optional backend deployment

GitHub Pages hosts only the static `web/` directory. It cannot start Python, Octave, MATLAB, or Dynare, so a live solver must run as a separate service on infrastructure where one supported model runtime and Dynare are installed.

## Service contract

1. Install Python 3.10+, repository dependencies, Dynare, and either GNU Octave or MATLAB.
2. Set `DEGE_DYNARE_PATH` to Dynare's `matlab` directory.
3. Select `DEGE_ENGINE=octave` (preferred) or `DEGE_ENGINE=matlab`.
4. Start `python -m uvicorn api.app:app --host 0.0.0.0 --port 8000` behind HTTPS.
5. Set `DEGE_CORS_ORIGINS` to the exact GitHub Pages origin.
6. Use persistent, access-controlled locations for `DEGE_CACHE_ROOT` and `DEGE_JOB_ROOT` if diagnostics must survive restarts.

Solver processes are CPU- and memory-intensive. Begin with `DEGE_MAX_WORKERS=1`; scale only after measuring a representative transition. Apply platform-level request-size limits, timeouts, rate limits, TLS, log retention, and authentication if the endpoint should not be fully public.

The in-memory public job registry is intentionally lightweight. A multi-instance or durable production deployment should replace it with a real queue and shared status store while keeping `api/runner.py` as the model-process boundary.

## Pages deployment

`.github/workflows/pages.yml` uploads `web/` after a push to `main` or a manual dispatch. Before the first run, select **GitHub Actions** under repository **Settings → Pages**. The workflow is included locally but nothing has been published or pushed by this repository preparation.
