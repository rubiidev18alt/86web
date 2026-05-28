#!/usr/bin/env bash
# 86Web Android/Termux helper.
#
# This is not a Docker replacement. Android does not expose the normal Linux
# bridge/TAP/service-user environment that the default compose stack expects.
# This helper runs a lightweight local-hosted dev stack from Termux/proot:
#   - backend on 127.0.0.1:8000
#   - runner on 127.0.0.1:8001
#   - frontend/Vite host on 0.0.0.0:8086
#
# It is meant for Android tablets/phones where you want to manage/test 86Web in
# the browser. Full VM networking/TAP support still depends on the device,
# kernel, root/container setup, and whether a working 86Box binary exists for it.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="${ROOT_DIR}/android"
DATA_DIR="${ROOT_DIR}/data-android"
LIBRARY_DIR="${ROOT_DIR}/library"
LOG_DIR="${ANDROID_DIR}/logs"
PID_DIR="${ANDROID_DIR}/pids"
ENV_FILE="${ROOT_DIR}/.env.android"
PYTHON_BIN="${PYTHON_BIN:-python3}"
NODE_BIN="${NODE_BIN:-node}"
NPM_BIN="${NPM_BIN:-npm}"
HOST_PORT="${HOST_PORT:-8086}"
BACKEND_PORT="${BACKEND_PORT:-8000}"
RUNNER_PORT="${RUNNER_PORT:-8001}"

usage() {
  cat <<EOF
86Web Android helper

Usage:
  bash scripts/android-86web.sh setup      Install Python/Node deps and create Android env
  bash scripts/android-86web.sh start      Start backend, runner, and frontend host
  bash scripts/android-86web.sh stop       Stop the Android-hosted stack
  bash scripts/android-86web.sh restart    Stop, then start
  bash scripts/android-86web.sh status     Show process status and access URLs
  bash scripts/android-86web.sh logs       Tail Android stack logs
  bash scripts/android-86web.sh doctor     Check common Termux/proot requirements

Environment overrides:
  HOST_PORT=8086 BACKEND_PORT=8000 RUNNER_PORT=8001 bash scripts/android-86web.sh start
EOF
}

have() { command -v "$1" >/dev/null 2>&1; }

android_ip() {
  ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1 || true
}

ensure_dirs() {
  mkdir -p \
    "${ANDROID_DIR}" "${LOG_DIR}" "${PID_DIR}" \
    "${DATA_DIR}/vms" "${DATA_DIR}/roms" "${DATA_DIR}/config" \
    "${DATA_DIR}/cache/86box" "${DATA_DIR}/user_images" \
    "${DATA_DIR}/shared_media" "${LIBRARY_DIR}"
}

write_env() {
  if [ -f "${ENV_FILE}" ]; then
    echo "Keeping existing ${ENV_FILE}"
    return
  fi

  cat > "${ENV_FILE}" <<EOF
# 86Web Android local-host profile
APP_NAME=86Web Android
APP_SECRET_KEY=change_this_android_secret
APP_HOST=0.0.0.0
APP_PORT=${BACKEND_PORT}
DATA_PATH=${DATA_DIR}
LIBRARY_PATH=${LIBRARY_DIR}
USER_MANAGEMENT=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD=changeme
ADMIN_EMAIL=admin@example.com
LDAP_ENABLED=false
BOX86_VERSION=
BOX86_ARCH=aarch64
BASE_VNC_PORT=5900
BASE_WS_PORT=6900
MAX_CONCURRENT_VMS=4
ACTIVE_VM_LIMIT=1
DEFAULT_MAX_VMS=3
DEFAULT_MAX_STORAGE_GB=32
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
RUNNER_URL=http://127.0.0.1:${RUNNER_PORT}
LOG_LEVEL=info
VM_AUTO_SHUTDOWN_MINUTES=60
AUDIO_BUFFER_SECS=0.6
EOF
  echo "Created ${ENV_FILE}"
}

