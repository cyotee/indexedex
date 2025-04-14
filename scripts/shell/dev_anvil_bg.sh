#!/usr/bin/env bash
set -euo pipefail

ROOT_PWD="$(pwd -P)"
TMP_DIR="$ROOT_PWD/tmp"
LOG_FILE="$TMP_DIR/anvil.log"
PID_FILE="$TMP_DIR/anvil.pid"

mkdir -p "$TMP_DIR"

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(cat "$PID_FILE" || true)"
  if [[ -n "${existing_pid:-}" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    echo "Anvil already running (pid=$existing_pid)."
    echo "Log: $LOG_FILE"
    exit 0
  fi
fi

nohup anvil --host 127.0.0.1 --port 8545 >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

echo "Started Anvil in background (pid=$(cat "$PID_FILE"))."
echo "Log: $LOG_FILE"
