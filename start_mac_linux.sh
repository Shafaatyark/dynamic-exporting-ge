#!/usr/bin/env sh
set -eu

PORT=8000
CHECK_ONLY=0
SMOKE_TEST=0
SKIP_INSTALL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --check-only) CHECK_ONLY=1; shift ;;
    --smoke-test) SMOKE_TEST=1; shift ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$PORT" in
  *[!0-9]*|'') echo "--port must be an integer." >&2; exit 2 ;;
esac
if [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
  echo "--port must be between 1024 and 65535." >&2
  exit 2
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

if command -v python3 >/dev/null 2>&1; then
  SYSTEM_PYTHON=$(command -v python3)
elif command -v python >/dev/null 2>&1; then
  SYSTEM_PYTHON=$(command -v python)
else
  echo "Python 3.10 or newer was not found. Install Python, then run this launcher again." >&2
  exit 1
fi

REPORT=$("$SYSTEM_PYTHON" scripts/check_installation.py --engine matlab --json || true)
"$SYSTEM_PYTHON" scripts/check_installation.py --engine matlab || CHECK_STATUS=$?
CHECK_STATUS=${CHECK_STATUS:-0}

if [ "$CHECK_ONLY" -eq 1 ]; then
  exit "$CHECK_STATUS"
fi
if [ "$CHECK_STATUS" -ne 0 ]; then
  echo "MATLAB and Dynare must be installed before the local simulator can start." >&2
  exit 1
fi

MATLAB_EXE=$(printf '%s' "$REPORT" | "$SYSTEM_PYTHON" -c 'import json,sys; print(json.load(sys.stdin)["matlab"]["path"] or "")')
DYNARE_PATH=$(printf '%s' "$REPORT" | "$SYSTEM_PYTHON" -c 'import json,sys; print(json.load(sys.stdin)["dynare"]["path"] or "")')
export DEGE_ENGINE=matlab
export DEGE_MATLAB_EXE="$MATLAB_EXE"
export DEGE_DYNARE_PATH="$DYNARE_PATH"
export DEGE_CORS_ORIGINS="http://127.0.0.1:$PORT,http://localhost:$PORT"

VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"
if [ ! -x "$VENV_PYTHON" ]; then
  if [ "$SKIP_INSTALL" -eq 1 ]; then
    echo "The local Python environment is missing. Run again without --skip-install to create it." >&2
    exit 1
  fi
  echo "Creating the local Python environment..."
  "$SYSTEM_PYTHON" -m venv .venv
fi

if ! "$VENV_PYTHON" -c 'import fastapi, uvicorn' >/dev/null 2>&1; then
  if [ "$SKIP_INSTALL" -eq 1 ]; then
    echo "FastAPI dependencies are missing. Run again without --skip-install to install them." >&2
    exit 1
  fi
  echo "Installing the local web interface dependencies..."
  "$VENV_PYTHON" -m pip install -r api/requirements.txt
fi

if [ "$SMOKE_TEST" -eq 1 ]; then
  "$VENV_PYTHON" scripts/run_example.py
fi

LOCAL_URL="http://127.0.0.1:$PORT"
(
  attempt=0
  while [ "$attempt" -lt 60 ]; do
    if "$VENV_PYTHON" -c "import urllib.request; urllib.request.urlopen('$LOCAL_URL/api/health', timeout=2).read()" >/dev/null 2>&1; then
      if command -v open >/dev/null 2>&1; then
        open "$LOCAL_URL"
      elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$LOCAL_URL"
      fi
      exit 0
    fi
    attempt=$((attempt + 1))
    sleep 0.5
  done
) &
OPENER_PID=$!
trap 'kill "$OPENER_PID" 2>/dev/null || true' EXIT INT TERM

echo "Starting the simulator at $LOCAL_URL"
echo "MATLAB and Dynare will run only on this computer. Press Ctrl+C to stop."
"$VENV_PYTHON" -m uvicorn api.app:app --host 127.0.0.1 --port "$PORT"