load_env() {
  if [ -f "${ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    . "${ENV_FILE}"
    set +a
  fi
  export DATA_PATH="${DATA_PATH:-${DATA_DIR}}"
  export LIBRARY_PATH="${LIBRARY_PATH:-${LIBRARY_DIR}}"
  export RUNNER_URL="${RUNNER_URL:-http://127.0.0.1:${RUNNER_PORT}}"
  export APP_HOST="${APP_HOST:-0.0.0.0}"
  export APP_PORT="${APP_PORT:-${BACKEND_PORT}}"
  export VITE_HOST_PORT="${HOST_PORT}"
}

venv_python() {
  echo "${ANDROID_DIR}/venv/bin/python"
}

setup_stack() {
  ensure_dirs
  write_env

  if ! have "${PYTHON_BIN}"; then
    echo "python3 not found. In Termux, run: pkg install python"
    exit 1
  fi
  if ! have "${NODE_BIN}" || ! have "${NPM_BIN}"; then
    echo "node/npm not found. In Termux, run: pkg install nodejs-lts"
    exit 1
  fi

  "${PYTHON_BIN}" -m venv "${ANDROID_DIR}/venv"
  "$(venv_python)" -m pip install --upgrade pip wheel setuptools
  "$(venv_python)" -m pip install -r "${ROOT_DIR}/backend/requirements.txt"
  "$(venv_python)" -m pip install -r "${ROOT_DIR}/runner/requirements.txt"

  (cd "${ROOT_DIR}/frontend" && "${NPM_BIN}" install --legacy-peer-deps)

  cat > "${ANDROID_DIR}/README.txt" <<EOF
86Web Android profile created.

Start:
  bash scripts/android-86web.sh start

Open on this Android device:
  http://127.0.0.1:${HOST_PORT}

Open from another device on the same Wi-Fi:
  http://ANDROID_WIFI_IP:${HOST_PORT}

Default login:
  admin / changeme

Change ADMIN_PASSWORD and APP_SECRET_KEY in .env.android before serious use.
EOF

  echo "Setup complete. Run: bash scripts/android-86web.sh start"
}

pid_file() { echo "${PID_DIR}/$1.pid"; }

is_running() {
  local file="$1"
  [ -f "$file" ] && kill -0 "$(cat "$file")" >/dev/null 2>&1
}

start_one() {
  local name="$1"
  local dir="$2"
  shift 2
  local pidfile
  pidfile="$(pid_file "$name")"

  if is_running "$pidfile"; then
    echo "$name already running (pid $(cat "$pidfile"))"
    return
  fi

  (cd "$dir" && nohup "$@" > "${LOG_DIR}/${name}.log" 2>&1 & echo $! > "$pidfile")
  sleep 1
  if is_running "$pidfile"; then
    echo "Started $name (pid $(cat "$pidfile"))"
  else
    echo "Failed to start $name. See ${LOG_DIR}/${name}.log"
    exit 1
  fi
}

start_stack() {
  ensure_dirs
  [ -d "${ANDROID_DIR}/venv" ] || setup_stack
  load_env

  export PYTHONPATH="${ROOT_DIR}/backend:${ROOT_DIR}/runner:${PYTHONPATH:-}"

  start_one backend "${ROOT_DIR}/backend" \
    "$(venv_python)" -m uvicorn app.main:app --host 0.0.0.0 --port "${BACKEND_PORT}" --log-level "${LOG_LEVEL:-info}"

  start_one runner "${ROOT_DIR}/runner" \
    "$(venv_python)" -m uvicorn app.main:app --host 127.0.0.1 --port "${RUNNER_PORT}" --log-level "${LOG_LEVEL:-info}"

  start_one frontend "${ROOT_DIR}/frontend" \
    "${NPM_BIN}" run dev -- --host 0.0.0.0 --port "${HOST_PORT}"

  show_status
}

stop_stack() {
  for name in frontend backend runner; do
    local pidfile
    pidfile="$(pid_file "$name")"
    if is_running "$pidfile"; then
      kill "$(cat "$pidfile")" || true
      echo "Stopped $name"
    fi
    rm -f "$pidfile"
  done
}

show_status() {
  local ip
  ip="$(android_ip)"
  echo
  for name in backend runner frontend; do
    local pidfile
    pidfile="$(pid_file "$name")"
    if is_running "$pidfile"; then
      echo "$name: running (pid $(cat "$pidfile"))"
    else
      echo "$name: stopped"
    fi
  done
  echo
  echo "Open on Android: http://127.0.0.1:${HOST_PORT}"
  if [ -n "$ip" ]; then
    echo "Open from same Wi-Fi: http://${ip}:${HOST_PORT}"
  else
    echo "Wi-Fi IP not detected. Try: ip -4 addr"
  fi
  echo "Logs: bash scripts/android-86web.sh logs"
}

doctor() {
  echo "86Web Android doctor"
  echo "Root: ${ROOT_DIR}"
  for cmd in bash "${PYTHON_BIN}" "${NODE_BIN}" "${NPM_BIN}" ip; do
    if have "$cmd"; then
      echo "ok: $cmd"
    else
      echo "missing: $cmd"
    fi
  done
  echo
  echo "Notes:"
  echo "- This host mode is for Termux/proot. It does not magically give Android bridge/TAP support."
  echo "- Full VM networking may require root, a real Linux container, or a normal Linux host."
  echo "- 86Box itself still needs a working Android/aarch64-compatible binary or Linux userspace binary."
}

tail_logs() {
  ensure_dirs
  touch "${LOG_DIR}/backend.log" "${LOG_DIR}/runner.log" "${LOG_DIR}/frontend.log"
  tail -n 120 -f "${LOG_DIR}/backend.log" "${LOG_DIR}/runner.log" "${LOG_DIR}/frontend.log"
}

case "${1:-}" in
  setup) setup_stack ;;
  start) start_stack ;;
  stop) stop_stack ;;
  restart) stop_stack; start_stack ;;
  status) show_status ;;
  logs) tail_logs ;;
  doctor) doctor ;;
  -h|--help|help|"") usage ;;
  *) echo "Unknown command: $1"; usage; exit 1 ;;
esac
