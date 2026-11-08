# HTTP 解析保护

`prepare_webserver.py` 在 PlatformIO 的 pre-build 阶段，从固定的 ArduinoESP32
2.0.17 框架复制 WebServer 到本工程忽略的 `.pio/webserver-libs/WebServer/`，
再施加受控修改。`lib_extra_dirs` 让此库优先于框架自带库；不会修改工作区共享的
`.platformio/packages/`。

上游同步 multipart 解析器在上传半包时可能无限等待；应用在 `handleClient()`
返回后检查上传超时无法打断该等待。保护进入实际解析循环，不在另一任务强制释放
仍被解析器使用的缓冲。

- 每请求从解析开始计时：总时限 30 秒、连续无字节时限 5 秒，均使用无符号差值。
- 请求行/头单行 1 KB，头部累计 8 KB。
- 请求体 60 KB，普通 JSON/单个表单字段 8 KB；所有普通字段值累计 8 KB、
  字段名累计 1 KB，在加入参数数组前检查，避免复制参数数组时放大堆占用。
  multipart boundary 最长 128 字节。
- 每次逐字节、逐行及普通请求体读取执行限额与断开检查。
- 失败关闭该 TCP 客户端；已进入文件上传则发送 `UPLOAD_FILE_ABORTED`，沿用
  `localRelease()` 回收帧与恢复蓝牙，随后主循环能继续服务其他请求。
- 健康检查、状态、48,000 字节画面和现有 multipart/JSON API 保持兼容。

脚本校验上游 `Parsing.cpp`、`WebServer.h` 的 SHA-256，框架变化将停止构建，
必须重新审查转换。生成库保留原始 LGPL 版权声明。
[上游源码](https://github.com/espressif/arduino-esp32/tree/2.0.17/libraries/WebServer)。

隔离验证（在工程目录，不访问真实设备）：

```sh
python3 -m unittest tests/test_http_parser.py -v
../../pio run -d firmware
```

测试直接编译生成后的请求和 multipart 解析函数，覆盖正常 48 KB 上传、半包、
断开、字段/请求体超限、慢速持续输入、零长度 POST、健康 GET、计时溢出与下次请求恢复。
测试需要已安装本工程固定框架；可通过 `MOJIAN_ARDUINO_FRAMEWORK` 指定其目录。
