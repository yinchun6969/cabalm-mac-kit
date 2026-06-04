# 新惊天动地 Mac 模拟器工具包

这是一个可分享的 macOS 工具包，用来安装启动脚本、桌面快捷方式、网络修复、资源同步入口、24 小时属性面板关闭/自动分配属性点守护，以及诊断脚本。

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
EMULATOR_LAUNCH_METHOD=terminal
LOAD_WAIT_SECONDS=600
```

## 常用命令

```bash
~/CabalmMacKit/scripts/cabal_macro_runner.sh play 1
~/CabalmMacKit/scripts/cabal_macro_runner.sh recover 1
~/CabalmMacKit/scripts/cabal_macro_runner.sh network 1
~/CabalmMacKit/scripts/cabal_attr_guard.sh start
~/CabalmMacKit/scripts/cabal_attr_guard.sh stop
~/CabalmMacKit/scripts/diagnose.sh
```

## 已知状态

当前验证出的正确配置是：保留宿主 VPN、模拟器 hosts 只保留 localhost、`version.db` 固定为 `type 0=55` 和 `type 1=8`，Android Emulator 36.5.11 使用 `swangle`、6144 MB、4 核、30 FPS，并通过 Terminal 启动，避免后台/nohup 启动被 macOS 关掉窗口。

在测试 Mac 上，`host` GPU 可以较快到登录和角色界面，但进入 3D 主场景容易黑屏。`swangle` 路线已验证能进入真实 3D 主游戏场景，并稳定运行 60 秒以上。公告页的关键路径是：关闭游戏公告后进入 WebView Browser Tester，按返回回到游戏服务器页，再点击服务器页和角色页进入主场景。
