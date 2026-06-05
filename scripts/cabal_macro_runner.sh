#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CABALM_HOME="${CABALM_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_FILE="${CONFIG_FILE:-$CABALM_HOME/config/cabalm.env}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi
ACTION="${1:-help}"
REPEAT="${2:-1}"
SPEED="${SPEED:-1}"
SERIAL="${SERIAL:-emulator-5554}"
AVD_NAME="${AVD_NAME:-macos_game_a9_01}"
AVD_HOME="${ANDROID_AVD_HOME:-${CABALM_AVD_HOME:-$HOME/.android/avd}}"
EMULATOR_PORT="${EMULATOR_PORT:-}"
GPU_MODE="${GPU_MODE:-swangle}"
MEMORY_MB="${MEMORY_MB:-6144}"
CORES="${CORES:-4}"
FPS="${FPS:-30}"
WORK_DIR="${WORK_DIR:-$CABALM_HOME/tmp}"
TMPDIR="${TMPDIR:-$WORK_DIR/tmp}"
export TMPDIR
EMULATOR_LAUNCH_METHOD="${EMULATOR_LAUNCH_METHOD:-nohup}"
EMULATOR_LOG_FILE="${EMULATOR_LOG_FILE:-$WORK_DIR/${AVD_NAME}-${GPU_MODE}.log}"
WRITABLE_SYSTEM="${WRITABLE_SYSTEM:-1}"
AUTO_BOOT="${AUTO_BOOT:-1}"
BOOT_TIMEOUT_SECONDS="${BOOT_TIMEOUT_SECONDS:-120}"
LOAD_WAIT_SECONDS="${LOAD_WAIT_SECONDS:-600}"
POST_DATA_WAIT_SECONDS="${POST_DATA_WAIT_SECONDS:-45}"
GAME_PACKAGE="${GAME_PACKAGE:-com.u1game.cabalm}"
GAME_ACTIVITY="${GAME_ACTIVITY:-com.iccgame.sdk.SplashActivity}"
GAME_FILES_DIR="${GAME_FILES_DIR:-/data/data/$GAME_PACKAGE/files}"
GAME_DB_DIR="${GAME_DB_DIR:-/data/data/$GAME_PACKAGE/databases}"
GAME_VERSION_DB="${GAME_VERSION_DB:-$GAME_DB_DIR/version.db}"
GAME_VERSION_GUARD="${GAME_VERSION_GUARD:-1}"
GAME_VERSION_TYPE0="${GAME_VERSION_TYPE0:-55}"
GAME_VERSION_TYPE1="${GAME_VERSION_TYPE1:-8}"
CEGUI_PATCH_IMAGESET_DIR="${CEGUI_PATCH_IMAGESET_DIR:-$WORK_DIR/inspect_cegui_current}"
CEGUI_PATCH_LAYOUT_DIR="${CEGUI_PATCH_LAYOUT_DIR:-$WORK_DIR/cegui_layout_patch}"
DEVICE_BRAND="${DEVICE_BRAND:-Xiaomi}"
DEVICE_MANUFACTURER="${DEVICE_MANUFACTURER:-Xiaomi}"
DEVICE_MODEL="${DEVICE_MODEL:-Xiaomi 14}"
DEVICE_PRODUCT="${DEVICE_PRODUCT:-houji}"
DEVICE_DEVICE="${DEVICE_DEVICE:-houji}"
DEVICE_MODEL_CODE="${DEVICE_MODEL_CODE:-23127PN0CC}"
HOST_DIRECT_DOMAIN="${HOST_DIRECT_DOMAIN:-cabalm.iccgame.com}"
GAME_HOSTS_OVERRIDE="${GAME_HOSTS_OVERRIDE:-0}"
GAME_HOSTS_IP="${GAME_HOSTS_IP:-}"
GAME_HOSTS_NAMES="${GAME_HOSTS_NAMES:-cabalm.iccgame.com video.h.aocde.com}"
GAME_HOSTS_FALLBACK_IP="${GAME_HOSTS_FALLBACK_IP:-}"
GAME_BASEBAND="${GAME_BASEBAND:-MPSS.HI.4.0.c2-00012-8998_GEN_PACK-1}"
GAME_DIRECT_HTTP_PROXY="${GAME_DIRECT_HTTP_PROXY:-1}"
GAME_DIRECT_PROXY_PORT="${GAME_DIRECT_PROXY_PORT:-18080}"
GAME_DIRECT_PROXY_IFACE="${GAME_DIRECT_PROXY_IFACE:-en1}"
GAME_DIRECT_PROXY_SCRIPT="${GAME_DIRECT_PROXY_SCRIPT:-$SCRIPT_DIR/mos-bound-http-proxy.py}"
GAME_DIRECT_PROXY_PYTHON="${GAME_DIRECT_PROXY_PYTHON:-python3}"
GAME_DIRECT_PROXY_IPS="${GAME_DIRECT_PROXY_IPS:-180.76.198.209}"
GAME_DIRECT_PROXY_RESOLVE="${GAME_DIRECT_PROXY_RESOLVE:-fr2s23sj.crcn.loveota.com=180.76.198.209 fr2s23sj.cscn.loveota.com=180.76.198.209 any.crcn.loveota.com-e358deab.baiduads.com=180.76.198.209 any.cscn.loveota.com-bcb8da15.baiduads.com=180.76.198.209}"
GAME_DIRECT_TCP_PROXY="${GAME_DIRECT_TCP_PROXY:-1}"
GAME_DIRECT_TCP_PROXIES="${GAME_DIRECT_TCP_PROXIES:-43.137.72.62:38101=18101 43.137.72.62:38102=18102}"
CHECK_HOST_ROUTE="${CHECK_HOST_ROUTE:-1}"
STOP_HOST_VPN_FOR_GAME="${STOP_HOST_VPN_FOR_GAME:-0}"
ALLOW_HOST_VPN_STOP_FOR_GAME="${ALLOW_HOST_VPN_STOP_FOR_GAME:-0}"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

prepare_host_work_dirs() {
  mkdir -p "$LOG_DIR" "$WORK_DIR" "$TMPDIR"
}

