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
SERIAL="${SERIAL:-emulator-5554}"
CHUNKS="${CHUNKS:-$CABALM_HOME/resource_chunks}"
WORK_DIR="${WORK_DIR:-$CABALM_HOME/tmp}"
APK="${APK:-$CABALM_HOME/apk/cabalm-base.apk}"
LOG="${LOG:-$WORK_DIR/cabal_resource_sync_${SERIAL}.log}"
PKG="${PKG:-com.u1game.cabalm}"
APP_DIR="/data/data/$PKG"
FILES_DIR="$APP_DIR/files"
DB_DIR="$APP_DIR/databases"
PRESERVE_LOGIN_STATE="${PRESERVE_LOGIN_STATE:-1}"
RESET_ANDROID_ID="${RESET_ANDROID_ID:-0}"
ANDROID_ID_VALUE="${ANDROID_ID_VALUE:-}"

mkdir -p "$WORK_DIR"
: > "$LOG"

log() {
  printf '%s %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG"
}

adb_s() {
  "$ADB" -s "$SERIAL" "$@"
}

remote_owner() {
  adb_s shell "stat -c '%u:%g' '$1' 2>/dev/null" | tr -d '\r' | head -n 1
}

ensure_package() {
  if adb_s shell "pm path '$PKG' >/dev/null 2>&1"; then
    return 0
  fi
  if [ ! -f "$APK" ]; then
    log "missing APK and package is not installed: $APK"
    exit 1
  fi
  log "package is missing; installing APK"
  adb_s push "$APK" /data/local/tmp/cabalm-base.apk >> "$LOG"
  adb_s shell "pm install -r -g /data/local/tmp/cabalm-base.apk" | tr -d '\r' | tee -a "$LOG"
  adb_s shell "rm -f /data/local/tmp/cabalm-base.apk" >/dev/null 2>&1 || true
}

ensure_app_dirs() {
  adb_s shell "mkdir -p '$FILES_DIR/data' '$FILES_DIR/lbkv' '$FILES_DIR/ICCGAME_SDK' '$APP_DIR/cache' '$DB_DIR'"
}

install_tar() {
  local tar_file="$1"
  local remote_dir="$2"
  local base
  base="$(basename "$tar_file")"
  log "installing $base -> $remote_dir"
  adb_s push "$tar_file" "/data/local/tmp/$base" >> "$LOG"
  adb_s shell "cd '$remote_dir' && tar -xf '/data/local/tmp/$base' && rm -f '/data/local/tmp/$base'"
}

if [ ! -d "$CHUNKS" ]; then
  log "missing resource chunks directory: $CHUNKS"
  exit 1
fi

log "waiting for $SERIAL"
adb_s wait-for-device
adb_s root >/dev/null 2>&1 || true
sleep 2
adb_s wait-for-device

ensure_package
ensure_app_dirs

APP_OWNER="$(remote_owner "$APP_DIR" || true)"
FILES_OWNER="$(remote_owner "$FILES_DIR" || true)"
CACHE_OWNER="$(remote_owner "$APP_DIR/cache" || true)"
APP_OWNER="${APP_OWNER:-$FILES_OWNER}"
FILES_OWNER="${FILES_OWNER:-$APP_OWNER}"
CACHE_OWNER="${CACHE_OWNER:-$APP_OWNER}"
if [ "$FILES_OWNER" = "0:0" ] && [ -n "${APP_OWNER:-}" ] && [ "$APP_OWNER" != "0:0" ]; then
  FILES_OWNER="$APP_OWNER"
fi

log "force-stopping game"
adb_s shell "am force-stop '$PKG' || true"

