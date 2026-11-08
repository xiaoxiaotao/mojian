# 工程速查与改动检查清单

面向二次开发和代码审查的一页式索引。协议与刷新的完整说明见 [架构与刷新](ARCHITECTURE.md)，验证边界见 [测试与兼容性](TESTING.md)。

## 1. 版本与位置

| 项 | 当前值 |
| --- | --- |
| 工程根 | `projects/agent-todo-display/`（独立 Git 仓库） |
| Mac | 0.4.14，SwiftUI，`macos/Sources/` |
| Android | 0.8.4（versionCode 25），原生 Java，`android/app/src/main/java/com/desktodo/app/` |
| 固件（默认） | `esp32-l`，`display-wait-2026-11-07` |
| 固件（参考对照） | `esp32-l-gx-reference-ab`，`reference-stride-2026-11-08` |
| 硬件 | ESP32-L / ESP32-WROOM-32D / DESPI-C02 / GDEY075Z08 800×480 黑白红 |
| 应用分区 | 单应用 2.5 MiB，USB 更新，无双槽 OTA |

## 2. 分层职责

| 层 | 职责 | 明确不做 |
| --- | --- | --- |
| Mac / Android | 清单、布局、卡片、天气行情、提醒、Agent 宿主与确认 | 不在设备上跑模型；不直接改设备清单 |
| Agent（Node） | 只读工具 + 操作提案，120 秒宿主超时 | 不写 ESP32、不执行任意 Shell/文件 |
| 固件 | Wi-Fi/BLE、本地 HTTP、显示事务、分区局刷、自主时钟/天气 | 不自动全刷、不格式化 LittleFS、不编造数据 |
| Python 服务 | 早期 SQLite 兼容路径、可选共享服务 | 不是主链路，不参与新客户端同步 |

## 3. 关键文件索引

| 文件 | 内容 |
| --- | --- |
| `firmware/src/main.cpp` | 启动、SPI/引脚、BLE 服务、主循环、legacy 轮询 |
| `firmware/src/local_portal.h` | 本地 HTTP、上传、提交校验、显示 worker、时钟绘制 |
| `firmware/src/EPD.cpp` | 全刷、差分波形、休眠、BUSY 守卫 |
| `firmware/src/reference_partial.cpp` | GxEPD2 参考局刷适配（完整源坐标裁剪） |
| `firmware/src/autonomy.h` | 自主调度、HTTPS/DNS 兜底、自主绘制 |
| `firmware/src/wifi_provision.h` | 加密 BLE 特征 0004 配网 |
| `firmware/src/paged_plane.h` | 12×4000 字节分页帧 |
| `macos/Sources/DeskStore.swift` | 串行 I/O、发送队列、三方合并、重连 |
| `macos/Sources/ScreenRenderer.swift` | 800×480 排版、168 阈值、红带避让 |
| `macos/Sources/Services.swift` | HTTP、天气/行情/高德、BLE 发现 |
| `macos/Sources/TaskReconcile.swift` | base/local/remote 三方合并 |
| `android/.../DeskRenderer.java` | 在设备底图上按布局重绘 |
| `android/.../ScreenSync.java` | 视觉回执与 `cardsVersion` 门禁 |
| `android/.../DeskApi.java` | 202 + transaction、423 重试 |

## 4. 设备发现与身份

- 设备 ID：`mojian-<eFuseMAC 后 48 位十六进制>`，例 `mojian-001122334455`。
- mDNS：`<device_id>.local:80`，服务 `_mojian._tcp`，TXT `id=<device_id>`、`api=1`。
- BLE：服务 `7f510001-8be5-4b2c-a47f-87c7e72e7050`；`…0002` 身份，`…0003` 只读地址，`…0004` 加密配网。
- 身份只是"别连错板"，**不是认证凭据**；局域网 HTTP 按设计无口令。

## 5. 设备 HTTP 契约

