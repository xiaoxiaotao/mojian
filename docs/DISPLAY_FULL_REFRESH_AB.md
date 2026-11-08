# 全刷寄存器对照实验

更新：2026-11-08。目的：隔离"原组与参考组共用同一条全刷路径"这一未验证因素。

## 为什么看全刷

原组与参考组的 **黑白局刷** 路径不同，但两者恢复基准时都调用原驱动的：

```text
EPD_Init -> EPD_WhiteScreen_ALL -> EPD_Update -> EPD_DeepSleep
```

如果这条共用全刷路径的寄存器块与同型号上游实现不一致，两组都可能从同一个不干净的起点开始。仅比较局刷无法排除这一点。

## 对照结果

| 项 | 本工程全刷（厂商路径） | GxEPD2 1.6.9 同型号全刷 |
| --- | --- | --- |
| `0x50` VCOM/数据间隔 | `0x11 0x07` | `0x13 0x07` |
| `0xE0` CCSET | 未写 | `0x00`（不使用 TSFIX，内部温度传感器） |
| `0x41` TSE | 未写 | `0x00`（启用内部温度传感器） |
| `0x04` POWER_ON 位置 | 在 `0x00/0x61/0x50/0x60` 之前 | 在 `0x00/0x50/0xE0/0x41` 之后 |
| 刷新前设置 | 仅初始化时写一次 | `_Update_Full` 在 `0x12` 前重写 |
| `0x12` 后 | `EPD_Update` 等待，随后 `0x50=F7`、`0x02`、`0x07 0xA5` | `_PowerOff`（`0x02`），随后 `0x07 0xA5` |

### `0x50` 不能单独改

UC8179 数据手册（CDI, R50h）把第一个数据字节定义为：

```text
BDZ  -  BDV[1:0]  N2OCP  -  DDX[1:0]
```

KWR 模式下 `DDX[1]` 是**红色数据极性**，`DDX[0]` 是 K/W 数据极性。`0x11` 的 `DDX=01`，`0x13` 的 `DDX=11`：红色极性翻转，K/W 不变。本工程的静态红色掩码约定"wire bit 1 是红色"；因此把 `0x50` 改成 `0x13` 必须同时把红色掩膜取反，否则品牌红会反色。这不是一个可以单独验证"残影"的干净因素。

本次实验因此**只测试厂商路径缺失的温度块** `0xE0=0x00`、`0x41=0x00`，保持 `0x50=0x11` 与红色掩膜不变。

## 实验配置

```sh
../../pio run -d firmware -e esp32-l-gx-full-temp-ab
```

`esp32-l-gx-full-temp-ab` 只定义一个开关 `MOJIAN_EXPERIMENT_GX_FULL_TEMP=1`，在 `EPD_WhiteScreen_ALL()` 写完 `0x10/0x13` 后、`EPD_Update()` 前追加：

```text
0xE0 0x00
0x41 0x00
```

刷入后 health 应显示：

```json
{"firmware_revision":"gx-full-temp-2026-11-08","display_experiment":"gxepd2-full-temperature"}
```

保持不变的项：

- 默认 `esp32-l` 全刷路径、`0x50=0x11`、静态红色掩膜、局刷波形、`0x50=F7` 休眠、红带、SPI 频率、超时与故障锁存。
- 不自动全刷，不写测试待办，不修改清单。
- 参考局刷配置 `esp32-l-gx-reference-ab` 仍是独立实验；本实验只加温度块，不能同时叠加多个因素。

## 验证边界