log "owners: app=${APP_OWNER:-unknown} files=${FILES_OWNER:-unknown} cache=${CACHE_OWNER:-unknown}"
log "clearing resource/update cache while preserving ICCGAME_SDK=$PRESERVE_LOGIN_STATE"
adb_s shell "rm -rf '$APP_DIR/cache'/* '$FILES_DIR/data' '$FILES_DIR/lbkv' '$FILES_DIR/arm64-v8a' '$FILES_DIR/armeabi-v7a' '$FILES_DIR/cegui' '$FILES_DIR/shader' '$FILES_DIR/x86' '$FILES_DIR/x86_64'; mkdir -p '$FILES_DIR/data' '$FILES_DIR/lbkv' '$FILES_DIR/ICCGAME_SDK' '$APP_DIR/cache'"

if [ "$PRESERVE_LOGIN_STATE" != "1" ]; then
  log "resetting ICC SDK login state for a fresh secondary instance"
  TMP_BASE="$WORK_DIR/resource_sync_${SERIAL}"
  mkdir -p "$TMP_BASE"
  printf '%s\n' '{"acct_login_persisted":false,"acct_login_times":0,"acct_name":"","acct_password":"","acct_type":0,"acct_list":[],"acct_notice_type":[]}' > "$TMP_BASE/local_storage.dat"
  printf '%s' '?game_id=3088&site_id=3&ad_id=0' > "$TMP_BASE/start_params.dat"
  printf '\0\0\0\0\0\0\1\177' > "$TMP_BASE/assistive_touch.dat"
  adb_s push "$TMP_BASE/local_storage.dat" "$FILES_DIR/ICCGAME_SDK/local_storage.dat" >> "$LOG"
  adb_s push "$TMP_BASE/start_params.dat" "$FILES_DIR/ICCGAME_SDK/start_params.dat" >> "$LOG"
  adb_s push "$TMP_BASE/assistive_touch.dat" "$FILES_DIR/ICCGAME_SDK/assistive_touch.dat" >> "$LOG"
fi

if [ "$RESET_ANDROID_ID" = "1" ] && [ -n "$ANDROID_ID_VALUE" ]; then
  log "resetting android_id"
  adb_s shell "settings put secure android_id '$ANDROID_ID_VALUE'" >/dev/null 2>&1 || true
elif [ "$RESET_ANDROID_ID" = "1" ]; then
  log "RESET_ANDROID_ID=1 was requested but ANDROID_ID_VALUE is empty; skip android_id reset"
fi

for tar_file in "$CHUNKS"/data__*.tar; do
  [ -e "$tar_file" ] || continue
  install_tar "$tar_file" "$FILES_DIR/data"
done

for tar_file in "$CHUNKS"/files__*.tar; do
  [ -e "$tar_file" ] || continue
  install_tar "$tar_file" "$FILES_DIR"
done

for tar_file in "$CHUNKS"/lbkv__*.tar; do
  [ -e "$tar_file" ] || continue
  install_tar "$tar_file" "$FILES_DIR/lbkv"
done

for tar_file in "$CHUNKS"/db__*.tar; do
  [ -e "$tar_file" ] || continue
  install_tar "$tar_file" "$DB_DIR"
done

log "fixing ownership and permissions"
if [ -n "${FILES_OWNER:-}" ]; then
  adb_s shell "chown -R '$FILES_OWNER' '$FILES_DIR' 2>/dev/null || true"
fi
if [ -n "${APP_OWNER:-}" ]; then
  adb_s shell "chown -R '$APP_OWNER' '$DB_DIR' 2>/dev/null || true"
fi
if [ -n "${CACHE_OWNER:-}" ]; then
  adb_s shell "chown -R '$CACHE_OWNER' '$APP_DIR/cache' 2>/dev/null || true"
fi
adb_s shell "chmod -R u+rwX,go-rwx '$FILES_DIR' '$DB_DIR'; chmod 2771 '$APP_DIR/cache' 2>/dev/null || true"

log "final size check"
adb_s shell "du -sh '$APP_DIR/cache' '$FILES_DIR' '$FILES_DIR/data' '$FILES_DIR/cegui' '$FILES_DIR/lbkv' '$DB_DIR' 2>/dev/null; sqlite3 '$DB_DIR/version.db' 'select * from version;' 2>/dev/null || true; df -h /data" | tr -d '\r' | tee -a "$LOG"

log "offline resource sync done"
