#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FRONTEND_DIR="$ROOT_DIR/lib/daosys/lib/daosys_frontend"
ROOT_PWD="$(pwd -P)"
TMP_DIR="$ROOT_PWD/tmp"
LOG_FILE="$TMP_DIR/daosys_frontend.log"
PID_FILE="$TMP_DIR/daosys_frontend.pid"

mkdir -p "$TMP_DIR"

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(cat "$PID_FILE" || true)"
  if [[ -n "${existing_pid:-}" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    echo "Frontend already running (pid=$existing_pid)."
    echo "Log: $LOG_FILE"
    exit 0
  fi
fi

if [[ ! -d "$FRONTEND_DIR" ]]; then
  echo "Frontend directory not found: $FRONTEND_DIR" >&2
  exit 1
fi

(
  cd "$FRONTEND_DIR"
  nohup npm run dev >"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
)

echo "Started daosys_frontend dev server in background (pid=$(cat "$PID_FILE"))."
echo "Log: $LOG_FILE"
