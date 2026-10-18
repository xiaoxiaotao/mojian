# 测试与兼容性

当前 Mac 0.4.0 / Android 0.7.0，开发验证阶段。验证硬件为 ESP32-WROOM-32D、DESPI-C02、GDEY075Z08 800×480 黑白红屏；Mac为Apple Silicon/macOS SDK 15.2，Android实机为Mi 10 Pro。

## 自动化验证

- `sh tools/test.sh`：Mac业务、可靠性、卡片、任务、重复规则与扩展隔离测试；C++差分传输、局刷窗口、红色保留带、配网分片、DNS解析及网页布局检查。
- `python3 -m unittest discover -s tests -v`：22项，包含兼容服务、共享HTTP服务、持久分区地址保护，需安装requirements.txt。
- Android调试APK的DeskChecks、ScreenChecks、AssistantChecks、ExtensionChecks、RepeatChecks、UiChecks通过。最新重复规则18项、布局780项；UI检查覆盖360dp及1.3倍字体。命令见Android README。
- 最新两端构建、固件编译/USB烧录、Mac开发签名和APK签名校验通过。

隔离测试不写真实用户事项或屏幕；模拟通知不代表系统已实际展示。

## 设备验证

关闭Mac及Android客户端后，ESP32自行获取天气返回HTTP200，TLS验证正常，时钟跨分钟变化。读取画面缓存检查差异仅发生于时钟/天气区域，任务、其他模块与固定红色区域保持；这不等同于实屏光学确认。设备重启后仍需明确应用一次布局建立基准。

固件使用2.5MiB单应用分区，原NVS/LittleFS/coredump地址和容量保持，无双槽OTA。首次配网协议已实现，但加密BLE系统配对、真实Wi-Fi写入及错误密码回退尚未完成端到端实机验收。

## 仍需验证

- 更多手机/系统、BLE系统配对与Wi-Fi配网。
- 日历授权后的真实事件、跨时区与长期同步。
- 系统通知、厂商省电、专注模式与休眠唤醒。
- 面板温度/批次、长期局刷残影、断网和断电恢复。
- 正式签名公证、跨设备迁移、公共部署和商业分发条件。

修改波形须保留协议测试并提供面板型号与真实观察结果。设备回执不能代替光学验收。
