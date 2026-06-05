#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CABALM_HOME="${CABALM_HOME:-$(cd "$SCRIPT_DIR/.." && pwd)}"
CONFIG_FILE="${CONFIG_FILE:-$CABALM_HOME/config/cabalm.env}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

MACRO="$SCRIPT_DIR/cabal_macro_runner.sh"
RESOURCE_SYNC="$SCRIPT_DIR/cabal_resource_sync.sh"
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"

printf '\n实例编号：1=macos_game_a9_01, 2=macos_game_a9_02, 3=macos_game_a9_03\n'
read -r -p "选择实例编号，回车默认 1: " instance
instance="${instance:-1}"

case "$instance" in
  1) SERIAL="emulator-5554"; AVD_NAME="macos_game_a9_01"; EMULATOR_PORT=5554 ;;
  2) SERIAL="emulator-5556"; AVD_NAME="macos_game_a9_02"; EMULATOR_PORT=5556 ;;
  3) SERIAL="emulator-5558"; AVD_NAME="macos_game_a9_03"; EMULATOR_PORT=5558 ;;
  *) echo "实例编号无效：$instance"; exit 1 ;;
esac

export SERIAL AVD_NAME EMULATOR_PORT
export GPU_MODE=swangle MEMORY_MB=6144 CORES=4 FPS=30
export EMULATOR_LAUNCH_METHOD="${EMULATOR_LAUNCH_METHOD:-nohup}"
export WORK_DIR="${WORK_DIR:-$CABALM_HOME/tmp}"
export TMPDIR="${TMPDIR:-$WORK_DIR/tmp}"
export STOP_HOST_VPN_FOR_GAME=0 ALLOW_HOST_VPN_STOP_FOR_GAME=0 GAME_HOSTS_OVERRIDE=0 GAME_HOSTS_IP=

tap() {
  "$ADB" -s "$SERIAL" shell input tap "$1" "$2" >/dev/null 2>&1 || true
  sleep "${3:-0.25}"
}

keyevent() {
  "$ADB" -s "$SERIAL" shell input keyevent "$1" >/dev/null 2>&1 || true
  sleep "${2:-0.25}"
}

close_panels() {
  keyevent BACK 0.3
  tap 1050 150 0.25
  close_system_mail_panel
  tap 640 610 0.25
  tap 523 472 0.25
}

system_mail_panel_visible() {
  command -v python3 >/dev/null 2>&1 || return 1
  "$ADB" -s "$SERIAL" exec-out screencap 2>/dev/null | python3 -c '
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
  # Close an already-open system mail window. Do not tap the top-right mail icon.
  system_mail_panel_visible || return 0
  tap 985 116 0.25
}

claim_mail_if_open() {
  tap 962 602 0.8
  tap 640 474 0.6
  tap 1050 150 0.4
}

quest_once() {
  close_panels
  tap 96 296 8
  tap 222 471 0.8
  tap 640 610 0.8
  tap 650 526 0.8
  tap 1086 624 0.5
}

battle_once() {
  close_panels
  tap 1086 624 0.5
  tap 1240 670 0.5
  tap 1190 600 0.5
  tap 1140 520 0.5
}

printf '\n动作：\n'
printf '  1 关闭弹窗/面板\n'
printf '  2 邮箱一键领取并关闭\n'
printf '  3 主线任务 10 轮\n'
printf '  4 自动战斗/技能 30 轮\n'
printf '  5 任务/战斗减负循环 3 轮（不点邮箱）\n'
printf '  6 原宏 full 1 轮\n'
printf '  7 启动24小时属性加点/关闭面板守护\n'
printf '  8 停止24小时属性加点/关闭面板守护\n'
printf '  9 离线补全游戏资源（保留当前账号状态）\n'
printf '  10 只同步 CEGUI 资源补丁\n'
printf '  11 启动并进入真实主游戏场景\n'
read -r -p "选择动作，回车默认 1: " action
action="${action:-1}"

case "$action" in
  1) close_panels ;;
  2) claim_mail_if_open ;;
  3) for _ in $(seq 1 10); do quest_once; done ;;
  4) for _ in $(seq 1 30); do battle_once; done ;;
  5) for _ in $(seq 1 3); do close_panels; quest_once; battle_once; done ;;
  6) "$MACRO" full 1 ;;
  7) "$SCRIPT_DIR/cabal_attr_guard.sh" start ;;
  8) "$SCRIPT_DIR/cabal_attr_guard.sh" stop ;;
  9) PRESERVE_LOGIN_STATE=1 "$RESOURCE_SYNC" ;;
  10) "$MACRO" sync_resources 1 ;;
  11) "$MACRO" play 1 ;;
  *) echo "动作无效：$action"; exit 1 ;;
esac

echo "点击脚本完成：实例 $instance，动作 $action。"
read -r -p "按回车关闭窗口..." _