| 方法与路径 | 说明 | 失败码 |
| --- | --- | --- |
| `GET /` | 内置本地页面 | — |
| `GET /api/local/state` | 清单、`layout_id`、`local_mode`、`baseline_ready`、`needs_full`、`content_key`、`device_id` | 503 存储不可用 |
| `GET /api/local/health` | 只读诊断：内存、网络、显示计数、事务/故障状态、固件版本 | 始终可响应 |
| `GET /api/local/base` | 当前黑白影子帧 48000 字节 | 423 显示忙 |
| `GET /api/local/transaction?id=` | `pending` / `completed` / `failed` | 404 非当前事务 |
| `POST /api/local/commit?full=0\|1&async=0\|1` | multipart：`metadata` JSON + `frame` 48000 字节 | 400/409/423/503 |
| `POST /api/local/remote` | 切回 Mac 同步并请求一次全刷 | 423/503 |
| `GET /api/local/autonomy` | 自主更新状态与天气缓存 | — |
| `POST /api/local/autonomy` | `enabled/latitude/longitude/city_bitmap(320B base64)`，正文上限 2048 | 400/423/503 |

**回执语义**：`202` 只表示已接受并落盘，必须轮询同一 `transaction_id` 直到 `completed`；`failed` 表示内容已保存但屏幕未确认。

## 6. 字节与数据格式

```text
黑白帧   48000 B = 800×480/8，行优先，每行 100 B，MSB 在左
红色带   字节偏移 8000…10399（y=80…103），黑白平面必须全 0xFF
状态快照 /local.dat = 首行 metadata JSON + 48000 B 画面
模式标记 /local-mode
metadata ≤ 8192 B；待办 ≤ 8 条；标题 ≤ 600 字；截止 ≤ 40 字
accent_version = "mojian-red-v2"；accent_style 必须已知
content_key = 客户端状态 JSON 的 SHA-256 十六进制
分页缓冲 12 页 × 4000 B，单次分配 ≤ 4 KB
```

## 7. 刷新决策表

| 情形 | 行为 | 位置 |
| --- | --- | --- |
| 首次进入独立模式 / 重启后无基准 | 拒绝局刷，409，要求明确全刷 | `local_portal.h` |
| `layout_id` / `external_layout` 变化 | 409，要求全刷 | 同上 |
| 红色版本或样式变化 | 409，要求全刷 | 同上 |
| `*.red-v2` 提交缺 external/accent | 400 | `local_commit_policy.h` |
| `/local.dat` 损坏但 `/local-mode` 存在 | 503，不发布空清单 | `local_portal.h` |
| 红带写入黑像素 | 400 | 同上 |
| `expected_content_key` 不符 | 409，要求重读 | 同上 |
| 普通内容变化 | 按 `REFRESH_REGIONS` 逐区规划，无变化跳过 | `refresh_plan.h` |
| 窗口跨红带 | 拆分或阻止 | `withoutAccent` / 固件校验 |
| 明确应用布局 | 反相 → `EPD_Init` → `EPD_WhiteScreen_ALL` → 反相回 | `localPaint` |
| 任何"检查到变化" | **不得**自动全刷 | 全工程约定 |

## 8. 客户端同步状态机

**Mac**：`deviceIOBusy = isSending || isConnecting || isReadingDevice || healthBusy`，四类 I/O 只能串行；其余请求排入 `pendingSync/pendingFull/pendingConnect/pendingHealthCheck`，由 `drainDeviceOperations()` 消费。发送前依次核对显示空闲、目标地址与身份、基准与布局、三方合并，再比对 `frame`/`contentKey`/远端 `content_key` 决定是否真的上传。

**Android**：五秒检查与分钟时钟**仅前台**；`ScreenSync.commitAcknowledged` 需要任务、布局、`content_key`、`phone_settings`、`baseline_ready` 同时成立；`cardsVersion=0` 的旧基准禁止静默迁移。

**共同点**：先本地保存，再排队同步；发送中编辑合并为最新快照；布局/控制权不匹配时只提示，不静默接管。

## 9. 配置与凭据

| 位置 | 内容 | 是否提交 |
| --- | --- | --- |
| `firmware/include/wifi_secrets.h` | Wi-Fi | 否（`.gitignore`） |
| `firmware/include/device_config.h` | 兼容服务地址/口令 | 否 |
| `common/config/wifi_secrets.h` | 工作区共享 Wi-Fi | 否 |
| Mac 钥匙串 | `device` / `deepseek` / `amap` | 不进文件 |
| Android Keystore | DeepSeek Key | 加密存储 |
| `.env` | Python 兼容服务 `TODO_TOKEN` 等 | 否 |
| `data/`、`dist/`、`docs/*.png` | 私有现场、构建产物 | 否 |