prepare_log_file() {
  local path="$1"
  if [ "$path" = "/dev/null" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  : >"$path"
}

find_adb() {
  if [ -n "${ADB:-}" ] && [ -x "$ADB" ]; then
    printf '%s\n' "$ADB"
    return
  fi
  if [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/platform-tools/adb" ]; then
    printf '%s\n' "$ANDROID_HOME/platform-tools/adb"
    return
  fi
  if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]; then
    printf '%s\n' "$ANDROID_SDK_ROOT/platform-tools/adb"
    return
  fi
  if [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
    printf '%s\n' "$HOME/Library/Android/sdk/platform-tools/adb"
    return
  fi
  command -v adb
}

ADB_BIN="$(find_adb)"
SDK_ROOT="$(dirname "$(dirname "$ADB_BIN")")"
LOG_DIR="${LOG_DIR:-$CABALM_HOME/logs}"
EMULATOR_DYLD_LIBRARY_PATH="$SDK_ROOT/emulator/lib64:$SDK_ROOT/emulator/lib64/qt/lib:$SDK_ROOT/emulator/qemu/darwin-aarch64${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
EMULATOR_DYLD_FALLBACK_LIBRARY_PATH="$SDK_ROOT/emulator/lib64:$SDK_ROOT/emulator/lib64/qt/lib:$SDK_ROOT/emulator/qemu/darwin-aarch64${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"

find_emulator() {
  local adb_dir sdk_root
  adb_dir="$(dirname "$ADB_BIN")"
  sdk_root="$(dirname "$adb_dir")"
  if [ -x "$sdk_root/emulator/emulator" ]; then
    printf '%s\n' "$sdk_root/emulator/emulator"
    return
  fi
  if [ -n "${ANDROID_HOME:-}" ] && [ -x "$ANDROID_HOME/emulator/emulator" ]; then
    printf '%s\n' "$ANDROID_HOME/emulator/emulator"
    return
  fi
  if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -x "$ANDROID_SDK_ROOT/emulator/emulator" ]; then
    printf '%s\n' "$ANDROID_SDK_ROOT/emulator/emulator"
    return
  fi
  command -v emulator
}

EMULATOR_BIN="$(find_emulator)"

emulator_writable_system_args() {
  if [ "$WRITABLE_SYSTEM" = "1" ]; then
    printf '%s\n' "-writable-system"
  fi
}

emulator_port_args() {
  if [ -n "$EMULATOR_PORT" ]; then
    printf '%s\n%s\n' "-port" "$EMULATOR_PORT"
  fi
}

host_route_interface() {
  route get "$HOST_DIRECT_DOMAIN" 2>/dev/null | awk -F: '/interface:/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }'
}

host_route_address() {
  route get "$HOST_DIRECT_DOMAIN" 2>/dev/null | awk -F: '/route to:/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); if ($2 ~ /^[0-9.]+$/) print $2; exit }'
}

host_route_uses_vpn() {
  local iface="$1"
  case "$iface" in
    utun*|ppp*|ipsec*) return 0 ;;
    *) return 1 ;;
  esac
}

stop_host_vpn_for_game() {
  log "Host VPN auto-stop is disabled. Keep VPN running and use split/direct routing for $HOST_DIRECT_DOMAIN."
}

ensure_host_direct_route() {
  if [ "$CHECK_HOST_ROUTE" != "1" ]; then
    return 0
  fi

  local before after
  before="$(host_route_interface || true)"
  if host_route_uses_vpn "$before"; then
    log "Host route for $HOST_DIRECT_DOMAIN is currently $before."
    if [ "$STOP_HOST_VPN_FOR_GAME" = "1" ] && [ "$ALLOW_HOST_VPN_STOP_FOR_GAME" = "1" ]; then
      stop_host_vpn_for_game
    else
      log "Host VPN stays running. Configure V2Box/Karing split routing for the game domain if the server list is empty."
    fi
  fi

  after="$(host_route_interface || true)"
  if host_route_uses_vpn "$after"; then
    log "WARNING: $HOST_DIRECT_DOMAIN still routes through $after. Keep VPN running if Codex needs it, and add a V2Box/Karing direct/split rule for the game domain."
  elif [ -n "$after" ]; then
    log "Host route for $HOST_DIRECT_DOMAIN uses $after."
  else
    log "WARNING: could not inspect host route for $HOST_DIRECT_DOMAIN."
  fi
}

