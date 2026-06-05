#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
CABALM_HOME="${CABALM_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_FILE="${CONFIG_FILE:-$CABALM_HOME/config/cabalm.env}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
SERIAL="${SERIAL:-emulator-5554}"
GAME_PACKAGE="${GAME_PACKAGE:-com.u1game.cabalm}"
WORK_DIR="${WORK_DIR:-$CABALM_HOME/tmp}"
LOG_DIR="${LOG_DIR:-$CABALM_HOME/logs}"
DURATION_SECONDS="${DURATION_SECONDS:-172800}"
LOOP_SLEEP_SECONDS="${LOOP_SLEEP_SECONDS:-12}"
NETWORK_EVERY_CYCLES="${NETWORK_EVERY_CYCLES:-20}"
UPGRADE_EVERY_CYCLES="${UPGRADE_EVERY_CYCLES:-3}"
DAILY_EVERY_CYCLES="${DAILY_EVERY_CYCLES:-0}"
SCREENSHOT_EVERY_CYCLES="${SCREENSHOT_EVERY_CYCLES:-20}"
PID_FILE="$WORK_DIR/cabal_unattended_48h.pid"
STATE_FILE="$WORK_DIR/cabal_unattended_48h.state"
LOG_FILE="$LOG_DIR/cabal_unattended_48h.log"
NOHUP_LOG="$LOG_DIR/cabal_unattended_48h.nohup.log"
SCREENSHOT_DIR="$WORK_DIR/pressure_screenshots"
MACRO="$SCRIPT_DIR/cabal_macro_runner.sh"
LAUNCH_LABEL="${LAUNCH_LABEL:-com.cabalm.unattended48h.$(printf '%s' "$SERIAL" | tr -c '[:alnum:]_.-' '_')}"
LAUNCH_PLIST="${LAUNCH_PLIST:-$HOME/Library/LaunchAgents/$LAUNCH_LABEL.plist}"
LAUNCH_LOG_DIR="${LAUNCH_LOG_DIR:-$HOME/Library/Logs/CabalmMacKit}"
LAUNCH_LOG_FILE="${LAUNCH_LOG_FILE:-$LAUNCH_LOG_DIR/cabal_unattended_48h.launchd.log}"

mkdir -p "$WORK_DIR" "$LOG_DIR" "$SCREENSHOT_DIR" "$LAUNCH_LOG_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

pid_is_running() {
  local pid="${1:-}"
  [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1
}

device_online() {
  "$ADB" devices | awk -v serial="$SERIAL" '$1 == serial && $2 == "device" { found = 1 } END { exit(found ? 0 : 1) }'
}

foreground_component() {
  "$ADB" -s "$SERIAL" shell dumpsys window windows 2>/dev/null | awk '
    /mCurrentFocus=/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^[A-Za-z0-9_.]+\/[A-Za-z0-9_.$]+/) {
          gsub(/}.*/, "", $i)
          print $i
          exit
        }
      }
    }
  '
}

