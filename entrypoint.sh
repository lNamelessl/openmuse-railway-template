#!/bin/sh
# OpenMuse Railway template entrypoint.
# Runs the node API on 127.0.0.1:8787 (sample mode requires a loopback HOST)
# and nginx on 8080 in the foreground (Railway routes to 8080).
set -eu
cd /src

mkdir -p "${DATA_DIR:-/data}"

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
