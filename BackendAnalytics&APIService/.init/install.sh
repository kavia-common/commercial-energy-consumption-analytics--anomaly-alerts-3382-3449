#!/usr/bin/env bash
set -euo pipefail
# Install runtime and dev packages into workspace venv and verify imports
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3449/BackendAnalytics&APIService"
cd "$WORKSPACE"
VENV_PIP="$WORKSPACE/.venv/bin/pip"
VENV_PY="$WORKSPACE/.venv/bin/python"
# sanity checks
if [ ! -x "$VENV_PIP" ] || [ ! -x "$VENV_PY" ]; then
  echo "ERROR: venv not found or missing pip/python at $WORKSPACE/.venv/bin" >&2
  exit 2
fi
# emit system and venv uvicorn info for traceability
SYSTEM_UVICORN=$(command -v uvicorn || true)
if [ -n "$SYSTEM_UVICORN" ]; then
  echo "system uvicorn: $SYSTEM_UVICORN"
  # try showing version; ignore errors
  "$SYSTEM_UVICORN" --version 2>/dev/null || true
fi
if [ -x "$WORKSPACE/.venv/bin/uvicorn" ]; then
  echo "venv uvicorn: $WORKSPACE/.venv/bin/uvicorn"
  "$WORKSPACE/.venv/bin/uvicorn" --version 2>/dev/null || true
fi
# warn if system uvicorn differs from venv uvicorn path (trace only)
if [ -n "$SYSTEM_UVICORN" ] && [ -x "$WORKSPACE/.venv/bin/uvicorn" ]; then
  if [ "$(readlink -f "$SYSTEM_UVICORN")" != "$(readlink -f "$WORKSPACE/.venv/bin/uvicorn")" ]; then
    echo "WARNING: system uvicorn and venv uvicorn differ; using venv uvicorn for runtime in this workspace" >&2
  fi
fi
# install runtime deps
if [ ! -f requirements.txt ]; then
  echo "ERROR: requirements.txt not found in workspace" >&2
  exit 6
fi
$VENV_PIP install -q -r requirements.txt || { echo "ERROR: pip install runtime deps failed" >&2; exit 3; }
# install dev deps if present
if [ -f requirements-dev.txt ]; then
  $VENV_PIP install -q -r requirements-dev.txt || { echo "ERROR: pip install dev deps failed" >&2; exit 4; }
fi
# verify imports for runtime packages
$VENV_PY - <<'PY'
import sys
try:
    import fastapi
    import pydantic
    import importlib
    importlib.import_module('uvicorn')
except Exception as e:
    sys.stderr.write('runtime dependency import failed: '+str(e)+'\n')
    sys.exit(10)
print('runtime-deps-ok')
PY
# verify dev deps: check pytest is installed when requirements-dev.txt exists
if [ -f requirements-dev.txt ]; then
  if ! $VENV_PIP show pytest >/dev/null 2>&1; then
    echo "ERROR: pytest not installed in venv" >&2; exit 5
  fi
  $VENV_PY - <<'PY'
import sys
try:
    import pytest
except Exception as e:
    sys.stderr.write('dev dependency import failed: '+str(e)+'\n')
    sys.exit(11)
print('dev-deps-ok')
PY
fi
# show venv-installed uvicorn info for debugging
$VENV_PIP show uvicorn || true
echo "DEPENDENCY INSTALL AND VERIFICATION: SUCCESS"
