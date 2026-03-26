#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3449/BackendAnalytics&APIService"
cd "$WORKSPACE"
[ -f .env ] && set -a && . .env && set +a || true
PORT=${PORT:-8000}
UVICORN_BIN="$WORKSPACE/.venv/bin/uvicorn"
if [ ! -x "$UVICORN_BIN" ]; then UVICORN_BIN="$(command -v uvicorn || true)"; fi
if [ -z "$UVICORN_BIN" ]; then echo "uvicorn not found" >&2; exit 3; fi
LOGFILE="$WORKSPACE/uvicorn-test.log"
TMPDIR=$(mktemp -d)
SERVER_PID=""
SERVER_PGID=""
cleanup(){
  rc=$?
  if [ -n "${SERVER_PGID:-}" ]; then kill -- -"$SERVER_PGID" >/dev/null 2>&1 || true; fi
  rm -rf "$TMPDIR" || true
  exit $rc
}
trap cleanup EXIT
# start server in new process group
setsid "$UVICORN_BIN" main:app --host 0.0.0.0 --port "$PORT" >"$LOGFILE" 2>&1 &
SERVER_PID=$!
SERVER_PGID=$(ps -o pgid= $SERVER_PID | tr -d ' ' || true)
# wait for readiness
for i in {1..12}; do
  if curl -sS --max-time 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then break; fi
  sleep 1
done
if ! curl -sS --max-time 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  echo "server did not become ready; see $LOGFILE" >&2
  if [ -n "${SERVER_PGID:-}" ]; then kill -- -"$SERVER_PGID" >/dev/null 2>&1 || true; fi
  exit 4
fi
# run pytest from venv (network tests if present)
"$WORKSPACE/.venv/bin/pytest" -q || { echo "pytest failed" >&2; if [ -n "${SERVER_PGID:-}" ]; then kill -- -"$SERVER_PGID" >/dev/null 2>&1 || true; fi; exit 5; }
# cleanup done by trap
