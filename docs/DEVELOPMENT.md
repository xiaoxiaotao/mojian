# 开发指南

所有命令默认在独立仓库根目录执行。在原 ESP32 工作区中，先进入 `projects/agent-todo-display/`。工作区根的 `./pio run -d projects/agent-todo-display/firmware` 仍有效。

## 环境与 Mac 构建

- Apple Silicon、macOS 14+；SwiftUI、AppKit、EventKit、CoreBluetooth、Security、UserNotifications。
- 已验证 SDK 15.2，脚本优先选本机这一 SDK，否则用 `xcrun` 当前 macOS SDK；可用 `MACOS_SDK=/path/to/SDK sh tools/build_macos.sh` 指定。
- Python 3.12+ 用于资源/运行时准备；Node 下载版本和 SHA-256 固定在 `agent-engine/NODE-SOURCE.txt`。
- Agent SDK 固定于锁文件，当前为 `@deepseek-ai/dsh-sdk-client@0.2.1-alpha.5`。这是 alpha 上游，不随意自动升级。

```sh
python3 tools/prepare_agent_runtime.py
export PATH="$PWD/agent-engine/runtime/bin:$PATH"
npm ci --prefix agent-engine
sh tools/build_macos.sh
sh tools/test.sh
```

缺少 Apple 工具时先安装 Command Line Tools；不把别人的 SDK、Node、node_modules 或本机钥匙串复制进 Git。开发签名只用于本地验证，不能替代正式签名和公证。

构建结果是 `dist/墨间.app`。如要生成开发归档：

```sh
ditto -c -k --sequesterRsrc --keepParent dist/墨间.app dist/mojian-mac-arm64.zip
```

## 测试层级

`tools/test.sh` 运行 Mac 原生、C++ 协议及网页布局隔离测试，无需真实 Key，不向设备写画面：

| 原生入口 | 重点 |
| --- | --- |
| `--self-test` | 作息、跨午夜、画面打包、高德解析、Agent提案与持久化 |
| `--reliability-test` | 断线、队列、去重、手机布局保护、Agent超时/停止 |
| `--information-test <输出目录>` | 旧数据兼容、置顶、周边界、日期、天气、各布局保留带 |
| `--task-management-test` | 编辑/撤销/上限、提醒阶段、跨重启去重、通知失败重试 |

新增 `--repeat-test`、`--extension-test` 检查重复事项、合并与共享边界。Python测试包含共享服务和持久分区地址保护。Android instrumentation 入口见 [Android说明](../android/README.md)。

C++ 测试检查 previous/current 寄存器顺序、刷新窗口、分页位图、固定红色保留带。它们不证明实屏光学效果。

## 固件开发

使用 `sh tools/pio.sh run`，脚本会正确选择原工作区缓存或独立克隆的用户级缓存，避免直接把相对 `core_dir` 解析到不期望的位置。Wi-Fi 头文件优先用本项目忽略文件，其次兼容原工作区共享配置。

烧录前核对：GDEY075Z08、DESPI-C02、引脚、供电和实际串口。只有显式执行 `-t upload` 才烧录。修改驱动波形时保留原参考文件并补实物验证记录；不要只凭 HTTP 成功回执判断显示效果。

## 资源生成

- `python3 tools/generate_regions.py`：根据 `config/refresh_regions.json` 生成固件分区。
- `python3 tools/generate_static_accent.py`：需要 Swift 与 Pillow；生成八种固定红色资源、Mac透明PNG及Flash位图。
- `python3 tools/embed_local_page.py`：将设备本地页面转成固件头文件。
- `dist/墨间.app/Contents/MacOS/MoJian --render-previews docs/images`：只生成虚构示例，不读取用户生产清单。

生成后的头文件与资源保留提交，避免普通构建强制要求所有生成工具。

## Android 原生客户端

需要 JDK 17、Android SDK 35、Gradle 8.9。设置 `ANDROID_HOME` 和可执行的 `gradle`，然后：

```sh
sh tools/build_android.sh
```

也可设置 `TODO_ANDROID_TOOLCHAIN` 指向包含 `android-sdk/`、`gradle-8.9/` 的工具链目录；`GRADLE_BIN` 可指定 Gradle 可执行文件。`ANDROID_OFFLINE=1` 仅适用于依赖已缓存的机器。个人覆盖配置放忽略文件 `tools/local-toolchain.env`，不要提交 `android/local.properties`。

## Python 服务与网页兼容路径

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
cp .env.example .env
# 填入随机 TODO_TOKEN；DeepSeek 可选。
.venv/bin/python tools/run_server.py
.venv/bin/python -m unittest discover -s tests -v
```

默认 `127.0.0.1:8787`。仅在需要局域网兼容客户端时配置监听地址。Linux 需用 `TODO_FONT` 指定中文字体。当前原生 Mac 直连模式不需要启动此服务。

## 现场联调工具

下列工具不是普通离线测试，应先阅读源码和对应参数；它们可能写真实屏幕、全刷、导入任务或停止兼容服务：

- `tools/verify_static_accent.py`：读取当前 Mac 状态并向设备提交；`--full` 显式允许全刷。
- `tools/verify_agent_engine.py --live`：隔离工具夹具，但会调用真实模型、消耗 API 额度；需本地 `.env`。
- `tools/check_status.py`：兼容服务状态检查。

普通测试统一用 `tools/test.sh`。不在 CI 中运行 `--live` 或现场设备脚本。

## 个人数据与 Git

Mac运行数据在 `~/Library/Application Support/MoJian/`，包括清单、Agent会话和提醒记录；Key在钥匙串。它们不属于仓库资源。`.env`、本机固件凭据、个人画面、原始日志、依赖和 `dist/` 均被忽略。可在提交前执行 `python3 tools/audit_repository.py` 检查暂存/已跟踪文件。

## 屏幕字体资源

Mac与Android构建会运行`tools/prepare_screen_fonts.py`，首次需联网下载约44MB字体并校验SHA256，缓存于tools/downloads。直接Gradle构建也需要Python3。字体原文件与OFL许可随应用打包，不提交下载缓存。见[屏幕字体](SCREEN_FONTS.md)。
