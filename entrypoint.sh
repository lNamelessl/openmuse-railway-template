#!/bin/sh
# OpenMuse Railway template entrypoint.
# Runs the node API on 127.0.0.1:8787 (sample mode requires a loopback HOST)
# and nginx on 8080 in the foreground (Railway routes to 8080).
set -eu
cd /src

mkdir -p "${DATA_DIR:-/data}"

# Runtime-derived config (keeps the template deploy form free of domain variables).
# Railway injects RAILWAY_PUBLIC_DOMAIN at runtime; the browser worker is reachable
# at <service-name>.railway.internal on the private network.
export PUBLIC_API_URL="${PUBLIC_API_URL:-https://${RAILWAY_PUBLIC_DOMAIN:-localhost:8080}}"
export ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-${PUBLIC_API_URL}}"
export BROWSER_WORKER_URL="${BROWSER_WORKER_URL:-http://browser-worker.railway.internal:8790}"
export WORKER_TOKEN="${WORKER_TOKEN:-9bd2fae8eee175848850209147dd6e04ecdce1914e5c0b0940ef9a71d78debf4}"

# The API port is fixed at 8787 (loopback): Railway injects PORT (8080) for the
# public listener, which nginx uses — the API must not pick it up.
PORT=8787 node dist/apps/server/src/index.js &
NODE_PID=$!

# Watchdog: if the API dies, take the whole container down so Railway's
# healthcheck fails and the deploy is marked unhealthy (restart policy kicks in).
(
  while kill -0 "$NODE_PID" 2>/dev/null; do sleep 5; done
  echo "[openmuse] API process exited; stopping container" >&2
  kill -TERM "$$" 2>/dev/null || true
) &

NGINX_PID=""
stop() {
  kill -TERM "$NODE_PID" 2>/dev/null || true
  if [ -n "$NGINX_PID" ]; then
    kill -TERM "$NGINX_PID" 2>/dev/null || true
  fi
  wait "$NODE_PID" 2>/dev/null || true
  exit 0
}
trap stop TERM INT

nginx -g "daemon off;" &
NGINX_PID=$!
wait "$NGINX_PID"
