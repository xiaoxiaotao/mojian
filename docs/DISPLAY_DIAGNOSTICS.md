# 显示更新诊断

`display-wait-2026-11-07` 开发固件在只读 `/api/local/health` 中提供实际驱动次数及等待时间，用于核对显示调度、关断等待和长时间连接状态。读取这些字段不会发起刷新。

| 字段 | 含义 |
| --- | --- |
| `display_refresh_commands` | 本次启动实际发出的 DISPLAY_REFRESH 命令累计数，包括全刷和局刷 |
| `display_refresh_completed` | 上述命令等待 BUSY 就绪且未锁存显示故障的累计数 |
| `display_differential_windows` | 已进入差分刷新调用的窗口数；一次客户端同步可能包含多个窗口 |
| `display_last_refresh_wait_ms` | 最近一次刷新命令到 BUSY 等待结束的时间，包含超时情形 |
| `display_normal_poweroff_waits` | 正常流程尝试 POWER_OFF 并等待的累计数，故障补救路径不计入 |
| `display_last_poweroff_wait_ms` | 最近一次正常 POWER_OFF 的等待耗时，含信号断言裕量 |
| `display_last_poweroff_busy_ready` | 最近一次正常关断等待是否观察到 BUSY 就绪；没有正常关断记录时为 false |
| `display_last_poweroff_busy_seen` | 最近一次正常关断等待的轮询是否见过 BUSY 为忙；未见到不代表没有短脉冲 |

这些字段按独立原子变量读取，繁忙期间不是同一事务的原子快照。它们不能代替 `/api/local/transaction` 的回执，也不能证明面板电压已实际关闭、颜色准确或没有残影。没有报告超时不能排除电气和光学问题。

设备重启后计数从零开始；旧固件缺失的字段表示不支持，不能按零处理。五秒健康检查次数不属于刷新次数。

## 有限时长的只读观察

先在客户端设备页核对已绑定设备的地址和 `device_id`，再运行：

```sh
python3 tools/observe_display.py \
  --url http://DEVICE_ADDRESS \
  --device-id DEVICE_ID \
  --seconds 120 --interval 10 \
  --output data/display-observation.json
```

工具仅 GET 健康状态及空闲时的黑白基帧；只保存帧哈希，不保存画面位图。遇到显示忙碌时跳过帧读取，设备身份不符则停止。输出保留设备诊断信息，建议放在已忽略的 `data/` 下。

汇总中的 `different_frame_hashes` 表示软件帧出现过几种内容，不能视为肉眼画面验证。检测到重启或计数倒退时不计算刷新差值；旧固件不支持的计数不会伪报为零。工具始终将光学结果标为 `not_observed`。

此工具不会暂停绘图、修改清单、恢复配置、重建基准或全刷。静置对照需要显式暂停所有控制端及设备自主绘图，并在观察后恢复原设置；程序采样应配合同光照、同角度的实物比较。
