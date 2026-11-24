#!/bin/bash
# Start script for Scriberr on Railway.
# - puts all state on the /app/data volume and fixes its ownership
# - caps CPU threads to the service's CPU limit (Railway shows the host's CPUs)
# - creates the admin account from ADMIN_USERNAME / ADMIN_PASSWORD on a loopback-only
#   first start, so no visitor can claim the instance through the sign-up screen
# - then runs Scriberr in the foreground; any crash exits non-zero so Railway restarts it
set -euo pipefail

DATA=/app/data
mkdir -p "$DATA"/uploads "$DATA"/transcripts "$DATA"/temp \
         "$HF_HOME" "$TORCH_HOME" "$NLTK_DATA" "$XDG_CACHE_HOME"
find "$DATA" \( ! -user appuser -o ! -group appuser \) -exec chown appuser:appuser {} +

# CPU threads from the cgroup limit, not the host's CPU count.
cpus=""
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ]; then
    cpus=$(( (quota + period - 1) / period ))
  fi
fi
[ -n "$cpus" ] || cpus=$(nproc)
[ "$cpus" -ge 1 ] || cpus=1
[ "$cpus" -le 8 ] || cpus=8
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$cpus}" MKL_NUM_THREADS="${MKL_NUM_THREADS:-$cpus}" \
       GOMAXPROCS="${GOMAXPROCS:-$cpus}" TOKENIZERS_PARALLELISM=false
echo "railway-start: using $OMP_NUM_THREADS CPU thread(s)"

cd /app
export HOME=/home/appuser USER=appuser

bootstrap_admin() {
  local port=18080 pid i status body code
  # setpriv runs Scriberr in place (no subshell), so $! is the server itself and kill reaches it.
  HOST=127.0.0.1 PORT=$port setpriv --reuid=appuser --regid=appuser --init-groups -- /app/scriberr &
  pid=$!
  for i in $(seq 1 300); do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "railway-start: Scriberr exited during first start" >&2; exit 1
    fi
    curl -fsS -o /dev/null "http://127.0.0.1:$port/health" 2>/dev/null && break
    sleep 1
  done
  status=$(curl -fsS "http://127.0.0.1:$port/api/v1/auth/registration-status")
  if printf '%s' "$status" | grep -q '"registration_enabled":true'; then
    body=$(python3 -c 'import json,os; u=os.environ["ADMIN_USERNAME"]; p=os.environ["ADMIN_PASSWORD"]; print(json.dumps({"username":u,"password":p,"confirmPassword":p}))')
    code=$(curl -s -o /tmp/register.out -w '%{http_code}' -H 'Content-Type: application/json' \
           -d "$body" "http://127.0.0.1:$port/api/v1/auth/register")
    if [ "$code" != "201" ]; then
      echo "railway-start: could not create the admin account (HTTP $code): $(cat /tmp/register.out)" >&2
      kill "$pid"; exit 1
    fi
    echo "railway-start: created admin account '$ADMIN_USERNAME'"
  else
    echo "railway-start: admin account already exists"
  fi
  rm -f /tmp/register.out
  kill "$pid"; wait "$pid" || true
  if curl -fs -o /dev/null "http://127.0.0.1:$port/health" 2>/dev/null; then
    echo "railway-start: first-start server did not stop" >&2; exit 1
  fi
}

has_users() {
  python3 - "$DATABASE_PATH" <<'PY' 2>/dev/null
import sqlite3, sys, os
p = sys.argv[1]
if not os.path.exists(p):
    sys.exit(1)
n = sqlite3.connect(p).execute("select count(*) from users").fetchone()[0]
sys.exit(0 if n > 0 else 1)
PY
}

if has_users; then
  echo "railway-start: admin account already exists"
elif [ -n "${ADMIN_USERNAME:-}" ] && [ -n "${ADMIN_PASSWORD:-}" ]; then
  bootstrap_admin
else
  echo "railway-start: ADMIN_USERNAME/ADMIN_PASSWORD not set; refusing to start with an open sign-up screen" >&2
  exit 1
fi

exec setpriv --reuid=appuser --regid=appuser --init-groups -- /app/scriberr