clear_emulator_crash_reports() {
  local crash_dir
  for crash_dir in "/tmp/android-$(id -un)"/emu-crash-*.db; do
    [ -d "$crash_dir" ] || continue
    rm -rf "$crash_dir"/completed/* \
      "$crash_dir"/pending/* \
      "$crash_dir"/new/* \
      "$crash_dir"/attachments/* 2>/dev/null || true
  done
}

dismiss_emulator_crash_dialog() {
  command -v osascript >/dev/null 2>&1 || return 0
  osascript >/dev/null 2>&1 <<'OSA' || true
tell application "System Events"
  if exists process "qemu-system-aarch64" then
    tell process "qemu-system-aarch64"
      repeat with w in windows
        try
          set isCrashDialog to false
          repeat with t in static texts of w
            try
              if (value of t as text) contains "closed unexpectedly" then
                set isCrashDialog to true
              end if
            end try
          end repeat
          repeat with b in buttons of w
            try
              if (title of b as text) is "Show details" then
                set isCrashDialog to true
              end if
            end try
          end repeat
          if isCrashDialog then
            click button 2 of w
          end if
        end try
      end repeat
    end tell
  end if
end tell
OSA
}

scaled_sleep() {
  local seconds="$1"
  local scaled
  scaled="$(awk "BEGIN { v=$seconds / $SPEED; if (v < 0.05) v=0.05; printf \"%.3f\", v }")"
  sleep "$scaled"
}

adb_shell() {
  "$ADB_BIN" -s "$SERIAL" shell "$@"
}

device_ready() {
  [ "$("$ADB_BIN" -s "$SERIAL" get-state 2>/dev/null || true)" = "device" ]
}

foreground_component() {
  adb_shell dumpsys window windows 2>/dev/null | awk '
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

foreground_matches() {
  local pattern="$1"
  foreground_component | grep -Eq "$pattern"
}

current_focus_line() {
  adb_shell dumpsys window windows 2>/dev/null | awk '/mCurrentFocus=/ { print; exit }'
}

emulator_console_cmd() {
  local command="$1"
  local port="${SERIAL#emulator-}"
  local token_file="$HOME/.emulator_console_auth_token"
  if ! command -v nc >/dev/null 2>&1 || [ "$port" = "$SERIAL" ] || [ ! -f "$token_file" ]; then
    return 1
  fi
  {
    printf 'auth %s\n' "$(cat "$token_file")"
    printf '%s\n' "$command"
    printf 'quit\n'
  } | nc -w 3 127.0.0.1 "$port" >/dev/null 2>&1
}

ensure_landscape_window() {
  adb_shell settings put system accelerometer_rotation 0 >/dev/null 2>&1 || true
  adb_shell settings put system user_rotation 1 >/dev/null 2>&1 || true
  if adb_shell dumpsys input 2>/dev/null | grep -q 'Viewport: displayId=0.*deviceSize=\[1280, 720\]'; then
    return 0
  fi
  log "Rotate emulator display back to landscape."
  emulator_console_cmd rotate || true
  scaled_sleep 2
}

dump_ui_xml() {
  adb_shell rm -f /sdcard/cabal-window.xml >/dev/null 2>&1 || true
  adb_shell uiautomator dump /sdcard/cabal-window.xml >/dev/null 2>&1 || true
  adb_shell cat /sdcard/cabal-window.xml 2>/dev/null || true
}

ui_contains() {
  local pattern="$1"
  dump_ui_xml | grep -Eq "$pattern"
}

login_or_server_screen_visible() {
  ui_contains '请输入账号|请输入密码|登录游戏|快速注册|忘记密码|选择服务器|正在确认连接登录服务器|频道 [0-9]+|进入游戏'
}

loading_data_visible() {
  ui_contains '下载中 Data|loading_text_load_data'
}

system_anr_visible() {
  current_focus_line | grep -q 'Application Not Responding'
}

dismiss_system_anr() {
  if system_anr_visible; then
    log "SystemUI ANR dialog detected; tap Wait."
    adb_shell input tap 640 460 >/dev/null 2>&1 || true
    adb_shell input tap 260 580 >/dev/null 2>&1 || true
    adb_shell input keyevent KEYCODE_DPAD_DOWN >/dev/null 2>&1 || true
    adb_shell input keyevent KEYCODE_ENTER >/dev/null 2>&1 || true
    scaled_sleep 2
  fi
}

is_game_foreground() {
  case "$(foreground_component || true)" in
    "$GAME_PACKAGE"/*) return 0 ;;
    *) return 1 ;;
  esac
}

recover_system_foreground() {
  local focus
  focus="$(foreground_component || true)"
  case "$focus" in
    com.google.android.googlequicksearchbox/*|com.android.launcher3/*)
      log "System/search foreground detected (${focus}); return to game."
      adb_shell input keyevent KEYCODE_BACK >/dev/null 2>&1 || true
      adb_shell am force-stop com.google.android.googlequicksearchbox >/dev/null 2>&1 || true
      start_cabal_activity
      return 0
      ;;
  esac
  return 1
}

webview_browser_foreground() {
  foreground_matches '^org\.chromium\.webview_shell/'
}

ensure_game_foreground() {
  if is_game_foreground; then
    return 0
  fi
  start_game
  is_game_foreground
}

skip_if_not_game_foreground() {
  if is_game_foreground; then
    return 1
  fi
  if recover_system_foreground; then
    return 0
  fi
  log "Skip game taps because foreground is $(foreground_component || echo unknown)."
  return 0
}

tap() {
  local x="$1"
  local y="$2"
  local delay="${3:-0.25}"
  if ! device_ready; then
    ensure_device
    prepare_game_screen
  fi
  adb_shell input tap "$x" "$y" >/dev/null || true
  scaled_sleep "$delay"
}

swipe() {
  local x1="$1"
  local y1="$2"
  local x2="$3"
  local y2="$4"
  local duration="$5"
  local delay="${6:-0.25}"
  if ! device_ready; then
    ensure_device
    prepare_game_screen
  fi
  adb_shell input swipe "$x1" "$y1" "$x2" "$y2" "$duration" >/dev/null || true
  scaled_sleep "$delay"
}

keyevent() {
  local key="$1"
  local delay="${2:-0.25}"
  if ! device_ready; then
    ensure_device
    prepare_game_screen
  fi
  adb_shell input keyevent "$key" >/dev/null || true
  scaled_sleep "$delay"
}

dialog_button_kind() {
  command -v python3 >/dev/null 2>&1 || return 1
  "$ADB_BIN" -s "$SERIAL" exec-out screencap 2>/dev/null | python3 -c '
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
  is_game_foreground || return 0
  local kind
  kind="$(dialog_button_kind 2>/dev/null || true)"
  case "$kind" in
    exit_confirm_green)
      log "Self-drawn exit-game confirmation detected; tap left Cancel."
      tap 480 477 0.4
      ;;
    return_cancel_grayblue)
      log "Self-drawn disconnect/return-to-character dialog detected; tap right Cancel/No."
      tap 748 485 0.4
      ;;
  esac
}

safe_back() {
  local delay="${1:-0.25}"
  keyevent KEYCODE_BACK "$delay"
  cancel_self_drawn_danger_dialogs
}

ensure_device() {
  if device_ready; then
    wait_for_boot_completed
    return 0
  fi

  "$ADB_BIN" start-server >/dev/null 2>&1 || true
  if ! device_ready && [ "$AUTO_BOOT" = "1" ]; then
    launch_emulator
  fi

  local waited=0
  while ! device_ready; do
    dismiss_emulator_crash_dialog
    if [ "$waited" -ge "$BOOT_TIMEOUT_SECONDS" ]; then
      break
    fi
    sleep 2
    waited=$((waited + 2))
  done

  if ! device_ready; then
    echo "ADB device is not ready: $SERIAL" >&2
    exit 1
  fi

  wait_for_boot_completed
}

wait_for_boot_completed() {
  local waited=0
  local booted=""

  while device_ready; do
    booted="$(adb_shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [ "$booted" = "1" ]; then
      return 0
    fi
    if [ "$waited" -ge "$BOOT_TIMEOUT_SECONDS" ]; then
      echo "Android boot did not finish within ${BOOT_TIMEOUT_SECONDS}s; continuing with ADB-ready device." >&2
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done

  echo "ADB device disappeared while waiting for Android boot." >&2
  exit 1
}

launch_emulator() {
  prepare_host_work_dirs
  clear_emulator_crash_reports
  dismiss_emulator_crash_dialog
  local log_file="$EMULATOR_LOG_FILE"
  local launch_label="com.macos.android.emulator.$(printf '%s' "$AVD_NAME" | tr -c '[:alnum:]_.-' '_')"
  local launch_agent_dir="$HOME/Library/LaunchAgents"
  local launch_plist="$launch_agent_dir/${launch_label}.plist"
  local terminal_launcher="$WORK_DIR/start_${AVD_NAME}_${GPU_MODE}.sh"
  local uid
  uid="$(id -u)"
  echo "No ready ADB device. Booting $AVD_NAME with $GPU_MODE GPU..."
  prepare_log_file "$log_file"

  if command -v launchctl >/dev/null 2>&1; then
    launchctl bootout "gui/${uid}/${launch_label}" >/dev/null 2>&1 || true
  fi

  cat >"$terminal_launcher" <<EOF
#!/usr/bin/env bash
export ANDROID_AVD_HOME="${AVD_HOME}"
export ANDROID_HOME="${ANDROID_HOME:-$SDK_ROOT}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$SDK_ROOT}"
export DYLD_LIBRARY_PATH="${EMULATOR_DYLD_LIBRARY_PATH}"
export DYLD_FALLBACK_LIBRARY_PATH="${EMULATOR_DYLD_FALLBACK_LIBRARY_PATH}"
exec "${EMULATOR_BIN}" \\
  -avd "${AVD_NAME}" \\
$(emulator_port_args | sed 's/.*/  & \\/')
  -gpu "${GPU_MODE}" \\
  -no-snapshot-load \\
  -no-snapshot-save \\
  -no-boot-anim \\
  -no-metrics \\
  -no-audio \\
  -skip-adb-auth \\
$(emulator_writable_system_args | sed 's/.*/  & \\/')
  -netdelay none \\
  -netspeed full \\
  -dns-server 192.168.1.1,223.5.5.5,119.29.29.29,8.8.8.8 \\
  -prop "ro.product.brand=${DEVICE_BRAND}" \\
  -prop "ro.product.manufacturer=${DEVICE_MANUFACTURER}" \\
  -prop "ro.product.model=${DEVICE_MODEL}" \\
  -prop "ro.product.name=${DEVICE_PRODUCT}" \\
  -prop "ro.product.device=${DEVICE_DEVICE}" \\
  -prop "ro.product.system.brand=${DEVICE_BRAND}" \\
  -prop "ro.product.system.manufacturer=${DEVICE_MANUFACTURER}" \\
  -prop "ro.product.system.model=${DEVICE_MODEL}" \\
  -prop "ro.product.system.name=${DEVICE_PRODUCT}" \\
  -prop "ro.product.system.device=${DEVICE_DEVICE}" \\
  -prop "ro.product.vendor.brand=${DEVICE_BRAND}" \\
  -prop "ro.product.vendor.manufacturer=${DEVICE_MANUFACTURER}" \\
  -prop "ro.product.vendor.model=${DEVICE_MODEL}" \\
  -prop "ro.product.vendor.name=${DEVICE_PRODUCT}" \\
  -prop "ro.product.vendor.device=${DEVICE_DEVICE}" \\
  -prop "ro.build.product=${DEVICE_DEVICE}" \\
  -prop "ro.product.board=${DEVICE_DEVICE}" \\
  -prop "persist.macos.virtual.model_code=${DEVICE_MODEL_CODE}" \\
  -memory "${MEMORY_MB}" \\
  -cores "${CORES}" \\
  -vsync-rate "${FPS}" \\
  >"${log_file}" 2>&1
EOF
  chmod +x "$terminal_launcher"

  if [ "$EMULATOR_LAUNCH_METHOD" = "terminal" ] && command -v osascript >/dev/null 2>&1; then
    if osascript >/dev/null <<EOF
tell application "Terminal"
  activate
  do script quoted form of "${terminal_launcher}"
  delay 0.5
  try
    set miniaturized of front window to true
  end try
end tell
EOF
    then
      echo "Emulator Terminal launcher: $terminal_launcher"
      echo "Emulator log: $log_file"
      return
    fi
    echo "Terminal launch failed; falling back to launchd/nohup." >&2
  fi

  if [ "$EMULATOR_LAUNCH_METHOD" = "launchd" ] && command -v launchctl >/dev/null 2>&1; then
    mkdir -p "$launch_agent_dir"
    umask 022
    cat >"$launch_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${launch_label}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>ANDROID_AVD_HOME</key>
    <string>${AVD_HOME}</string>
    <key>ANDROID_HOME</key>
    <string>${ANDROID_HOME:-$SDK_ROOT}</string>
    <key>ANDROID_SDK_ROOT</key>
    <string>${ANDROID_SDK_ROOT:-$SDK_ROOT}</string>
    <key>DYLD_LIBRARY_PATH</key>
    <string>${EMULATOR_DYLD_LIBRARY_PATH}</string>
    <key>DYLD_FALLBACK_LIBRARY_PATH</key>
    <string>${EMULATOR_DYLD_FALLBACK_LIBRARY_PATH}</string>
  </dict>
  <key>ProgramArguments</key>
  <array>
    <string>${EMULATOR_BIN}</string>
	    <string>-avd</string>
	    <string>${AVD_NAME}</string>
$(if [ -n "$EMULATOR_PORT" ]; then printf '    <string>-port</string>\n    <string>%s</string>\n' "$EMULATOR_PORT"; fi)
	    <string>-gpu</string>
    <string>${GPU_MODE}</string>
    <string>-no-snapshot-load</string>
    <string>-no-snapshot-save</string>
    <string>-no-boot-anim</string>
    <string>-no-metrics</string>
    <string>-no-audio</string>
    <string>-skip-adb-auth</string>
$(if [ "$WRITABLE_SYSTEM" = "1" ]; then printf '    <string>-writable-system</string>\n'; fi)
    <string>-netdelay</string>
    <string>none</string>
    <string>-netspeed</string>
    <string>full</string>
    <string>-dns-server</string>
    <string>192.168.1.1,223.5.5.5,119.29.29.29,8.8.8.8</string>
    <string>-prop</string>
    <string>ro.product.brand=${DEVICE_BRAND}</string>
    <string>-prop</string>
    <string>ro.product.manufacturer=${DEVICE_MANUFACTURER}</string>
    <string>-prop</string>
    <string>ro.product.model=${DEVICE_MODEL}</string>
    <string>-prop</string>
    <string>ro.product.name=${DEVICE_PRODUCT}</string>
    <string>-prop</string>
    <string>ro.product.device=${DEVICE_DEVICE}</string>
    <string>-prop</string>
    <string>ro.product.system.brand=${DEVICE_BRAND}</string>
    <string>-prop</string>
    <string>ro.product.system.manufacturer=${DEVICE_MANUFACTURER}</string>
    <string>-prop</string>
    <string>ro.product.system.model=${DEVICE_MODEL}</string>
    <string>-prop</string>
    <string>ro.product.system.name=${DEVICE_PRODUCT}</string>
    <string>-prop</string>
    <string>ro.product.system.device=${DEVICE_DEVICE}</string>
    <string>-prop</string>
    <string>ro.product.vendor.brand=${DEVICE_BRAND}</string>
    <string>-prop</string>
    <string>ro.product.vendor.manufacturer=${DEVICE_MANUFACTURER}</string>
    <string>-prop</string>
    <string>ro.product.vendor.model=${DEVICE_MODEL}</string>
    <string>-prop</string>
    <string>ro.product.vendor.name=${DEVICE_PRODUCT}</string>
    <string>-prop</string>
    <string>ro.product.vendor.device=${DEVICE_DEVICE}</string>
    <string>-prop</string>
    <string>ro.build.product=${DEVICE_DEVICE}</string>
    <string>-prop</string>
    <string>ro.product.board=${DEVICE_DEVICE}</string>
    <string>-prop</string>
    <string>persist.macos.virtual.model_code=${DEVICE_MODEL_CODE}</string>
    <string>-memory</string>
    <string>${MEMORY_MB}</string>
    <string>-cores</string>
    <string>${CORES}</string>
    <string>-vsync-rate</string>
    <string>${FPS}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>StandardOutPath</key>
  <string>${log_file}</string>
  <key>StandardErrorPath</key>
  <string>${log_file}</string>
</dict>
</plist>
EOF
    chmod 644 "$launch_plist"
    if launchctl bootstrap "gui/${uid}" "$launch_plist" >/dev/null 2>&1; then
      echo "Emulator launchd label: $launch_label"
      echo "Emulator log: $log_file"
      return
    fi
    echo "launchd boot failed; falling back to nohup." >&2
  fi

  nohup env \
    ANDROID_AVD_HOME="$AVD_HOME" \
    ANDROID_HOME="${ANDROID_HOME:-$SDK_ROOT}" \
    ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$SDK_ROOT}" \
    DYLD_LIBRARY_PATH="$EMULATOR_DYLD_LIBRARY_PATH" \
    DYLD_FALLBACK_LIBRARY_PATH="$EMULATOR_DYLD_FALLBACK_LIBRARY_PATH" \
    "$EMULATOR_BIN" \
    -avd "$AVD_NAME" \
    $(emulator_port_args) \
    -gpu "$GPU_MODE" \
    -no-snapshot-load \
    -no-snapshot-save \
    -no-boot-anim \
    -no-metrics \
    -no-audio \
    -skip-adb-auth \
    $(emulator_writable_system_args) \
    -netdelay none \
    -netspeed full \
    -dns-server 192.168.1.1,223.5.5.5,119.29.29.29,8.8.8.8 \
    -prop "ro.product.brand=$DEVICE_BRAND" \
    -prop "ro.product.manufacturer=$DEVICE_MANUFACTURER" \
    -prop "ro.product.model=$DEVICE_MODEL" \
    -prop "ro.product.name=$DEVICE_PRODUCT" \
    -prop "ro.product.device=$DEVICE_DEVICE" \
    -prop "ro.product.system.brand=$DEVICE_BRAND" \
    -prop "ro.product.system.manufacturer=$DEVICE_MANUFACTURER" \
    -prop "ro.product.system.model=$DEVICE_MODEL" \
    -prop "ro.product.system.name=$DEVICE_PRODUCT" \
    -prop "ro.product.system.device=$DEVICE_DEVICE" \
    -prop "ro.product.vendor.brand=$DEVICE_BRAND" \
    -prop "ro.product.vendor.manufacturer=$DEVICE_MANUFACTURER" \
    -prop "ro.product.vendor.model=$DEVICE_MODEL" \
    -prop "ro.product.vendor.name=$DEVICE_PRODUCT" \
    -prop "ro.product.vendor.device=$DEVICE_DEVICE" \
    -prop "ro.build.product=$DEVICE_DEVICE" \
    -prop "ro.product.board=$DEVICE_DEVICE" \
    -prop "persist.macos.virtual.model_code=$DEVICE_MODEL_CODE" \
    -memory "$MEMORY_MB" \
    -cores "$CORES" \
    -vsync-rate "$FPS" \
    >"$log_file" 2>&1 </dev/null &
  local emulator_pid=$!
  echo "Emulator pid: $emulator_pid"
  echo "Emulator log: $log_file"
  disown "$emulator_pid" >/dev/null 2>&1 || true
}

