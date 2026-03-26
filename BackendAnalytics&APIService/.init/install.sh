#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3449/BackendAnalytics&APIService"
cd "$WORKSPACE"
PY=python3
VENV_DIR="$WORKSPACE/.venv"
# create venv idempotently
[ -d "$VENV_DIR" ] || { $PY -m venv "$VENV_DIR"; }
VENV_PY="$VENV_DIR/bin/python"
# ensure pip up-to-date and basic requirements
"$VENV_PY" -m pip install -q --upgrade pip setuptools wheel
REQ="$WORKSPACE/requirements.txt"
if [ ! -f "$REQ" ]; then cat > "$REQ" <<'EOF'
fastapi
uvicorn[standard]
celery
redis
pytest
requests
EOF
fi
# install requirements if checksum changed
STAMP="$VENV_DIR/.req.stamp"
CHK=$(sha256sum "$REQ" | cut -d' ' -f1)
if [ ! -f "$STAMP" ] || [ "$(cat "$STAMP")" != "$CHK" ]; then
  "$VENV_PY" -m pip install -q --upgrade -r "$REQ"
  echo "$CHK" > "$STAMP"
fi
