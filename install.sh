#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="$HOME/CabalmMacKit"
if [ -d /Volumes/DDISK ]; then
  DEFAULT_INSTALL_DIR="/Volumes/DDISK/macOS/CabalmMacKit"
fi
INSTALL_DIR="${CABALM_HOME:-$DEFAULT_INSTALL_DIR}"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"

mkdir -p "$INSTALL_DIR/scripts" "$INSTALL_DIR/config" "$INSTALL_DIR/tmp" "$INSTALL_DIR/logs" "$INSTALL_DIR/resource_chunks" "$INSTALL_DIR/apk"
cp "$SOURCE_DIR"/scripts/*.sh "$INSTALL_DIR/scripts/"
cp "$SOURCE_DIR"/scripts/mos-bound-http-proxy.py "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR"/scripts/*.sh "$INSTALL_DIR/scripts/mos-bound-http-proxy.py"

if [ ! -f "$INSTALL_DIR/config/cabalm.env" ]; then
  cp "$SOURCE_DIR/config/cabalm.env.example" "$INSTALL_DIR/config/cabalm.env"
fi

set_config_value() {
  local key="$1"
  local value="$2"
  local tmp_config
  tmp_config="$(mktemp)"
  awk -v key="$key" -v line="$key=$value" '
    BEGIN { done = 0 }
    $0 ~ "^" key "=" {
      print line
      done = 1
      next
    }
    { print }
    END {
      if (done == 0) {
        print line
      }
    }
  ' "$INSTALL_DIR/config/cabalm.env" >"$tmp_config"
  mv "$tmp_config" "$INSTALL_DIR/config/cabalm.env"
}

if [ -d "/Volumes/DDISK/macOS/Android/avd" ]; then
  tmp_config="$(mktemp)"
  awk '
    BEGIN { done = 0 }
    /^CABALM_AVD_HOME=/ {
      print "CABALM_AVD_HOME=\"/Volumes/DDISK/macOS/Android/avd\""
      done = 1
      next
    }
    { print }
    END {
      if (done == 0) {
        print "CABALM_AVD_HOME=\"/Volumes/DDISK/macOS/Android/avd\""
      }
    }
  ' "$INSTALL_DIR/config/cabalm.env" >"$tmp_config"
  mv "$tmp_config" "$INSTALL_DIR/config/cabalm.env"
fi

set_config_value GPU_MODE swangle
set_config_value CABALM_HOME "$INSTALL_DIR"
set_config_value MEMORY_MB 6144
set_config_value CORES 4
set_config_value FPS 30
set_config_value EMULATOR_LAUNCH_METHOD nohup
set_config_value LOAD_WAIT_SECONDS 600
set_config_value POST_DATA_WAIT_SECONDS 45

make_command() {
  local path="$1"
  local body="$2"
  printf '%s\n' "$body" >"$path"
  chmod +x "$path"
}

make_command "$DESKTOP_DIR/启动新惊天动地1号实例.command" "#!/usr/bin/env bash
set -euo pipefail
trap '\"$INSTALL_DIR/scripts/close_this_terminal_later.sh\" 1.0 >/dev/null 2>&1 || true' EXIT
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
export SERIAL=emulator-5554
export AVD_NAME=macos_game_a9_01
export EMULATOR_PORT=5554
export GPU_MODE=swangle
export MEMORY_MB=6144
export CORES=4
export EMULATOR_LAUNCH_METHOD=nohup
export LOAD_WAIT_SECONDS=600
export POST_DATA_WAIT_SECONDS=45
cd \"$INSTALL_DIR/scripts\"
./cabal_macro_runner.sh play 1
./close_idle_emulator_terminal_windows.sh >/dev/null 2>&1 || true"

make_command "$DESKTOP_DIR/启动新惊天动地双开.command" "#!/usr/bin/env bash
set -euo pipefail
trap '\"$INSTALL_DIR/scripts/close_this_terminal_later.sh\" 1.0 >/dev/null 2>&1 || true' EXIT
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
export GPU_MODE=swangle
export MEMORY_MB=6144
export CORES=4
export EMULATOR_LAUNCH_METHOD=nohup
export STOP_HOST_VPN_FOR_GAME=0
export ALLOW_HOST_VPN_STOP_FOR_GAME=0
export GAME_HOSTS_OVERRIDE=0
export GAME_HOSTS_IP=
cd \"$INSTALL_DIR/scripts\"
env SERIAL=emulator-5554 AVD_NAME=macos_game_a9_01 EMULATOR_PORT=5554 ./cabal_macro_runner.sh network 1
env SERIAL=emulator-5556 AVD_NAME=macos_game_a9_02 EMULATOR_PORT=5556 ./cabal_macro_runner.sh network 1
echo \"双开启动流程完成。请分别使用不同账号登录，避免互踢。\"
./close_idle_emulator_terminal_windows.sh >/dev/null 2>&1 || true"

make_command "$DESKTOP_DIR/启动新惊天动地三开.command" "#!/usr/bin/env bash
set -euo pipefail
trap '\"$INSTALL_DIR/scripts/close_this_terminal_later.sh\" 1.0 >/dev/null 2>&1 || true' EXIT
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
export GPU_MODE=swangle
export MEMORY_MB=6144
export CORES=4
export EMULATOR_LAUNCH_METHOD=nohup
export STOP_HOST_VPN_FOR_GAME=0
export ALLOW_HOST_VPN_STOP_FOR_GAME=0
export GAME_HOSTS_OVERRIDE=0
export GAME_HOSTS_IP=
cd \"$INSTALL_DIR/scripts\"
env SERIAL=emulator-5554 AVD_NAME=macos_game_a9_01 EMULATOR_PORT=5554 ./cabal_macro_runner.sh network 1
env SERIAL=emulator-5556 AVD_NAME=macos_game_a9_02 EMULATOR_PORT=5556 ./cabal_macro_runner.sh network 1
env SERIAL=emulator-5558 AVD_NAME=macos_game_a9_03 EMULATOR_PORT=5558 ./cabal_macro_runner.sh network 1
echo \"三开启动流程完成。请分别使用不同账号登录，避免互踢。\"
./close_idle_emulator_terminal_windows.sh >/dev/null 2>&1 || true"

make_command "$DESKTOP_DIR/新惊天动地辅助菜单.command" "#!/usr/bin/env bash
set -euo pipefail
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
cd \"$INSTALL_DIR/scripts\"
exec ./cabal_assist_menu.sh"

make_command "$DESKTOP_DIR/启动新惊天动地48小时无人值守压测.command" "#!/usr/bin/env bash
set -euo pipefail
trap '\"$INSTALL_DIR/scripts/close_this_terminal_later.sh\" 1.0 >/dev/null 2>&1 || true' EXIT
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
export SERIAL=emulator-5554
cd \"$INSTALL_DIR/scripts\"
./cabal_unattended_48h.sh start
./close_idle_emulator_terminal_windows.sh >/dev/null 2>&1 || true"

make_command "$DESKTOP_DIR/查看新惊天动地48小时压测状态.command" "#!/usr/bin/env bash
set -euo pipefail
trap '\"$INSTALL_DIR/scripts/close_this_terminal_later.sh\" 8.0 >/dev/null 2>&1 || true' EXIT
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
cd \"$INSTALL_DIR/scripts\"
./cabal_unattended_48h.sh status"

make_command "$DESKTOP_DIR/停止新惊天动地48小时压测.command" "#!/usr/bin/env bash
set -euo pipefail
trap '\"$INSTALL_DIR/scripts/close_this_terminal_later.sh\" 2.0 >/dev/null 2>&1 || true' EXIT
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
cd \"$INSTALL_DIR/scripts\"
./cabal_unattended_48h.sh stop"

make_command "$DESKTOP_DIR/关闭空闲模拟器终端窗口.command" "#!/usr/bin/env bash
set -euo pipefail
trap '\"$INSTALL_DIR/scripts/close_this_terminal_later.sh\" 1.0 >/dev/null 2>&1 || true' EXIT
\"$INSTALL_DIR/scripts/close_idle_emulator_terminal_windows.sh\"
"

echo "Installed CabalM Mac Kit to: $INSTALL_DIR"
echo "Config file: $INSTALL_DIR/config/cabalm.env"
echo "Desktop shortcuts were created in: $DESKTOP_DIR"