prepare_game_screen() {
  ensure_landscape_window
  adb_shell settings put secure show_rotation_suggestions 0 >/dev/null 2>&1 || true
  adb_shell settings put global policy_control "immersive.full=*" >/dev/null 2>&1 || true
  adb_shell settings put system volume_music 0 >/dev/null 2>&1 || true
  adb_shell media volume --stream 3 --set 0 >/dev/null 2>&1 || true
  adb_shell wm size reset >/dev/null 2>&1 || true
  adb_shell wm density reset >/dev/null 2>&1 || true
}

repair_network() {
  "$ADB_BIN" -s "$SERIAL" root >/dev/null 2>&1 || true
  local waited=0
  while ! device_ready && [ "$waited" -lt 20 ]; do
    sleep 1
    waited=$((waited + 1))
  done
  adb_shell settings put global http_proxy :0 >/dev/null 2>&1 || true
  adb_shell settings put global private_dns_mode off >/dev/null 2>&1 || true
  adb_shell settings delete global private_dns_specifier >/dev/null 2>&1 || true
  adb_shell ip -6 addr flush dev eth0 >/dev/null 2>&1 || true
  adb_shell ip -6 addr flush dev wlan0 >/dev/null 2>&1 || true
  adb_shell ip -6 addr flush dev radio0 >/dev/null 2>&1 || true
  adb_shell stop ipv6proxy >/dev/null 2>&1 || true
  adb_shell setprop persist.net.doxlat false >/dev/null 2>&1 || true
  adb_shell svc wifi enable >/dev/null 2>&1 || true
  adb_shell svc data enable >/dev/null 2>&1 || true
  apply_runtime_device_props
  apply_game_hosts_override
  ensure_direct_http_proxy
  if [ "$GAME_DIRECT_HTTP_PROXY" = "1" ]; then
    adb_shell settings put global http_proxy "10.0.2.2:$GAME_DIRECT_PROXY_PORT" >/dev/null 2>&1 || true
  fi
  ensure_direct_tcp_proxies
  apply_guest_direct_proxy_rules
  ensure_game_version_db
}

