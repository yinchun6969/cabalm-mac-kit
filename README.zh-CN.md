# 新惊天动地 Mac 模拟器工具包

这是一个可分享的 macOS 工具包，用来安装启动脚本、桌面快捷方式、网络修复、资源同步入口、24 小时属性面板关闭/自动分配属性点守护、48 小时无人值守压测脚本，以及诊断脚本。

安装后的脚本可以脱离 Codex 单独使用。Codex 只负责安装、修复和验证；真正运行时只需要桌面 `.command` 快捷方式或终端里的 `scripts/*.sh`。

不包含内容：

- 不包含游戏 APK、游戏资源、AVD 镜像或任何账号状态。
- 不包含密码、token、日志截图或本机设备标识。
- 不会关闭宿主机 VPN。默认只提示路由状态，并在模拟器内部修复 hosts、代理、Private DNS、IPv6 和 version.db。

## 安装

```bash
unzip cabalm-mac-kit-*.zip
cd cabalm-mac-kit
./install.sh
```

安装到外接盘示例：

```bash
CABALM_HOME=/Volumes/DDISK/macOS/CabalmMacKit ./install.sh
```

安装后会生成桌面快捷方式：

- `启动新惊天动地1号实例.command`
- `启动新惊天动地双开.command`
- `启动新惊天动地三开.command`
- `新惊天动地辅助菜单.command`
- `启动新惊天动地48小时无人值守压测.command`
- `查看新惊天动地48小时压测状态.command`
- `停止新惊天动地48小时压测.command`
- `关闭空闲模拟器终端窗口.command`

## 配置

配置文件在：

```bash
~/CabalmMacKit/config/cabalm.env
```

外接盘安装时在：

```bash
/Volumes/DDISK/macOS/CabalmMacKit/config/cabalm.env
```

关键默认值：

```bash
STOP_HOST_VPN_FOR_GAME=0
ALLOW_HOST_VPN_STOP_FOR_GAME=0
GAME_HOSTS_OVERRIDE=0
GAME_VERSION_GUARD=1
GAME_VERSION_TYPE0=55
GAME_VERSION_TYPE1=8
GPU_MODE=swangle
MEMORY_MB=6144
CORES=4
FPS=30
EMULATOR_LAUNCH_METHOD=nohup
LOAD_WAIT_SECONDS=600
POST_DATA_WAIT_SECONDS=45
```

## 常用命令

```bash
~/CabalmMacKit/scripts/cabal_macro_runner.sh play 1
~/CabalmMacKit/scripts/cabal_macro_runner.sh recover 1
~/CabalmMacKit/scripts/cabal_macro_runner.sh network 1
~/CabalmMacKit/scripts/cabal_attr_guard.sh start
~/CabalmMacKit/scripts/cabal_attr_guard.sh stop
~/CabalmMacKit/scripts/cabal_unattended_48h.sh start
~/CabalmMacKit/scripts/cabal_unattended_48h.sh status
~/CabalmMacKit/scripts/cabal_unattended_48h.sh stop
~/CabalmMacKit/scripts/diagnose.sh
```

外接盘安装时，把上面的 `~/CabalmMacKit` 换成：

```bash
/Volumes/DDISK/macOS/CabalmMacKit
```

## 已知状态

当前验证出的正确配置是：保留宿主 VPN、模拟器 hosts 只保留 localhost、`version.db` 固定为 `type 0=55` 和 `type 1=8`，Android Emulator 36.5.11 使用 `swangle`、6144 MB、4 核、30 FPS。桌面快捷方式默认用 `nohup` 后台启动并自动关闭自己的 Terminal；如果本机权限导致后台方式不能保活，保留一个最小化的 qemu Terminal 承载窗口是正常现象，不要关闭这个窗口，否则模拟器会退出。

在测试 Mac 上，`host` GPU 可以较快到登录和角色界面，但进入 3D 主场景容易黑屏。`swangle` 路线已验证能进入真实 3D 主游戏场景，并稳定运行无人值守任务循环。公告页的关键路径是：关闭游戏公告后进入 WebView Browser Tester，按返回回到游戏服务器页，再点击服务器页和角色页进入主场景。48 小时脚本只执行任务点击、战斗、升级属性分配、关闭人物属性窗口、断线重连和截图记录，不执行系统邮箱领取或每日奖励扫荡，并避免误点“确认退出游戏”。

自绘弹窗规则已经固化：看到“断开连接，是否要返回角色选择窗口？”时点右侧“取消/否”；看到“确认退出游戏”时点左侧“取消”。这两个规则写在 `cabal_macro_runner.sh` 和 `cabal_unattended_48h.sh`，单独运行脚本也会生效。