- 主机测试：`tests/gx_full_settings_test.cpp` 逐字节断言两条命令、两个数据字节；`display_init` 的 `gx_full_temp` 变体用真实 `EPD_WhiteScreen_ALL` 检查命令顺序与 `0x12` 位置。
- 构建：`esp32-l-gx-full-temp-ab` 编译通过；默认环境不受影响。
- 实机：2026-11-08 已授权烧录一次并恢复当前布局。全刷事务 `7d82df54-00000001` completed，布局/清单/红带保留；全刷等待 29.7 秒，无故障/超时；随后 120 秒只读观察 11 个样本、0 读错误/重启；一次上电复位后重新全刷（29.65 秒，`e69a78b6-00000001` completed），180 秒观察 18 个样本、0 读错误/重启。仍需在 **同一布局、光照、温度、更新节奏** 下观察干净起点和后续局刷残影；单次等待时间不能归因于温度块。
- 如果温度块改变光学结果，说明温度补偿路径值得继续；如果无变化，再考虑单独的 `0x50` 极性实验（已实现，见下节，未烧录）。
- 协议通过、回执 completed 和影子帧正确都不能替代光学确认。

## 0x50 极性实验（已实现，已烧录一次）

环境：`esp32-l-gx-full-cdi-ab`，开关 `MOJIAN_EXPERIMENT_GX_FULL_CDI=1`。

只对 `staticAccent` 全刷帧生效：

- 在 `0x10/0x13` 数据写完、`EPD_Update()` 前写 `0x50=0x13 0x07`；
- 仅把静态红色掩膜的 8000…10399 字节取反，带外显式写 `0xFF`（白）；
- 旧 Python `pages` 红色路径不改变，保持厂商 `0x50=0x11`；
- 与温度块互斥，两个宏同时定义会在编译期报错。

刷入后 health 应显示 `firmware_revision=gx-full-cdi-2026-11-08`、`display_experiment=gxepd2-full-cdi`。
`gx_full_settings` 与 `display_init` 的 `gx_full_cdi` 变体覆盖寄存器顺序、红带内外取反；配置编译通过。2026-11-08 已按用户授权烧录一次：全刷事务 `6789cd09-00000001` completed，等待 29.65 秒。首轮实屏为**整屏红底、横带白底红字**：带内取反正确，但带外静态掩膜的 0 在 `DDX=11` 下是红色。已回退温度块并重新全刷（`a577c6d4-00000001` completed）。修正为带外写 `0xFF`，测试与编译通过。修正版已于 2026-11-08 重新烧录：全刷 `fc9c407a-00000001` completed，等待 29.65 秒；180 秒观察 18 个样本、0 读错误/重启，随后 300 秒观察 29 个样本、0 读错误/重启。回归覆盖整帧 48000 字节与旧非 staticAccent 路径。用户随后反馈修正版 CDI **整屏残影**，该配置不采用；已回退温度块并重新全刷（`3c5c138c-00000001` completed），整屏残影是否清除待用户确认；回退后用户确认暂无残影；600 秒观察 55 个样本、0 读错误/重启、11 个差分窗口完成，继续观察。

## 0x50 实验的前置条件

如果要做 `0x50=0x13` 对照，必须同时：

1. 仅在全刷路径把静态红色掩膜的 8000…10399 字节取反，带外写 `0xFF`；
2. 保持 K/W 数据与当前一致（`DDX[0]` 未变）；
3. 在相同布局下确认红色仍为正红而不是反白，再做残影比较；
4. 不把该实验与温度块或参考局刷叠加。

## 来源

- 本工程：`firmware/src/EPD.cpp` 的 `EPD_Init()`、`EPD_WhiteScreen_ALL()`、`EPD_Update()`、`EPD_DeepSleep()`。
- 上游：GxEPD2 1.6.9，提交 `de82887e77a78528ea386e68bba2cb0291d2c319`，`src/gdey3c/GxEPD2_750c_GDEY075Z08.cpp` 的 `_InitDisplay()`、`_Update_Full()`、`_PowerOn()`、`_PowerOff()`、`hibernate()`。
- 厂商原始示例：`common/vendor/official-download/A32-GDEY075Z08-FP-20231017/GDEY075Z08_Arduino/Display_EPD_W21.cpp`。
- [UC8179 数据手册](https://atta.szlcsc.com/upload/public/pdf/source/20241016/F7B4A5482459404971A26A11A3471994.pdf)：CDI (R50h)、CCSET (E0h)、TSE (41h)、TSSET (E5h)。