ensure_game_version_db() {
  local owner
  local tmp_db
  if [ "$GAME_VERSION_GUARD" != "1" ]; then
    return 0
  fi
  if ! adb_shell "[ -f '$GAME_VERSION_DB' ]" >/dev/null 2>&1; then
    log "WARNING: version.db is missing: $GAME_VERSION_DB"
    return 0
  fi
  if adb_shell "sqlite3 '$GAME_VERSION_DB' \"update version set version=$GAME_VERSION_TYPE0 where type=0; update version set version=$GAME_VERSION_TYPE1 where type=1;\"" >/dev/null 2>&1; then
    log "Game version.db guarded: type0=$GAME_VERSION_TYPE0 type1=$GAME_VERSION_TYPE1."
  else
    if ! command -v sqlite3 >/dev/null 2>&1; then
      log "WARNING: could not update $GAME_VERSION_DB; host sqlite3 is missing."
      return 0
    fi
    mkdir -p "$WORK_DIR"
    tmp_db="$WORK_DIR/version.$SERIAL.$$.db"
    owner="$(adb_shell "stat -c '%u:%g' '$GAME_VERSION_DB' 2>/dev/null" | tr -d '\r' | head -n 1 || true)"
    if "$ADB_BIN" -s "$SERIAL" pull "$GAME_VERSION_DB" "$tmp_db" >/dev/null 2>&1 &&
      sqlite3 "$tmp_db" "update version set version=$GAME_VERSION_TYPE0 where idx=0; update version set version=$GAME_VERSION_TYPE1 where idx=1;" >/dev/null 2>&1 &&
      "$ADB_BIN" -s "$SERIAL" push "$tmp_db" "$GAME_VERSION_DB" >/dev/null 2>&1; then
      if [ -n "$owner" ]; then
        adb_shell "chown $owner '$GAME_VERSION_DB'" >/dev/null 2>&1 || true
      fi
      adb_shell "chmod 600 '$GAME_VERSION_DB'" >/dev/null 2>&1 || true
      log "Game version.db guarded via host sqlite3: type0=$GAME_VERSION_TYPE0 type1=$GAME_VERSION_TYPE1."
    else
      log "WARNING: could not update $GAME_VERSION_DB."
    fi
    rm -f "$tmp_db"
  fi
}

game_files_owner() {
  local owner
  owner="$(adb_shell "stat -c '%u:%g' '$GAME_FILES_DIR' 2>/dev/null" | tr -d '\r' | head -n 1 || true)"
  if [ -n "$owner" ]; then
    printf '%s\n' "$owner"
    return 0
  fi
  printf 'u0_a88:u0_a88\n'
}

sync_resources_patch() {
  local imageset_dir layout_dir base owner data_size cegui_size
  imageset_dir="$CEGUI_PATCH_IMAGESET_DIR"
  layout_dir="$CEGUI_PATCH_LAYOUT_DIR"
  base="$GAME_FILES_DIR/cegui"

  for patch_file in \
    "$imageset_dir/basiccomponent01.imageset" \
    "$imageset_dir/basiccomponent10.imageset" \
    "$imageset_dir/basiccomponent21.imageset" \
    "$layout_dir/root.layout"; do
    if [ ! -f "$patch_file" ]; then
      echo "Missing resource patch file: $patch_file" >&2
      exit 1
    fi
  done

  adb_shell am force-stop "$GAME_PACKAGE" >/dev/null 2>&1 || true
  if ! adb_shell "[ -d '$GAME_FILES_DIR/data' ] && [ -d '$base/imagesets' ] && [ -d '$base/layouts' ]" >/dev/null 2>&1; then
    echo "Game resource directories are missing on $SERIAL: $GAME_FILES_DIR" >&2
    exit 1
  fi

  data_size="$(adb_shell "du -sh '$GAME_FILES_DIR/data' 2>/dev/null | awk '{print \$1}'" | tr -d '\r' || true)"
  cegui_size="$(adb_shell "du -sh '$base' 2>/dev/null | awk '{print \$1}'" | tr -d '\r' || true)"
  log "Resource status before patch: data=${data_size:-unknown}, cegui=${cegui_size:-unknown}."

  owner="$(game_files_owner)"
  "$ADB_BIN" -s "$SERIAL" push "$imageset_dir/basiccomponent01.imageset" "$base/imagesets/basiccomponent01.imageset" >/dev/null
  "$ADB_BIN" -s "$SERIAL" push "$imageset_dir/basiccomponent10.imageset" "$base/imagesets/basiccomponent10.imageset" >/dev/null
  "$ADB_BIN" -s "$SERIAL" push "$imageset_dir/basiccomponent21.imageset" "$base/imagesets/basiccomponent21.imageset" >/dev/null
  "$ADB_BIN" -s "$SERIAL" push "$layout_dir/root.layout" "$base/layouts/root.layout" >/dev/null

  adb_shell "chown $owner '$base/imagesets/basiccomponent01.imageset' '$base/imagesets/basiccomponent10.imageset' '$base/imagesets/basiccomponent21.imageset' '$base/layouts/root.layout'; chmod 600 '$base/imagesets/basiccomponent01.imageset' '$base/imagesets/basiccomponent10.imageset' '$base/imagesets/basiccomponent21.imageset' '$base/layouts/root.layout'" >/dev/null 2>&1 || true

  adb_shell "grep -q 'ICN_Class_00_S' '$base/imagesets/basiccomponent01.imageset' && grep -q 'Img_Item_Type_Premium' '$base/imagesets/basiccomponent10.imageset' && grep -q 'FirstPurchaseEvent_Bg' '$base/imagesets/basiccomponent21.imageset' && ! grep -q 'MouseAutoRepeatEnabled' '$base/layouts/root.layout'" >/dev/null
  log "Resource CEGUI patch synced on $SERIAL without copying account data."
}

