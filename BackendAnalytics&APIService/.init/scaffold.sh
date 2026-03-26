#!/usr/bin/env bash
set -euo pipefail
# Scaffolding: create FastAPI app, requirements, start script, and unit test
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3449/BackendAnalytics&APIService"
mkdir -p "$WORKSPACE"
# main app
cat > "$WORKSPACE/main.py" <<'PY'
from fastapi import FastAPI
import os
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass
app = FastAPI()
PORT = int(os.environ.get("PORT", "8000"))
ENV = os.environ.get("ENV", "development")
@app.get('/health')
async def health():
    return {'status': 'ok', 'env': ENV, 'port': PORT}
PY
# runtime requirements (allow pydantic v2+ compatible range)
cat > "$WORKSPACE/requirements.txt" <<'REQ'
fastapi>=0.100,<1
uvicorn[standard]>=0.23,<1
pydantic>=1.10,<3
REQ
# dev requirements (pytest, python-dotenv, requests for dev/network tests)
cat > "$WORKSPACE/requirements-dev.txt" <<'REQD'
pytest>=7.0,<8
python-dotenv>=1.0,<2
requests>=2.30,<3
REQD
# start script (venv-aware)
cat > "$WORKSPACE/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# load workspace .env if present
[ -f .env ] && set -a && . .env && set +a || true
PORT=${PORT:-8000}
# prefer workspace venv uvicorn
if [ -x "./.venv/bin/uvicorn" ]; then
  exec "./.venv/bin/uvicorn" main:app --host 0.0.0.0 --port "$PORT"
else
  exec uvicorn main:app --host 0.0.0.0 --port "$PORT"
fi
SH
chmod +x "$WORKSPACE/start.sh"
# unit test using TestClient
mkdir -p "$WORKSPACE/tests"
cat > "$WORKSPACE/tests/test_health.py" <<'PT'
from fastapi.testclient import TestClient
from main import app

def test_health():
    client = TestClient(app)
    r = client.get('/health')
    assert r.status_code == 200
    j = r.json()
    assert j.get('status') == 'ok'
PT