任何日志、错误信息、提交与截图都不得出现真实 Key、口令、Wi-Fi 密码或设备 IP。

## 10. 构建、测试与烧录

```sh
# 固件（工作区根目录）
./pio run -d projects/agent-todo-display/firmware
./pio run -d projects/agent-todo-display/firmware -t upload --upload-port /dev/cu.YOUR_PORT

# 完整隔离测试（需先构建 dist/墨间.app）
cd projects/agent-todo-display && sh tools/test.sh

# 仅 Python 全量（需 Pillow）
../../.venv/bin/python -m unittest discover -s tests

# 参考驱动实验（编译不烧录）
../../pio run -d firmware -e esp32-l-gx-reference-ab

# Android
sh tools/build_android.sh
adb install -r dist/desk-todo-debug.apk
```

## 11. 测试覆盖矩阵

| 层 | 入口 | 证明了什么 | 不证明什么 |
| --- | --- | --- | --- |
| Mac 原生 | `--self-test` 等 7 组 | 作息、合并、队列、提醒、排版、持久化 | 真机网络与系统通知 |
| C++ 协议 | `tests/*_test.cpp`（17 个可执行） | 波形字节、窗口、分页、红带、故障注入 | 面板光学与信号完整性 |
| Python | `tools/test.sh` 内 6 个脚本；另 `unittest discover` 共 33 项 | 解析器、上传生命周期、自主调度、存储安全 | 长期内存与真实 TLS 负载 |
| Node | `tests/phone_layout_test.mjs` | 两端布局同源 | 原生控件渲染 |
| Android 仪器 | `DeskChecks` / `ScreenChecks` 等 | 真机只读直连、像素区域断言 | 用户实际观感 |
| 实物 | 用户照片与长时间观察 | 光学残影、红条纹 | 不能由任何回执替代 |

## 12. 改动检查清单

- [ ] 未改 LUT、VCOM、极性、扫描模式；如确需改，附面板型号与实物观察记录。
- [ ] 局刷窗口没有跨过 y=80…103；黑白平面该带保持全 0xFF。
- [ ] 普通内容变化没有触发自动全刷；全刷只由明确应用布局/模式/恢复基准发起。
- [ ] 提交走 `async=1`，成功只认同 `transaction_id` 的 `completed`。
- [ ] 新增大块内存前先考虑 `PagedPlane`，不申请连续 48 KB 常驻。
- [ ] 显示 worker 独占 SPI 与影子帧；上传、自主刷新、BLE 恢复期间不并发写帧。
- [ ] LittleFS 失败不自动格式化、不向客户端返回空清单。
- [ ] 设备直连保持无口令；兼容服务口令与设备凭据不混用。
- [ ] 新增字段在旧客户端缺省时有安全默认值；容量上限仍为 8 条待办 / 8192 B。
- [ ] 已跑 `sh tools/test.sh` 与固件编译；改动固件再跑对应 C++ 用例。
- [ ] 更新 `CHANGELOG.md`；涉及实物变更补 `VALIDATION.md`。
- [ ] 未提交真实 Key、口令、Wi-Fi、设备 IP、个人数据和私有截图。

## 13. 常见坑

1. `python3 -m unittest discover` 需要 Pillow；系统 Python 可能没有，改用根 `.venv/bin/python`。
2. `tools/test.sh` 依赖已存在的 `dist/墨间.app`，换机器先跑 `tools/build_macos.sh`。
3. `./pio` 必须带 `-d`；各工程 `platformio.ini` 的 `core_dir` 指向根 `.platformio/`。
4. BLE 地址特征必须 `setValue(ptr, length)`；传 `String.c_str()` 会走指针模板只发 4 字节。
5. 显示忙时 `/base` 与提交返回 423，不是故障；内存不足返回 503。
6. 设备重启后 `baseline_ready=false`，必须明确应用一次布局，不能靠轮询自动恢复。
7. 手机接管布局带 `.phone` 后缀；Mac 需显式"接管并同步（全刷）"。
8. 参考组全刷仍走原驱动；只切换黑白局刷路径，不要据此推断全刷波形。
9. 快照损坏时 state 返回 503，不要用空清单覆盖；无 `/local-mode` 开机默认走旧 Python 轮询。
