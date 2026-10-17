# 第三方来源与许可状态

本项目由多个来源组成，不提供覆盖全部文件的统一MIT声明。公开可读源码不等同于对所有部分授予相同许可；正式复制或商业分发前应按来源核对。

| 部分 | 来源与状态 |
| --- | --- |
| 同型号校正LUT/差分实现参考 | [GxEPD2](https://github.com/ZinggJM/GxEPD2)，Jean-Marc Zingg；`firmware/src/partial_lut.h`已注明派生与GPL-3.0，参考源文件与完整许可证保留于`references/gxepd2/` |
| 基础EPD驱动 | 从原工作区既有display-test工程及ESP32epdx示例继承；本地上游LICENSE文件为空，尚不足以确定完整许可。未把这部分重新声明为MIT；需进一步核验厂商来源和分发授权 |
| Agent | [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)，SDK版本与依赖锁见`agent-engine/`；本地参考提交1517a4dbca0a2789ff1d41ba439600f8547d23fa。完整上游克隆及其Git元数据保留本地，未嵌入本仓库 |
| Node | 官方下载URL与SHA-256在`agent-engine/NODE-SOURCE.txt`。准备脚本下载，运行时不提交Git；构建应用时保留Node LICENSE |
| npm依赖 | 由package-lock锁定；node_modules不提交，应用构建保留随依赖附带的许可文件。正式发布仍需汇总完整依赖清单 |
| 固件库 | PlatformIO固定ArduinoJson与NimBLE-Arduino版本；由包管理器安装，未把缓存视为本项目自有源码 |
| 字体与图标 | Mac当前使用系统字体与SF Symbols；旧服务支持本机中文字体，不分发系统字体文件。项目图片/图标资产的正式商业分发来源仍需核对 |
| 数据 | Open-Meteo、行情接口、高德分别遵循各自服务条件；开发可用不代表量产可免费调用。天气数据署名与商用托管服务条件分开处理 |

## 发布边界

仓库不包含真实Key、Wi-Fi密码、个人任务数据库、Agent个人会话、原始现场截图或官方依赖二进制。需要正式销售/分发时，先完成未决来源核验，不把“已上传GitHub”当作商业许可已经确认。
