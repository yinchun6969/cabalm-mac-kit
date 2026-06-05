#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CABALM_HOME="${CABALM_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_FILE="${CONFIG_FILE:-$CABALM_HOME/config/cabalm.env}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
GAME_PACKAGE="${GAME_PACKAGE:-com.u1game.cabalm}"
SERIALS="${SERIALS:-emulator-5554 emulator-5556 emulator-5558}"
WORK_DIR="${WORK_DIR:-$CABALM_HOME/tmp}"
PID_FILE="$WORK_DIR/cabal_attr_guard.pid"
LOG_FILE="$WORK_DIR/cabal_attr_guard.log"
DURATION_SECONDS="${DURATION_SECONDS:-86400}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-180}"

mkdir -p "$WORK_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

pid_is_running() {
  local pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1
}

device_online() {
  local serial="$1"
  "$ADB" devices | awk -v serial="$serial" '$1 == serial && $2 == "device" { found = 1 } END { exit(found ? 0 : 1) }'
}

game_foreground() {
  local serial="$1"
  "$ADB" -s "$serial" shell dumpsys window windows 2>/dev/null | grep -q "$GAME_PACKAGE/com.estsoft.cabal.androidtv.CabalActivity"
}

tap() {
  local serial="$1"
  local x="$2"
  local y="$3"
  local delay="${4:-0.25}"
  "$ADB" -s "$serial" shell input tap "$x" "$y" >/dev/null 2>&1 || true
  sleep "$delay"
}

keyevent() {
  local serial="$1"
  local key="$2"
  local delay="${3:-0.25}"
  "$ADB" -s "$serial" shell input keyevent "$key" >/dev/null 2>&1 || true
  sleep "$delay"
}

close_character_panel() {
  local serial="$1"
  tap "$serial" 389 98 0.25
}

system_mail_panel_visible() {
  local serial="$1"
  command -v python3 >/dev/null 2>&1 || return 1
  "$ADB" -s "$serial" exec-out screencap 2>/dev/null | python3 -c '
import struct, sys
data = sys.stdin.buffer.read()
if len(data) < 16:
    sys.exit(1)
w, h, fmt, _ = struct.unpack_from("<IIII", data, 0)
def pix(x, y):
    x = max(0, min(w - 1, int(x * w / 1280)))
    y = max(0, min(h - 1, int(y * h / 720)))
    i = 16 + (y * w + x) * 4
    return data[i:i + 4]
bright = 0
for y in range(100, 130):
    for x in range(970, 1000):
        r, g, b, a = pix(x, y)
        if r > 165 and g > 165 and b > 165:
            bright += 1
dark_samples = [pix(940, 116), pix(1005, 116), pix(985, 145)]
dark = sum(1 for r, g, b, a in dark_samples if r < 75 and g < 85 and b < 100)
sys.exit(0 if bright >= 18 and dark >= 2 else 1)
'
}

close_system_mail_panel() {
  local serial="$1"
  # Close an already-open system mail window. Do not tap the top-right mail icon.
  system_mail_panel_visible "$serial" || return 0
  tap "$serial" 985 116 0.25
}

attr_cycle() {
  local serial="$1"

  if ! device_online "$serial"; then
    log "$serial not online; skipped."
    return 0
  fi
  if ! game_foreground "$serial"; then
    log "$serial game not foreground; skipped."
    return 0
  fi

  log "$serial attribute guard cycle."

  # Close an already-open character/attribute panel first, then open the
  # character panel and tap the game's own auto-allocation controls.
  keyevent "$serial" BACK 0.35
  close_character_panel "$serial"
  close_system_mail_panel "$serial"

  tap "$serial" 50 45 0.9
  tap "$serial" 207 629 0.5
  tap "$serial" 327 629 0.5

  # Close character/attribute panels and common confirm overlays.
  close_character_panel "$serial"
  close_system_mail_panel "$serial"
  keyevent "$serial" BACK 0.25
}

run_loop() {
  : > "$LOG_FILE"
  echo "$$" > "$PID_FILE"
  trap 'rm -f "$PID_FILE"; log "attribute guard stopped."' EXIT

  local start now elapsed serial
  start="$(date +%s)"
  log "attribute guard started for ${DURATION_SECONDS}s; interval=${INTERVAL_SECONDS}s; serials=$SERIALS"

  while true; do
    now="$(date +%s)"
    elapsed=$((now - start))
    if [ "$elapsed" -ge "$DURATION_SECONDS" ]; then
      log "24-hour duration reached."
      break
    fi

    for serial in $SERIALS; do
      attr_cycle "$serial"
    done

    sleep "$INTERVAL_SECONDS"
  done
}

start_guard() {
  if [ -f "$PID_FILE" ]; then
    local old_pid
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if pid_is_running "$old_pid"; then
      echo "24小时属性守护已经在运行：PID $old_pid"
      exit 0
    fi
  fi

  nohup "$0" run >> "$WORK_DIR/cabal_attr_guard.nohup.log" 2>&1 </dev/null &
  local pid="$!"
  echo "$pid" > "$PID_FILE"
  echo "已后台启动 24 小时属性加点/关闭面板守护：PID $pid"
  echo "日志：$LOG_FILE"
}

stop_guard() {
  if [ ! -f "$PID_FILE" ]; then
    echo "没有找到正在运行的属性守护。"
    exit 0
  fi
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if pid_is_running "$pid"; then
    kill "$pid" >/dev/null 2>&1 || true
    echo "已停止属性守护：PID $pid"
  else
    echo "属性守护 PID 已不存在：$pid"
  fi
  rm -f "$PID_FILE"
}

status_guard() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if pid_is_running "$pid"; then
      echo "属性守护运行中：PID $pid"
      echo "日志：$LOG_FILE"
      exit 0
    fi
  fi
  echo "属性守护未运行。"
}

case "${1:-start}" in
  start) start_guard ;;
  stop) stop_guard ;;
  status) status_guard ;;
  run) run_loop ;;
  once)
    for serial in $SERIALS; do
      attr_cycle "$serial"
    done
    ;;
  *)
    echo "Usage: $0 [start|stop|status|run|once]"
    exit 2
    ;;
esac
