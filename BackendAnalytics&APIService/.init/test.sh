#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3449/BackendAnalytics&APIService"
cd "$WORKSPACE"
VENV_PY="$WORKSPACE/.venv/bin/python"
[ -x "$VENV_PY" ] || { echo "ERROR: venv python missing; run env-001" >&2; exit 20; }
# run tests via venv python
"$VENV_PY" -m pytest -q tests/test_api.py
