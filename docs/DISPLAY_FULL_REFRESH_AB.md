# 全刷寄存器对照实验

更新：2026-11-08。目的：隔离"原组与参考组共用同一条全刷路径"这一未验证因素。

## 为什么看全刷

原组与参考组的 **黑白局刷** 路径不同，但两者恢复基准时都调用原驱动的：

```text
EPD_Init -> EPD_WhiteScreen_ALL -> EPD_Update -> EPD_DeepSleep
```

如果这条共用全刷路径的寄存器块与同型号上游实现不一致，两组都可能从同一个不干净的起点开始，随后各自局刷累积不同的残影。仅比较局刷无法排除这一点。

## 对照结果

| 项 | 本工程全刷（厂商路径） | GxEPD2 1.6.9 同型号全刷 |
| --- | --- | --- |
| `0x50` VCOM/数据间隔 | `0x11 0x07`（`EPD_Init`） | `0x13 0x07`（`_InitDisplay` 与 `_Update_Full`） |
| `0xE0` CCSET | 未写 | `0x00`（不使用 TSFIX，内部温度传感器） |
| `0x41` TSE | 未写 | `0x00`（启用内部温度传感器） |
| `0x04` POWER_ON 位置 | 在 `0x00/0x61/0x50/0x60` 之前 | 在 `0x00/0x50/0xE0/0x41` 之后 |
| 刷新前设置 | 仅初始化时写一次 | `_Update_Full` 在 `0x12` 前重写 `0x00/0x50/0xE0/0x41` |
| `0x12` 后 | `EPD_Update` 等待，随后 `0x50=F7`、`0x02`、`0x07 0xA5` | `_PowerOff`（`0x02`），随后 `0x07 0xA5` |

`0x50=0x13` 在 GxEPD2 源码中的注释是 "0xFF white for black, 0xFF white for red"；本工程沿用厂商示例的 `0x11`。两者都来自同型号资料，不能仅凭源码判定谁正确，必须做光学对照。

## 实验配置

```sh
../../pio run -d firmware -e esp32-l-gx-full-ab
```

`esp32-l-gx-full-ab` 只定义一个开关 `MOJIAN_EXPERIMENT_GX_FULL=1`，在 `EPD_WhiteScreen_ALL()` 写完 `0x10/0x13` 后、`EPD_Update()` 前追加：

```text
0x00 0x0F
0x50 0x13 0x07
0xE0 0x00
0x41 0x00
```

保持不变的项：

- 默认 `esp32-l` 全刷路径、局刷波形、`0x50=F7` 休眠、红带、SPI 频率、超时与故障锁存。
- 不自动全刷，不写测试待办，不修改清单。
- 参考局刷配置 `esp32-l-gx-reference-ab` 仍是独立实验；本实验只改全刷寄存器块，可与原组或参考组分开评估，不能同时叠加多个因素。

## 验证边界

- 主机测试：`tests/gx_full_settings_test.cpp` 逐字节断言上述 4 条命令、5 个数据字节；`tools/test.sh` 已包含。
- 构建：`esp32-l-gx-full-ab` 编译通过；默认环境不受影响。
- 实机：需要明确授权烧录，并在 **同一布局、光照、温度、更新节奏** 下观察全刷后的干净起点和后续局刷残影；记录累计局刷窗口数与出现时间。
- 如果该块改变光学结果，下一步应拆成 `0x50` 与 `0xE0/0x41` 两个单因素，而不是直接改生产波形。
- 协议通过、回执 completed 和影子帧正确都不能替代光学确认。

## 来源

- 本工程：`firmware/src/EPD.cpp` 的 `EPD_Init()`、`EPD_WhiteScreen_ALL()`、`EPD_Update()`、`EPD_DeepSleep()`。
- 上游：GxEPD2 1.6.9，提交 `de82887e77a78528ea386e68bba2cb0291d2c319`，`src/gdey3c/GxEPD2_750c_GDEY075Z08.cpp` 的 `_InitDisplay()`、`_Update_Full()`、`_PowerOn()`、`_PowerOff()`、`hibernate()`。
- 厂商原始示例：`common/vendor/official-download/A32-GDEY075Z08-FP-20231017/GDEY075Z08_Arduino/Display_EPD_W21.cpp`。