apply_runtime_device_props() {
  adb_shell setprop gsm.version.baseband "$GAME_BASEBAND" >/dev/null 2>&1 || true
}

ensure_direct_http_proxy() {
  if [ "$GAME_DIRECT_HTTP_PROXY" != "1" ]; then
    return 0
  fi
  if [ ! -x "$GAME_DIRECT_PROXY_SCRIPT" ]; then
    log "WARNING: direct HTTP proxy script is missing: $GAME_DIRECT_PROXY_SCRIPT"
    return 0
  fi
  if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$GAME_DIRECT_PROXY_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    return 0
  fi

  prepare_host_work_dirs
  local resolve_args=()
  local entry
  for entry in $GAME_DIRECT_PROXY_RESOLVE; do
    resolve_args+=(--resolve "$entry")
  done
  nohup "$GAME_DIRECT_PROXY_PYTHON" -u "$GAME_DIRECT_PROXY_SCRIPT" \
    --listen 0.0.0.0 \
    --port "$GAME_DIRECT_PROXY_PORT" \
    --iface "$GAME_DIRECT_PROXY_IFACE" \
    "${resolve_args[@]}" \
    >"$LOG_DIR/mos-bound-http-proxy.log" 2>&1 &
  log "Started direct HTTP proxy on 10.0.2.2:$GAME_DIRECT_PROXY_PORT via $GAME_DIRECT_PROXY_IFACE."
}

apply_guest_direct_proxy_rules() {
  if [ "$GAME_DIRECT_HTTP_PROXY" = "1" ]; then
    local ip
    for ip in $GAME_DIRECT_PROXY_IPS; do
      adb_shell iptables -t nat -D OUTPUT -p tcp -d "$ip" --dport 80 -j DNAT --to-destination "10.0.2.2:$GAME_DIRECT_PROXY_PORT" >/dev/null 2>&1 || true
      if adb_shell iptables -t nat -I OUTPUT 1 -p tcp -d "$ip" --dport 80 -j DNAT --to-destination "10.0.2.2:$GAME_DIRECT_PROXY_PORT" >/dev/null 2>&1; then
        log "Guest direct HTTP proxy: $ip:80 -> 10.0.2.2:$GAME_DIRECT_PROXY_PORT"
      else
        log "WARNING: could not install guest direct proxy rule for $ip."
      fi
    done
  fi

  if [ "$GAME_DIRECT_TCP_PROXY" = "1" ]; then
    local entry target local_port target_host target_port
    for entry in $GAME_DIRECT_TCP_PROXIES; do
      target="${entry%%=*}"
      local_port="${entry#*=}"
      target_host="${target%:*}"
      target_port="${target##*:}"
      adb_shell iptables -t nat -D OUTPUT -p tcp -d "$target_host" --dport "$target_port" -j DNAT --to-destination "10.0.2.2:$local_port" >/dev/null 2>&1 || true
      if adb_shell iptables -t nat -I OUTPUT 1 -p tcp -d "$target_host" --dport "$target_port" -j DNAT --to-destination "10.0.2.2:$local_port" >/dev/null 2>&1; then
        log "Guest direct TCP proxy: $target_host:$target_port -> 10.0.2.2:$local_port"
      else
        log "WARNING: could not install guest direct TCP proxy rule for $target_host:$target_port."
      fi
    done
  fi
}

ensure_direct_tcp_proxies() {
  if [ "$GAME_DIRECT_TCP_PROXY" != "1" ]; then
    return 0
  fi
  if [ ! -x "$GAME_DIRECT_PROXY_SCRIPT" ]; then
    log "WARNING: direct TCP proxy script is missing: $GAME_DIRECT_PROXY_SCRIPT"
    return 0
  fi

  prepare_host_work_dirs
  local entry target local_port target_host target_port
  for entry in $GAME_DIRECT_TCP_PROXIES; do
    target="${entry%%=*}"
    local_port="${entry#*=}"
    target_host="${target%:*}"
    target_port="${target##*:}"
    if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:"$local_port" -sTCP:LISTEN >/dev/null 2>&1; then
      continue
    fi
    nohup "$GAME_DIRECT_PROXY_PYTHON" -u "$GAME_DIRECT_PROXY_SCRIPT" \
      --listen 0.0.0.0 \
      --port "$local_port" \
      --iface "$GAME_DIRECT_PROXY_IFACE" \
      --tcp-target "$target_host:$target_port" \
      >"$LOG_DIR/mos-bound-tcp-proxy-$local_port.log" 2>&1 &
    log "Started direct TCP proxy on 10.0.2.2:$local_port -> $target_host:$target_port via $GAME_DIRECT_PROXY_IFACE."
  done
}

apply_game_hosts_override() {
  if [ "$GAME_HOSTS_OVERRIDE" != "1" ]; then
    prepare_host_work_dirs
    local hosts_file local_hosts
    hosts_file="/data/local/tmp/mos-game-hosts-clean"
    local_hosts="$(mktemp "${TMPDIR:-/tmp}/mos-game-hosts-clean.XXXXXX")"
    printf '127.0.0.1 localhost\n::1 ip6-localhost\n' >"$local_hosts"
    "$ADB_BIN" -s "$SERIAL" root >/dev/null 2>&1 || true
    "$ADB_BIN" -s "$SERIAL" remount >/dev/null 2>&1 || true
    if "$ADB_BIN" -s "$SERIAL" push "$local_hosts" "$hosts_file" >/dev/null 2>&1; then
      adb_shell chmod 0644 "$hosts_file" >/dev/null 2>&1 || true
      adb_shell umount /system/etc/hosts >/dev/null 2>&1 || true
      if adb_shell "cp '$hosts_file' /system/etc/hosts && chmod 0644 /system/etc/hosts && (restorecon /system/etc/hosts 2>/dev/null || chcon u:object_r:system_file:s0 /system/etc/hosts 2>/dev/null || true)" >/dev/null 2>&1; then
        log "Guest hosts override disabled; guest hosts reset to localhost only."
      fi
    fi
    rm -f "$local_hosts"
    return 0
  fi

  prepare_host_work_dirs
  local ip hosts_file local_hosts name wrote_any
  hosts_file="/data/local/tmp/mos-game-hosts"
  local_hosts="$(mktemp "${TMPDIR:-/tmp}/mos-game-hosts.XXXXXX")"
  printf '127.0.0.1 localhost\n::1 ip6-localhost\n' >"$local_hosts"
  wrote_any=0
  for name in $GAME_HOSTS_NAMES; do
    ip="$GAME_HOSTS_IP"
    if [ -z "$ip" ] && command -v dig >/dev/null 2>&1; then
      ip="$(dig +short "$name" A 2>/dev/null | awk '/^[0-9.]+$/ { print; exit }')"
    fi
    if [ -z "$ip" ]; then
      ip="$GAME_HOSTS_FALLBACK_IP"
    fi
    if [ -n "$ip" ]; then
      printf '%s %s\n' "$ip" "$name" >>"$local_hosts"
      wrote_any=1
    else
      log "WARNING: could not resolve guest hosts entry for $name."
    fi
  done
  if [ "$wrote_any" != "1" ]; then
    rm -f "$local_hosts"
    log "WARNING: guest hosts override requested but no host entries were resolved."
    return 0
  fi
  "$ADB_BIN" -s "$SERIAL" root >/dev/null 2>&1 || true
  "$ADB_BIN" -s "$SERIAL" remount >/dev/null 2>&1 || true
  if ! "$ADB_BIN" -s "$SERIAL" push "$local_hosts" "$hosts_file" >/dev/null 2>&1; then
    rm -f "$local_hosts"
    log "WARNING: could not prepare non-empty guest hosts override; existing hosts left unchanged."
    return 0
  fi
  rm -f "$local_hosts"
  adb_shell chmod 0644 "$hosts_file" >/dev/null 2>&1 || true
  adb_shell umount /system/etc/hosts >/dev/null 2>&1 || true
  if adb_shell "cp '$hosts_file' /system/etc/hosts && chmod 0644 /system/etc/hosts && (restorecon /system/etc/hosts 2>/dev/null || chcon u:object_r:system_file:s0 /system/etc/hosts 2>/dev/null || true)" >/dev/null 2>&1; then
    log "Guest hosts override applied for: $GAME_HOSTS_NAMES"
  else
    log "WARNING: could not write guest hosts override for $GAME_HOSTS_NAMES."
  fi
}

