#!/usr/bin/env bash
set -euo pipefail

CABALM_HOME="${CABALM_HOME:-$HOME/CabalmMacKit}"
CONFIG_FILE="${CONFIG_FILE:-$CABALM_HOME/config/cabalm.env}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
WORK_DIR="${WORK_DIR:-$CABALM_HOME/tmp}"
LOG_DIR="${LOG_DIR:-$CABALM_HOME/logs}"

echo "== CabalM Mac Kit diagnostics =="
echo "time: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "CABALM_HOME=${CABALM_HOME}"
echo "ANDROID_HOME=${ANDROID_HOME:-}"
echo "ANDROID_AVD_HOME=${ANDROID_AVD_HOME:-${CABALM_AVD_HOME:-}}"
echo

echo "== ADB devices =="
if [ -x "$ADB" ]; then
  "$ADB" devices -l || true
else
  echo "ADB not found: $ADB"
fi
echo

echo "== Emulator processes =="
ps -axo pid,stat,tty,command | grep -E 'qemu-system-aarch64|emulator.*-avd' | grep -v grep || true
echo

echo "== Host route =="
route get "${HOST_DIRECT_DOMAIN:-cabalm.iccgame.com}" 2>/dev/null | awk -F: '/route to:|interface:|gateway:/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $1 ":" $2}' || true
echo

echo "== Recent emulator graphics errors =="
find "$WORK_DIR" "$LOG_DIR" -maxdepth 1 -type f -name '*.log' 2>/dev/null \
  -print0 | xargs -0 grep -H -E 'bad window surface|bad color buffer|ColorBufferGl|Application Not Responding|isn.t responding|FATAL EXCEPTION|ANR' 2>/dev/null \
  | tail -80 || true

