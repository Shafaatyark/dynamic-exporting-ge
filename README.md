# Dynamic Exporting GE Simulator

This teaching-oriented repository exposes prescribed tariff transitions in a two-country dynamic exporting general-equilibrium model. The economic equations and steady-state logic remain in MATLAB/Octave and Dynare; Python only validates requests, starts the solver, caches successful runs, and serializes results for the static web interface.

**Website:** [Dynamic Exporting GE Simulator](https://shafaatyark.github.io/dynamic-exporting-ge/)

The public scope is deliberately narrow:

- symmetric and asymmetric baseline steady states;
- unilateral, bilateral, and custom exogenous tariff paths;
- all macro and model series returned by Dynare;
- interactive Plotly charts and CSV/SVG downloads.

It does **not** include optimal tariffs, optimal policy paths, one-shot or sequence-space optimization, optimization-only routines, paper figures or tables, or private research results.

## Saved results and live simulations

The GitHub Pages site loads two genuine, precomputed model results:

- free trade to a 10% unilateral Home tariff;
- free trade to a 10% bilateral tariff.

These files are labeled **saved model result**. They contain 132 complete finite model series and are not recalculated in the browser. A **live simulation** is produced only when the interface reaches a local or separately deployed API with Octave or MATLAB plus Dynare. Failure never triggers synthetic replacement data.

## Run new simulations locally

The recommended setup uses each researcher's own MATLAB and Dynare installation. The local service binds to `127.0.0.1`, serves the website and API from one address, and does not send model inputs or solved results to GitHub Pages.

Requirements:

- Python 3.10 or newer;
- MATLAB with `jsondecode` and `jsonencode`;
- Dynare 7.1 or a newer stable release (7.1 is the currently validated release).

Clone the repository, then use the launcher for your operating system.

Windows PowerShell:

```powershell
git clone https://github.com/Shafaatyark/dynamic-exporting-ge.git
cd dynamic-exporting-ge
.\start_windows.ps1
```

If MATLAB or Dynare is installed outside the locations searched by the launcher, point the launcher to it for the current PowerShell session:

```powershell
$env:DEGE_MATLAB_EXE = "C:\path\to\MATLAB\bin\matlab.exe" # only if MATLAB is not detected
$env:DEGE_DYNARE_PATH = "C:\path\to\dynare-7.1\matlab"    # folder containing dynare.m
.\start_windows.ps1
```

These declarations affect only the current PowerShell session. To configure Dynare persistently for the current Windows user, use `[Environment]::SetEnvironmentVariable("DEGE_DYNARE_PATH", "C:\path\to\dynare-7.1\matlab", "User")`, then open a new PowerShell window.

macOS or Linux:

```bash
git clone https://github.com/Shafaatyark/dynamic-exporting-ge.git
cd dynamic-exporting-ge
./start_mac_linux.sh
```

The launcher:

1. detects MATLAB and Dynare, selecting the newest installed version that is at least Dynare 7.1;
2. creates an isolated `.venv` and installs the small Python API dependency set when needed;
3. sets portable environment variables for this session only;
4. starts the simulator at `http://127.0.0.1:8000`; and
5. opens the local website in the default browser.

Run installation checks without starting the server:

```powershell
.\start_windows.ps1 -CheckOnly
```

Run the genuine 10% unilateral example before starting the server:

```powershell
.\start_windows.ps1 -SmokeTest
```

The macOS/Linux equivalents are `--check-only` and `--smoke-test`. If PowerShell blocks a downloaded script, use `powershell -ExecutionPolicy Bypass -File .\start_windows.ps1`. The downloadable request is [`web/data/example_request.json`](web/data/example_request.json).

## Run the static frontend locally

With Python 3 installed:

```powershell
python -m http.server 8080 --directory web
```

Open `http://127.0.0.1:8080`. Saved results work without the backend. Plotly is loaded from its public CDN, so the browser needs network access unless Plotly is vendored separately.

## Install Octave and Dynare

Install mutually compatible releases listed on the [Dynare download page](https://www.dynare.org/download/) and follow the [official Dynare installation guide](https://www.dynare.org/manual/installation-and-configuration.html). GNU Octave installers are available from the [official Octave download page](https://octave.org/download.html).

When using Octave, point this repository at Dynare's `matlab` directory without editing model files:

```powershell
$env:DEGE_DYNARE_PATH = "C:\path\to\dynare\matlab"
$env:DEGE_ENGINE = "octave"
$env:DEGE_OCTAVE_EXE = "C:\path\to\octave-cli.exe"  # optional if on PATH
```

The API prefers Octave in `auto` mode and falls back to MATLAB. The bridge requires Octave versions that provide `jsondecode` and `jsonencode`.

## Run the local backend manually

Create an isolated Python 3.10+ environment and start FastAPI:

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r api\requirements.txt
python -m uvicorn api.app:app --host 127.0.0.1 --port 8000
```

Then open `http://127.0.0.1:8000`. FastAPI serves both the frontend and API at that address. Optional configuration:

| Variable | Purpose | Default |
|---|---|---|
| `DEGE_ENGINE` | `auto`, `octave`, or `matlab` | `auto` |
| `DEGE_DYNARE_PATH` | Dynare `matlab` directory | unset |
| `DEGE_OCTAVE_EXE` | Octave executable | PATH lookup |
| `DEGE_MATLAB_EXE` | MATLAB executable | PATH lookup |
| `DEGE_SOLVER_TIMEOUT` | Maximum solve time in seconds | `1800` |
| `DEGE_MAX_WORKERS` | Concurrent solver workers | `1` |
| `DEGE_CACHE_ROOT` | Successful-result cache | system temp directory |
| `DEGE_JOB_ROOT` | Solver diagnostics | system temp directory |
| `DEGE_CORS_ORIGINS` | Comma-separated frontend origins | `*` |

MATLAB can be selected with `$env:DEGE_ENGINE = "matlab"`; no Optimization or Parallel Computing Toolbox is used by the public workflow.

## Validation and tests

```powershell
python -m unittest discover -s tests -v
python scripts\validate_saved_examples.py
```

To compare every raw public-solver series with a trusted source MATLAB JSON result:

```powershell
python scripts\compare_reference_results.py source-result.json public-result.json --atol 1e-8 --rtol 1e-7
```

See [docs/validation.md](docs/validation.md) for the current validation record and remaining cross-engine work.

## Deployment

The Pages workflow publishes only `web/` from `main`. In repository settings, select **GitHub Actions** as the Pages source. GitHub Pages serves static files only—it cannot execute Python, Octave, MATLAB, or Dynare. Live solving therefore needs a separate backend deployment; see [docs/backend-deployment.md](docs/backend-deployment.md).

## Repository map

- `model/` — public steady-state, Dynare, and JSON bridge code, all using the `dege_` prefix;
- `api/` — validation, execution, cache, and FastAPI boundary;
- `web/` — GitHub Pages frontend and saved results;
- `scripts/` — regeneration and validation utilities;
- `tests/` — focused request/result/frontend-data checks;
- `docs/` — architecture, disclosure, deployment, and validation records.

## Citation and license

Formal citation metadata will be added when the accompanying code-and-website paper is ready. Until then, please identify the project and repository URL in teaching materials or derivative research.

The repository is offered under the [MIT License](LICENSE). MIT permits reuse and modification with preservation of the copyright and permission notice; it does not itself impose an academic citation requirement. External software remains under its own license—see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