common_confirm_sweep() {
  skip_if_not_game_foreground && return 0
  cancel_self_drawn_danger_dialogs
  safe_back 0.4
  tap 890 445 0.25
  tap 48 104 0.25
  tap 523 472 0.25
  tap 447 484 0.25
  tap 650 526 0.25
  tap 640 610 0.25
  tap 640 650 0.25
  tap 389 98 0.2
  tap 1194 42 0.2
  tap 1237 44 0.2
}

skip_tutorial_popups() {
  skip_if_not_game_foreground && return 0
  cancel_self_drawn_danger_dialogs
  safe_back 0.5
  tap 125 48 0.5
  tap 523 472 0.5
  tap 650 526 0.5
  tap 640 610 0.5
  tap 389 98 0.25
  tap 1194 42 0.25
  tap 1237 44 0.25
}

main_quest_cycle() {
  ensure_game_foreground || return 0
  tap 1237 44 0.25
  tap 96 296 12.0
  tap 222 471 1.1
  tap 222 471 1.1
  tap 650 526 0.8
  tap 125 48 0.6
  tap 523 472 0.7
  tap 1088 626 0.8
}

battle_auto_cycle() {
  ensure_game_foreground || return 0
  tap 1088 626 0.8
  tap 1053 492 1.0
  tap 1240 655 1.5
  tap 1193 492 1.5
  tap 414 552 1.0
}

upgrade_allocate() {
  ensure_game_foreground || return 0
  tap 50 45 0.8
  tap 207 629 0.5
  tap 327 629 0.5
  tap 389 98 0.35
  tap 1237 44 0.25
}

daily_rewards_sweep() {
  ensure_game_foreground || return 0
  tap 1240 40 0.5
  tap 1168 32 1.0
  common_confirm_sweep
  tap 1240 40 0.5
  tap 900 486 1.0
  common_confirm_sweep
  tap 1240 40 0.5
  tap 967 486 1.0
  common_confirm_sweep
  tap 1240 40 0.5
  tap 966 398 1.0
  common_confirm_sweep
  tap 1240 40 0.5
  tap 966 32 1.0
  common_confirm_sweep
}

buy_potions_assist() {
  ensure_game_foreground || return 0
  tap 1237 44 0.25
  tap 1042 240 1.0
  tap 640 610 0.5
  tap 1175 372 0.5
  tap 650 526 0.5
  tap 640 610 0.5
  tap 1237 44 0.25
}

disconnect_confirm_sweep() {
  skip_if_not_game_foreground && return 0
  cancel_self_drawn_danger_dialogs
  tap 890 445 1.0
  tap 48 104 1.0
  cancel_self_drawn_danger_dialogs
  tap 447 484 1.0
  tap 1193 38 1.0
  tap 1193 38 1.0
  tap 523 472 0.5
  tap 640 610 0.5
}

start_cabal_activity() {
  adb_shell am start -n "$GAME_PACKAGE/com.estsoft.cabal.androidtv.CabalActivity" >/dev/null 2>&1 || true
  scaled_sleep 2
}

handle_webview_browser() {
  if ! webview_browser_foreground; then
    return 1
  fi
  log "WebView Browser Tester is foreground; press BACK to return to the game shell."
  safe_back 2.0
  # Historical successful runs sometimes showed an exit confirmation here.
  tap 340 366 0.8
  tap 523 472 0.8
  return 0
}

handle_sdk_announcement() {
  local focus
  focus="$(foreground_component || true)"
  case "$focus" in
    "$GAME_PACKAGE"/com.iccgame.sdk.SplashActivity|"$GAME_PACKAGE"/com.estsoft.cabal.androidtv.CabalActivity)
      log "Try closing SDK announcement and returning through WebView Browser Tester."
      tap 1196 35 2.0
      if handle_webview_browser; then
        return 0
      fi
      # Some emulator runs keep the announcement under SplashActivity until the native game
      # activity is nudged; this is the path verified on the test Mac.
      start_cabal_activity
      tap 1196 35 2.0
      handle_webview_browser || true
      ;;
  esac
}

enter_cached_character_flow() {
  skip_if_not_game_foreground && return 1
  # Server landing page: "please tap screen".
  tap 640 455 8.0
  # Character page: start the selected character.
  tap 1120 672 30.0
  # Store and sign-in popups that can cover the real scene.
  tap 1010 39 1.0
  tap 1010 43 1.0
}

play_to_main_scene() {
  local waited=0
  local next_data_log=0
  local initial_wait_seconds="${INITIAL_PLAY_WAIT_SECONDS:-60}"
  local post_data_wait_done=0
  while [ "$waited" -lt "$LOAD_WAIT_SECONDS" ]; do
    dismiss_system_anr
    if [ "$waited" -lt "$initial_wait_seconds" ]; then
      log "Initial game startup wait (${waited}s/${initial_wait_seconds}s)."
      scaled_sleep 10
      waited=$((waited + 10))
      continue
    fi
    if ! is_game_foreground && ! webview_browser_foreground; then
      if recover_system_foreground; then
        scaled_sleep 5
        waited=$((waited + 5))
        continue
      fi
      log "Waiting for game foreground (${waited}s)."
      scaled_sleep 5
      waited=$((waited + 5))
      continue
    fi
    if loading_data_visible; then
      if [ "$waited" -ge "$next_data_log" ]; then
        log "Still on Data loading screen (${waited}s); wait without tapping."
        next_data_log=$((waited + 60))
      fi
      scaled_sleep 10
      waited=$((waited + 10))
      continue
    fi
    if [ "$post_data_wait_done" = "0" ]; then
      log "Data loading cleared; wait ${POST_DATA_WAIT_SECONDS}s before closing announcements."
      scaled_sleep "$POST_DATA_WAIT_SECONDS"
      waited=$((waited + POST_DATA_WAIT_SECONDS))
      post_data_wait_done=1
      continue
    fi
    handle_webview_browser && { scaled_sleep 4; waited=$((waited + 4)); continue; }
    handle_sdk_announcement
    log "Try cached-login server/character flow after Data loading cleared (${waited}s)."
    enter_cached_character_flow || true
    dismiss_system_anr
    log "Cached-login flow was attempted; stop scripted taps and leave the game running."
    return 0
    scaled_sleep 10
    waited=$((waited + 10))
  done
}

