#!/usr/bin/env bash
set -euo pipefail

# Validation: smoke-start server, verify /health and run pytest unit tests with guarded cleanup
WORKSPACE="/home/kavia/workspace/code-generation/commercial-energy-consumption-analytics--anomaly-alerts-3382-3449/BackendAnalytics&APIService"
cd "$WORKSPACE"
[ -f .env ] && set -a && . .env && set +a || true
PORT=${PORT:-8000}
UVICORN_BIN="$WORKSPACE/.venv/bin/uvicorn"
# prefer workspace venv uvicorn, fall back to system uvicorn
if [ ! -x "$UVICORN_BIN" ]; then UVICORN_BIN="$(command -v uvicorn || true)"; fi
if [ -z "$UVICORN_BIN" ]; then echo "uvicorn not found" >&2; exit 3; fi
LOGFILE="$WORKSPACE/uvicorn-validate.log"
TMPRESP=$(mktemp)
SERVER_PID=""
SERVER_PGID=""
cleanup(){
  rc=$?
  rm -f "$TMPRESP" || true
  if [ -n "${SERVER_PGID:-}" ]; then kill -- -"$SERVER_PGID" >/dev/null 2>&1 || true; fi
  exit $rc
}
trap cleanup EXIT

# start server in its own process group so we can kill the group
setsid "$UVICORN_BIN" main:app --host 0.0.0.0 --port "$PORT" >"$LOGFILE" 2>&1 &
SERVER_PID=$!
SERVER_PGID=$(ps -o pgid= $SERVER_PID | tr -d ' ' || true)

# wait for readiness (12s total)
HTTP_CODE="000"
for i in {1..12}; do
  HTTP_CODE=$(curl -sS --max-time 2 -w "%{http_code}" "http://127.0.0.1:$PORT/health" -o "$TMPRESP" ) || HTTP_CODE="000"
  if [ "$HTTP_CODE" = "200" ]; then break; fi
  sleep 1
done
if [ "$HTTP_CODE" != "200" ]; then
  echo "Validation failed: /health returned $HTTP_CODE; see $LOGFILE" >&2
  if [ -n "${SERVER_PGID:-}" ]; then kill -- -"$SERVER_PGID" >/dev/null 2>&1 || true; fi
  rm -f "$TMPRESP"
  exit 4
fi

# output evidence JSON
cat "$TMPRESP" || true

# run pytest from venv if present, else try system pytest
PYTEST_BIN="$WORKSPACE/.venv/bin/pytest"
if [ ! -x "$PYTEST_BIN" ]; then PYTEST_BIN="$(command -v pytest || true)"; fi
if [ -z "$PYTEST_BIN" ]; then echo "pytest not found" >&2; if [ -n "${SERVER_PGID:-}" ]; then kill -- -"$SERVER_PGID" >/dev/null 2>&1 || true; fi; rm -f "$TMPRESP"; exit 5; fi

"$PYTEST_BIN" -q || { echo "pytest failed during validation" >&2; if [ -n "${SERVER_PGID:-}" ]; then kill -- -"$SERVER_PGID" >/dev/null 2>&1 || true; rm -f "$TMPRESP"; exit 6; }

# stop server and cleanup (trap handles remaining cleanup)
if [ -n "${SERVER_PGID:-}" ]; then kill -- -"$SERVER_PGID" >/dev/null 2>&1 || true; fi
wait ${SERVER_PID:-} 2>/dev/null || true
rm -f "$TMPRESP"
echo "validation: success"