game_foreground() {
  case "$(foreground_component || true)" in
    "$GAME_PACKAGE"/*) return 0 ;;
    *) return 1 ;;
  esac
}

anr_visible() {
  "$ADB" -s "$SERIAL" shell dumpsys window windows 2>/dev/null | grep -q 'Application Not Responding'
}

ui_needs_reconnect() {
  "$ADB" -s "$SERIAL" shell uiautomator dump /sdcard/cabal-unattended.xml >/dev/null 2>&1 || true
  "$ADB" -s "$SERIAL" shell cat /sdcard/cabal-unattended.xml 2>/dev/null |
    grep -Eq '断开|重新连接|选择服务器|正在确认连接登录服务器|请输入账号|请输入密码|登录游戏|游戏版本更新'
}

current_ui_xml() {
  "$ADB" -s "$SERIAL" shell uiautomator dump /sdcard/cabal-unattended.xml >/dev/null 2>&1 || true
  "$ADB" -s "$SERIAL" shell cat /sdcard/cabal-unattended.xml 2>/dev/null || true
}

tap() {
  local x="$1"
  local y="$2"
  local delay="${3:-0.25}"
  "$ADB" -s "$SERIAL" shell input tap "$x" "$y" >/dev/null 2>&1 || true
  sleep "$delay"
}

keyevent() {
  local key="$1"
  local delay="${2:-0.25}"
  "$ADB" -s "$SERIAL" shell input keyevent "$key" >/dev/null 2>&1 || true
  sleep "$delay"
}

dialog_button_kind() {
  command -v python3 >/dev/null 2>&1 || return 1
  "$ADB" -s "$SERIAL" exec-out screencap 2>/dev/null | python3 -c '
import struct, sys
x = int(sys.argv[1])
y = int(sys.argv[2])
data = sys.stdin.buffer.read()
if len(data) < 16:
    sys.exit(1)
w, h, fmt, _ = struct.unpack_from("<IIII", data, 0)
if not (0 <= x < w and 0 <= y < h):
    sys.exit(1)
i = 16 + (y * w + x) * 4
if i + 4 > len(data):
    sys.exit(1)
r, g, b, a = data[i:i + 4]
if g >= 155 and b >= 100 and r <= 95 and (g - r) >= 55:
    print("exit_confirm_green")
elif 35 <= r <= 195 and 35 <= g <= 205 and b >= r + 8 and b >= g - 8:
    print("return_cancel_grayblue")
else:
    print("none")
' 748 485
}

cancel_self_drawn_danger_dialogs() {
  game_foreground || return 0
  local kind
  kind="$(dialog_button_kind 2>/dev/null || true)"
  case "$kind" in
    exit_confirm_green)
      log "self-drawn exit-game confirmation detected; tap left Cancel."
      tap 480 477 0.4
      ;;
    return_cancel_grayblue)
      log "self-drawn disconnect/return-to-character dialog detected; tap right Cancel/No."
      tap 748 485 0.4
      ;;
  esac
}

safe_back() {
  local delay="${1:-0.25}"
  keyevent KEYCODE_BACK "$delay"
  cancel_self_drawn_danger_dialogs
}

run_macro() {
  local action="$1"
  local repeat="${2:-1}"
  log "macro: $action $repeat"
  SERIAL="$SERIAL" "$MACRO" "$action" "$repeat" >>"$LOG_FILE" 2>&1 || log "macro failed but loop continues: $action $repeat"
}

recover_if_needed() {
  if ! device_online; then
    log "$SERIAL not online; run recover."
    run_macro recover 1
    return 0
  fi

  cancel_self_drawn_danger_dialogs

  if anr_visible; then
    log "ANR visible; choose Wait."
    tap 640 460 0.5
    keyevent KEYCODE_DPAD_DOWN 0.2
    keyevent KEYCODE_ENTER 2.0
  fi

  case "$(foreground_component || true)" in
    "$GAME_PACKAGE"/com.iccgame.sdk.SplashActivity)
      log "SDK announcement/splash foreground detected; run reconnect."
      run_macro reconnect 1
      ;;
    com.google.android.googlequicksearchbox/*|com.android.launcher3/*)
      log "system/search foreground detected; return to game."
      "$ADB" -s "$SERIAL" shell am force-stop com.google.android.googlequicksearchbox >/dev/null 2>&1 || true
      "$ADB" -s "$SERIAL" shell am start -n "$GAME_PACKAGE/com.estsoft.cabal.androidtv.CabalActivity" >/dev/null 2>&1 || true
      sleep 6
      ;;
  esac

  if ui_needs_reconnect || ! game_foreground; then
    log "login/disconnect/non-game state detected; run reconnect."
    run_macro reconnect 1
    if ! game_foreground; then
      log "reconnect did not restore foreground; run play."
      run_macro play 1
    fi
  fi
}

reward_and_stage_sweep() {
  game_foreground || return 0
  # Conservative confirm/accept positions seen on rewards and stage switches.
  # Avoid center dialog buttons because merchant/sell dialogs use those.
  tap 1239 678 0.25
  tap 1115 674 0.25
}

cancel_dangerous_dialogs() {
  game_foreground || return 0
  cancel_self_drawn_danger_dialogs
  local ui_xml
  ui_xml="$(current_ui_xml)"
  if printf '%s' "$ui_xml" | grep -q '退出游戏'; then
    log "exit-game confirmation detected; tap Cancel."
    tap 480 477 0.5
    return 0
  fi
  if printf '%s' "$ui_xml" | grep -q '出售' && printf '%s' "$ui_xml" | grep -q '贵重'; then
    log "valuable-item sale confirmation detected; tap Cancel."
    tap 755 472 0.5
    return 0
  fi
}

safe_task_cycle() {
  game_foreground || return 0
  cancel_dangerous_dialogs
  safe_back 0.25
  reward_and_stage_sweep
  # Left task panel / active quest title.
  tap 92 252 6.0
  tap 96 296 6.0
  # NPC quest choices in the dialog, if a dialog is open.
  tap 222 471 1.0
  tap 222 535 1.0
  reward_and_stage_sweep
  # Quest/autopath button near the lower-right action cluster.
  tap 1088 626 0.5
}

dungeon_and_progress_sweep() {
  game_foreground || return 0
  cancel_dangerous_dialogs
  # Quest/BATTLE/Dungeon-related buttons and safe accept spots.
  tap 1088 626 0.35
  tap 1152 373 0.35
  tap 1239 678 0.25
  tap 1115 674 0.25
}

capture_screenshot() {
  local shot="$SCREENSHOT_DIR/$(date '+%Y%m%d-%H%M%S')-cycle-${1:-0}.png"
  "$ADB" -s "$SERIAL" exec-out screencap -p >"$shot" 2>/dev/null &
  local pid="$!"
  local waited=0
  while pid_is_running "$pid" && [ "$waited" -lt 15 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if pid_is_running "$pid"; then
    kill "$pid" >/dev/null 2>&1 || true
    rm -f "$shot"
    log "screenshot timed out."
  else
    log "screenshot: $shot"
  fi
}

write_state() {
  local cycle="$1"
  local start_epoch="$2"
  local end_epoch="$3"
  local now
  now="$(date +%s)"
  {
    printf 'pid=%s\n' "$$"
    printf 'serial=%s\n' "$SERIAL"
    printf 'cycle=%s\n' "$cycle"
    printf 'start_epoch=%s\n' "$start_epoch"
    printf 'end_epoch=%s\n' "$end_epoch"
    printf 'now_epoch=%s\n' "$now"
    printf 'remaining_seconds=%s\n' "$((end_epoch - now))"
    printf 'foreground=%s\n' "$(foreground_component || true)"
    printf 'log=%s\n' "$LOG_FILE"
    printf 'screenshots=%s\n' "$SCREENSHOT_DIR"
  } >"$STATE_FILE"
}

run_loop() {
  : >"$LOG_FILE"
  echo "$$" >"$PID_FILE"
  trap 'rm -f "$PID_FILE"; log "unattended pressure test stopped."' EXIT

  local start_epoch end_epoch now cycle
  start_epoch="$(date +%s)"
  end_epoch=$((start_epoch + DURATION_SECONDS))
  cycle=0
  log "48h unattended pressure test started; duration=${DURATION_SECONDS}s; serial=$SERIAL"
  log "logs=$LOG_FILE screenshots=$SCREENSHOT_DIR"

  while true; do
    now="$(date +%s)"
    if [ "$now" -ge "$end_epoch" ]; then
      log "duration reached; stop pressure test."
      break
    fi

    cycle=$((cycle + 1))
    write_state "$cycle" "$start_epoch" "$end_epoch"
    log "cycle $cycle start; remaining=$((end_epoch - now))s"

    recover_if_needed

    if [ $((cycle % NETWORK_EVERY_CYCLES)) -eq 1 ]; then
      run_macro network 1
    fi

    reward_and_stage_sweep
    safe_task_cycle
    reward_and_stage_sweep
    run_macro battle 2
    dungeon_and_progress_sweep
    reward_and_stage_sweep

    if [ $((cycle % UPGRADE_EVERY_CYCLES)) -eq 0 ]; then
      cancel_dangerous_dialogs
      safe_back 0.25
      run_macro upgrade 1
      reward_and_stage_sweep
    fi

    if [ "$DAILY_EVERY_CYCLES" -gt 0 ] && [ $((cycle % DAILY_EVERY_CYCLES)) -eq 0 ]; then
      run_macro daily 1
      reward_and_stage_sweep
    fi

    if [ $((cycle % SCREENSHOT_EVERY_CYCLES)) -eq 0 ]; then
      capture_screenshot "$cycle"
    fi

    sleep "$LOOP_SLEEP_SECONDS"
  done
}

start_guard() {
  if [ -f "$PID_FILE" ]; then
    local old_pid
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if pid_is_running "$old_pid"; then
      echo "48小时无人值守压测已经在运行：PID $old_pid"
      echo "状态：$STATE_FILE"
      echo "日志：$LOG_FILE"
      exit 0
    fi
  fi

  if command -v launchctl >/dev/null 2>&1; then
    mkdir -p "$(dirname "$LAUNCH_PLIST")"
    launchctl bootout "gui/$(id -u)/$LAUNCH_LABEL" >/dev/null 2>&1 || true
    cat >"$LAUNCH_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCH_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT_PATH</string>
    <string>run</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$SCRIPT_DIR</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>CABALM_HOME</key>
    <string>$CABALM_HOME</string>
    <key>CONFIG_FILE</key>
    <string>$CONFIG_FILE</string>
    <key>SERIAL</key>
    <string>$SERIAL</string>
    <key>HOME</key>
    <string>$HOME</string>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LAUNCH_LOG_FILE</string>
  <key>StandardErrorPath</key>
  <string>$LAUNCH_LOG_FILE</string>
</dict>
</plist>
EOF
    chmod 644 "$LAUNCH_PLIST"
    if launchctl bootstrap "gui/$(id -u)" "$LAUNCH_PLIST" >/dev/null 2>&1; then
      local waited pid
      waited=0
      pid=""
      while [ "$waited" -lt 8 ]; do
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if pid_is_running "$pid"; then
          echo "已通过 LaunchAgent 后台启动 48 小时无人值守压测：PID $pid"
          echo "LaunchAgent：$LAUNCH_LABEL"
          echo "状态：$STATE_FILE"
          echo "日志：$LOG_FILE"
          echo "截图：$SCREENSHOT_DIR"
          exit 0
        fi
        sleep 1
        waited=$((waited + 1))
      done
      echo "LaunchAgent 未能在 8 秒内写入 PID，回退到 nohup 后台启动：$LAUNCH_LABEL"
      launchctl bootout "gui/$(id -u)/$LAUNCH_LABEL" >/dev/null 2>&1 || true
      rm -f "$LAUNCH_PLIST"
    else
      echo "LaunchAgent 启动失败，回退到 nohup 后台启动。" >&2
    fi
  fi

  nohup "$0" run >>"$NOHUP_LOG" 2>&1 </dev/null &
  local pid="$!"
  echo "$pid" >"$PID_FILE"
  echo "已后台启动 48 小时无人值守压测：PID $pid"
  echo "状态：$STATE_FILE"
  echo "日志：$LOG_FILE"
  echo "截图：$SCREENSHOT_DIR"
}

stop_guard() {
  if command -v launchctl >/dev/null 2>&1; then
    launchctl bootout "gui/$(id -u)/$LAUNCH_LABEL" >/dev/null 2>&1 || true
  fi
  if [ ! -f "$PID_FILE" ]; then
    rm -f "$LAUNCH_PLIST"
    echo "没有找到正在运行的 48 小时压测。"
    exit 0
  fi
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if pid_is_running "$pid"; then
    kill "$pid" >/dev/null 2>&1 || true
    echo "已停止 48 小时压测：PID $pid"
  else
    echo "压测 PID 已不存在：$pid"
  fi
  rm -f "$PID_FILE"
  rm -f "$LAUNCH_PLIST"
}

status_guard() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if pid_is_running "$pid"; then
      echo "48小时无人值守压测运行中：PID $pid"
      if [ -f "$LAUNCH_PLIST" ]; then
        echo "运行方式：LaunchAgent $LAUNCH_LABEL"
      else
        echo "运行方式：nohup/Terminal 权限继承"
      fi
      [ -f "$STATE_FILE" ] && cat "$STATE_FILE"
      exit 0
    fi
  fi
  echo "48小时无人值守压测未运行。"
}

case "${1:-start}" in
  start) start_guard ;;
  stop) stop_guard ;;
  status) status_guard ;;
  run) run_loop ;;
  once)
    recover_if_needed
    reward_and_stage_sweep
    safe_task_cycle
    run_macro battle 2
    run_macro upgrade 1
    dungeon_and_progress_sweep
    ;;
  *)
    echo "Usage: $0 [start|stop|status|run|once]"
    exit 2
    ;;
esac
