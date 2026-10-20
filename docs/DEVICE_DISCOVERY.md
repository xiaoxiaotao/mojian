# 设备发现与断线恢复

适用Mac0.4.7 / Android0.7.7与提供device_id的新固件。

## 使用方式

先用蓝牙发现或手动地址连接一次。客户端从HTTP状态读取并保存固定的屏幕ID。之后旧IP不可访问或指向其他屏幕时，Mac使用固定`.local`名称，安卓通过系统NSD查询`_mojian._tcp.`服务，再核对HTTP返回的ID后才采用地址。

它针对IP变化，不会替设备连接一个尚未配置的Wi-Fi。两端和屏幕仍需处于可相互访问的局域网。路由器屏蔽组播、访客隔离或系统限制发现时，可使用蓝牙重新读取地址、手动填写地址。安卓自动发现仅前台运行，不自动申请蓝牙权限。

连接失败按5、10、20、40、60秒上限退避；单次安卓NSD查询最多8秒，离开前台取消。Mac状态请求最长6秒，安卓连接4秒/读取6秒。网络可用不等于内容已更新，设备重启后仍需明确应用布局建立显示基准。

更换屏幕：设备设置中点「更换屏幕 / 解除绑定」并确认，再发现新设备。该操作保留本机清单；不会给新屏幕自动写入旧清单或自动全刷。首次连接旧固件仍可手动使用，但无法建立身份绑定；已绑定后遇到缺失ID的响应会拒绝，降级或换板需要明确解除绑定。

## 数据与协议

- 板卡ID：`mojian-`加12位小写十六进制芯片标识，重启/IP变化不改变。
- 主机名与服务实例名均取该ID，服务`_mojian._tcp`端口80，TXT仅含id和API版本。
- GET `/api/local/state`新增`device_id`、`discovery_host`。ID用于防止意外连错设备，不是密码或加密身份认证；仅适用于可信局域网。
- Mac保存于可选Preferences.deviceID，兼容已有状态文件；安卓单独保存deviceID，不加入模板或模型配置。
- DNS发现提供候选地址，HTTP状态必须再次核对。绑定状态下缺失或不一致ID均拒绝，不导入或提交该设备事项。
- Mac发现本身不导入清单，后续同步继续三方合并。安卓继续原有读取/冲突确认；两端都不自动接管另一端布局、不自动全刷。

## 验证

隔离测试覆盖ID格式、错误/缺失ID拒绝、失效地址转固定名称、本地草稿与手机布局保留、绑定持久化及明确解除。

Android debug额外提供`DeviceDiscoveryChecks`，需显式传入deviceID：只进行NSD与HTTP GET，可测试失效地址恢复，不提交清单或画面。普通隔离测试不依赖实机。

参考：[Android NSD](https://developer.android.com/develop/connectivity/wifi/use-nsd)、[ESP32 mDNS](https://docs.espressif.com/projects/esp-idf/en/v4.2/esp32/api-reference/protocols/mdns.html)、[Home Assistant发现](https://contributors.home-assistant.io/core/integrations/discovery/)。
