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
| 字体与图标 | 原生应用控件使用系统字体与SF Symbols；屏幕位图采用下述OFL字体，旧服务仍支持本机中文字体，不分发系统字体文件。项目图片/图标资产的正式商业分发来源仍需核对 |
| 数据 | Open-Meteo、行情接口、高德分别遵循各自服务条件；开发可用不代表量产可免费调用。天气数据署名与商用托管服务条件分开处理 |

## 设计调研

TRMNL、InkyPi、paperlesspaper、Inkycal等用于研究模块划分和信息呈现；具体链接见调研文档。没有将其整套服务器或固件移植进当前工程。未来复用代码时记录具体版本、路径、修改和适用许可证。

## 发布边界

仓库不包含真实Key、Wi-Fi密码、个人任务数据库、Agent个人会话、原始现场截图或官方依赖二进制。需要正式销售/分发时，先完成未决来源核验，不把“已上传GitHub”当作商业许可已经确认。

## 自主天气新增资源

- `firmware/src/autonomy_font.h`：由Noto Sans SC少量字形生成的单色像素子集；上游[notofonts/noto-cjk](https://github.com/notofonts/noto-cjk)，SIL Open Font License 1.1全文在`firmware/resources/NotoSansCJK-OFL.txt`。原字体由工具下载到忽略目录，不捆绑系统字体。再生成入口`tools/generate_autonomy_assets.py --font <本地Noto字体路径>`。
- `firmware/resources/isrg-root-x1.pem`及`isrg-root-x2.pem`：来自[Let's Encrypt官方证书页](https://letsencrypt.org/certificates/)的公开ISRG信任锚；用于验证Open-Meteo HTTPS。不是个人证书或私钥。不关闭证书验证，不在源码保存天气服务私密凭据。

## 屏幕字体（Mac0.4.8 / Android0.7.8）

- 思源黑体SC Medium：[Adobe Source Han Sans](https://github.com/adobe-fonts/source-han-sans)，中文正文；完整版权/OFL1.1见`resources/fonts/SourceHanSans-OFL.txt`。
- Inter：[Google Fonts分发](https://github.com/google/fonts/tree/main/ofl/inter)，数字与拉丁字符；见`resources/fonts/Inter-OFL.txt`。
- 霞鹜文楷GB屏幕阅读版v1.530：[LXGW WenKai Screen](https://github.com/lxgw/LxgwWenKai-Screen)，日历标题和少量短句；见`resources/fonts/WenKai-OFL.txt`。
- `resources/fonts/manifest.json`锁定原始字体下载URL和SHA256，构建时下载并以原文件捆绑，许可证同时打包。字体独立维持OFL1.1，不以项目GPL声明替换其许可，不单独售卖字体。未对子集字体沿用保留名称。
- ESP自主数字和少量天气字形由Inter和思源黑体生成小型位图；生成入口`tools/generate_autonomy_assets.py --font <思源黑体> --digits-font <Inter>`；对应许可另保存在`firmware/resources/`。未把完整字体写入ESP32。