enter_game_after_load() {
  local waited=0
  local data_ticks=0
  local center_tap_done=0
  local back_done=0
  while [ "$waited" -lt "$LOAD_WAIT_SECONDS" ]; do
    dismiss_system_anr
    handle_webview_browser && continue
    handle_sdk_announcement
    if login_or_server_screen_visible; then
      log "Login/server screen is visible; stop load recovery."
      return 0
    fi
    ensure_game_foreground || true
    scaled_sleep 10
    waited=$((waited + 10))
    dismiss_system_anr
    if login_or_server_screen_visible; then
      log "Login/server screen is visible; stop load recovery."
      return 0
    fi
    if loading_data_visible; then
      data_ticks=$((data_ticks + 1))
      log "Still on Data loading screen (${waited}s)."
      if [ "$data_ticks" -ge 6 ] && [ "$center_tap_done" = "0" ]; then
        log "Nudge Data loading screen with one center tap."
        tap 592 360 2.0
        center_tap_done=1
        continue
      fi
      if [ "$data_ticks" -ge 12 ] && [ "$back_done" = "0" ]; then
        log "Nudge stuck SDK/game surface with one BACK key."
        safe_back 3.0
        back_done=1
        continue
      fi
    else
      data_ticks=0
    fi
    skip_if_not_game_foreground && continue
    tap 1194 42 0.8
    login_or_server_screen_visible && return 0
    tap 447 484 0.8
    login_or_server_screen_visible && return 0
    tap 640 610 1.2
    login_or_server_screen_visible && return 0
    tap 765 590 1.2
    login_or_server_screen_visible && return 0
    tap 641 674 1.2
    login_or_server_screen_visible && return 0
    tap 1115 674 1.2
    tap 1115 674 1.2
    tap 640 610 0.8
    tap 523 472 0.8
  done
}

start_game() {
  adb_shell am force-stop com.android.chrome >/dev/null 2>&1 || true
  adb_shell am force-stop com.google.android.googlequicksearchbox >/dev/null 2>&1 || true
  adb_shell monkey -p "$GAME_PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || \
    adb_shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$GAME_PACKAGE/$GAME_ACTIVITY" >/dev/null 2>&1 || true
  scaled_sleep 8
}

restart_game() {
  adb_shell am force-stop "$GAME_PACKAGE" >/dev/null 2>&1 || true
  scaled_sleep 2
  start_game
}

reconnect_game() {
  disconnect_confirm_sweep
  start_game
  disconnect_confirm_sweep
  enter_game_after_load
}

recover_game() {
  prepare_game_screen
  repair_network
  restart_game
  enter_game_after_load
  skip_tutorial_popups
}

play_game() {
  prepare_game_screen
  repair_network
  restart_game
  play_to_main_scene
  skip_tutorial_popups
}

full_assist_cycle() {
  reconnect_game
  skip_tutorial_popups
  upgrade_allocate
  daily_rewards_sweep
  main_quest_cycle
  battle_auto_cycle
}

usage() {
  cat <<'EOF'
新惊天动地独立辅助宏

用法:
  ./cabal_macro_runner.sh <动作> [重复次数]

动作:
  skip          跳过教程/确认/领奖/关闭常见弹窗
  quest         主线任务循环：点任务、自动寻路、对话、领奖、开 AUTO
  battle        战斗辅助循环：AUTO、普攻、技能、COMBO、药水
  upgrade       升级后自动分配属性点并关闭角色面板
  daily         每日奖励扫一遍：邮箱、活动、礼物盒、通行证等常见入口
  buy_potions   买药辅助入口：打开 NPC/商店相关入口并点常见购买确认
  sync_resources 同步已验证资源补丁：只修复本地资源文件，不复制账号数据
  network       修复模拟器内网络：清代理、Private DNS、IPv6、ipv6proxy
  reconnect     处理服务器断开/公告/登录确认，尝试重新进入游戏
  recover       更强恢复：无设备时自动启动模拟器，重启游戏，处理断线和公告
  play          启动并尽量进入真实主游戏场景：公告/WebView/服务器/角色/常见弹窗
  enter         等待下载完成，持续关闭公告并尝试进入游戏
  full          综合执行：skip + upgrade + daily + quest + battle

例子:
  ./cabal_macro_runner.sh quest 5
  ./cabal_macro_runner.sh battle 20
  ./cabal_macro_runner.sh recover 1
  ./cabal_macro_runner.sh play 1
  ./cabal_macro_runner.sh enter 1
  SPEED=1.3 ./cabal_macro_runner.sh quest 3

停止:
  关闭终端窗口，或按 Control+C。

环境变量:
  SERIAL=emulator-5554
	  AVD_NAME=macos_game_a9_01
	  EMULATOR_PORT=5554
	  GPU_MODE=swangle
	  MEMORY_MB=6144
	  CORES=4
	  WORK_DIR=$HOME/CabalmMacKit/tmp
	  TMPDIR=$HOME/CabalmMacKit/tmp/tmp
	  EMULATOR_LAUNCH_METHOD=nohup
	  EMULATOR_LOG_FILE=$HOME/CabalmMacKit/tmp/macos_game_a9_01-swangle.log
	  GAME_DIRECT_HTTP_PROXY=1
	  FPS=30
  WRITABLE_SYSTEM=1
  AUTO_BOOT=1
  LOAD_WAIT_SECONDS=120
  HOST_DIRECT_DOMAIN=cabalm.iccgame.com
  CHECK_HOST_ROUTE=1
  STOP_HOST_VPN_FOR_GAME=0
  ALLOW_HOST_VPN_STOP_FOR_GAME=0
  ADB=$HOME/Library/Android/sdk/platform-tools/adb
EOF
}

run_once() {
  case "$ACTION" in
    skip) skip_tutorial_popups ;;
    quest) main_quest_cycle ;;
    battle) battle_auto_cycle ;;
    upgrade) upgrade_allocate ;;
    daily) daily_rewards_sweep ;;
    buy_potions) buy_potions_assist ;;
    sync_resources) sync_resources_patch ;;
    network) repair_network ;;
    reconnect) reconnect_game ;;
    recover) recover_game ;;
    play) play_game ;;
    enter) enter_game_after_load ;;
    full) full_assist_cycle ;;
    help|--help|-h) usage; exit 0 ;;
    *)
      usage
      echo "Unknown action: $ACTION" >&2
      exit 2
      ;;
  esac
}

case "$ACTION" in
  help|--help|-h)
    usage
    exit 0
    ;;
esac

ensure_host_direct_route
ensure_device
prepare_game_screen

case "$REPEAT" in
  ''|*[!0-9]*)
    echo "Repeat count must be a positive integer: $REPEAT" >&2
    exit 2
    ;;
esac

if [ "$REPEAT" -lt 1 ]; then
  REPEAT=1
fi

echo "Running $ACTION x $REPEAT on $SERIAL using $ADB_BIN"
i=1
while [ "$i" -le "$REPEAT" ]; do
  echo "Cycle $i/$REPEAT"
  run_once
  i=$((i + 1))
done
echo "Done."
