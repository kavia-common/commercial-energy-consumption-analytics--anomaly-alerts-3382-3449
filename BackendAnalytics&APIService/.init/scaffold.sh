#!/usr/bin/env bash
set -euo pipefail
# Idempotent scaffold for minimal FastAPI app using workspace from container context
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3449/BackendAnalytics&APIService"
cd "$WORKSPACE"
mkdir -p "$WORKSPACE/app" "$WORKSPACE/data" "$WORKSPACE/tests"
# package init
[ -f "$WORKSPACE/app/__init__.py" ] || cat > "$WORKSPACE/app/__init__.py" <<'PY'
# app package
PY
# main app entrypoint
[ -f "$WORKSPACE/app/main.py" ] || cat > "$WORKSPACE/app/main.py" <<'PY'
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import sqlite3
import os

app = FastAPI()
WORKSPACE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
DB_PATH = os.path.join(WORKSPACE, 'data', 'app.db')
# NOTE: for minimal dev we use per-request sqlite3 connections. Do NOT run multiple uvicorn worker processes
# with the same SQLite file without appropriate configuration; start.sh/validation use a single worker.
class Item(BaseModel):
    id: int
    value: float

@app.on_event("startup")
def startup_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute('CREATE TABLE IF NOT EXISTS items(id INTEGER PRIMARY KEY, value REAL)')
    conn.commit(); conn.close()

@app.get('/health')
def health():
    return {"status": "ok"}

@app.get('/item/{item_id}')
def get_item(item_id: int):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.execute('SELECT id, value FROM items WHERE id=?', (item_id,))
    row = cur.fetchone(); conn.close()
    if not row:
        raise HTTPException(status_code=404, detail='not found')
    return {"id": row[0], "value": row[1]}

@app.post('/item')
def create_item(item: Item):
    conn = sqlite3.connect(DB_PATH)
    conn.execute('INSERT OR REPLACE INTO items(id, value) VALUES (?, ?)', (item.id, item.value))
    conn.commit(); conn.close()
    return {"ok": True}
PY
# tasks module
[ -f "$WORKSPACE/app/tasks.py" ] || cat > "$WORKSPACE/app/tasks.py" <<'PY'
# Minimal task module: deterministic add_sync() and optional Celery app if a broker is present.
import os
try:
    from celery import Celery
except Exception:
    Celery = None
REDIS_URL = os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379/0')
# instantiate Celery if available; presence does not change deterministic add_sync
if Celery is not None:
    cel = Celery('app_tasks', broker=REDIS_URL, backend=REDIS_URL)
    @cel.task
    def add(a, b):
        return a + b
else:
    cel = None

def add_sync(a, b):
    return a + b
PY
# start script that prefers venv uvicorn binary
[ -f "$WORKSPACE/start.sh" ] || cat > "$WORKSPACE/start.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_BIN="$WORKSPACE/.venv/bin"
# prefer venv's uvicorn binary; fallback to venv python -m uvicorn
UVICORN_BIN="$VENV_BIN/uvicorn"
: "${PORT:=8000}"
if [ -x "$UVICORN_BIN" ]; then
  exec "$UVICORN_BIN" app.main:app --host 0.0.0.0 --port "${PORT}" --workers 1 --log-level info
else
  exec "$VENV_BIN/python" -m uvicorn app.main:app --host 0.0.0.0 --port "${PORT}" --workers 1 --log-level info
fi
SH
chmod +x "$WORKSPACE/start.sh"
# basic test
[ -f "$WORKSPACE/tests/test_api.py" ] || cat > "$WORKSPACE/tests/test_api.py" <<'PY'
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    r = client.get('/health')
    assert r.status_code == 200
    assert r.json().get('status') == 'ok'
PY
# note added to workspace README if not present
README_FILE="$WORKSPACE/README.md"
if [ ! -f "$README_FILE" ]; then
  cat > "$README_FILE" <<'TXT'
Minimal FastAPI scaffold generated.

- Use the workspace .venv (create with: python3 -m venv .venv) and install requirements.
- start.sh uses the venv's uvicorn binary or falls back to "python -m uvicorn" to ensure venv isolation.
- SQLite note: the app uses per-request sqlite3 connections. Do NOT run multiple uvicorn worker processes
  against the same SQLite file in production without proper configuration. Validation/start scripts use --workers 1.
TXT
fi
# Completed
