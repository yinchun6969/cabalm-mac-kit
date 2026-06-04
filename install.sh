#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${CABALM_HOME:-$HOME/CabalmMacKit}"
DESKTOP_DIR="${DESKTOP_DIR:-$HOME/Desktop}"

mkdir -p "$INSTALL_DIR/scripts" "$INSTALL_DIR/config" "$INSTALL_DIR/tmp" "$INSTALL_DIR/logs" "$INSTALL_DIR/resource_chunks" "$INSTALL_DIR/apk"
cp "$SOURCE_DIR"/scripts/*.sh "$INSTALL_DIR/scripts/"
cp "$SOURCE_DIR"/scripts/mos-bound-http-proxy.py "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR"/scripts/*.sh "$INSTALL_DIR/scripts/mos-bound-http-proxy.py"

if [ ! -f "$INSTALL_DIR/config/cabalm.env" ]; then
  cp "$SOURCE_DIR/config/cabalm.env.example" "$INSTALL_DIR/config/cabalm.env"
fi

make_command() {
  local path="$1"
  local body="$2"
  printf '%s\n' "$body" >"$path"
  chmod +x "$path"
}

make_command "$DESKTOP_DIR/启动新惊天动地1号实例.command" "#!/usr/bin/env bash
set -euo pipefail
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
export SERIAL=emulator-5554
export AVD_NAME=macos_game_a9_01
export EMULATOR_PORT=5554
export EMULATOR_LAUNCH_METHOD=nohup
cd \"$INSTALL_DIR/scripts\"
exec ./cabal_macro_runner.sh recover 1"

make_command "$DESKTOP_DIR/启动新惊天动地三开.command" "#!/usr/bin/env bash
set -euo pipefail
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
export EMULATOR_LAUNCH_METHOD=nohup
export STOP_HOST_VPN_FOR_GAME=0
export ALLOW_HOST_VPN_STOP_FOR_GAME=0
export GAME_HOSTS_OVERRIDE=0
export GAME_HOSTS_IP=
cd \"$INSTALL_DIR/scripts\"
env SERIAL=emulator-5554 AVD_NAME=macos_game_a9_01 EMULATOR_PORT=5554 MEMORY_MB=4096 ./cabal_macro_runner.sh network 1
env SERIAL=emulator-5556 AVD_NAME=macos_game_a9_02 EMULATOR_PORT=5556 MEMORY_MB=4096 ./cabal_macro_runner.sh network 1
env SERIAL=emulator-5558 AVD_NAME=macos_game_a9_03 EMULATOR_PORT=5558 MEMORY_MB=4096 ./cabal_macro_runner.sh network 1
echo \"三开启动流程完成。请分别使用不同账号登录，避免互踢。\"
read -r -p \"按回车关闭窗口...\" _"

make_command "$DESKTOP_DIR/新惊天动地辅助菜单.command" "#!/usr/bin/env bash
set -euo pipefail
export CABALM_HOME=\"$INSTALL_DIR\"
export CONFIG_FILE=\"$INSTALL_DIR/config/cabalm.env\"
cd \"$INSTALL_DIR/scripts\"
exec ./cabal_assist_menu.sh"

make_command "$DESKTOP_DIR/关闭空闲模拟器终端窗口.command" "#!/usr/bin/env bash
set -euo pipefail
\"$INSTALL_DIR/scripts/close_idle_emulator_terminal_windows.sh\"
read -r -p \"按回车关闭窗口...\" _"

echo "Installed CabalM Mac Kit to: $INSTALL_DIR"
echo "Config file: $INSTALL_DIR/config/cabalm.env"
echo "Desktop shortcuts were created in: $DESKTOP_DIR"

