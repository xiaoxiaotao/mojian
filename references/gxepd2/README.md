# GxEPD2 同型号差分刷新参考

来源：https://github.com/ZinggJM/GxEPD2 。保留本次下载的原始源文件和 LICENSE。下载于 2026-10-16，使用 master 路径，未将其作为固定提交版本发布。

- `GxEPD2_750c_GDEY075Z08.cpp/.h`：同型号驱动，作者 Jean-Marc Zingg。
- `FastBlackWhiteOnColor.ino`：黑白窗口更新示例。
- `LICENSE`：GPLv3。

`firmware/src/partial_lut.h` 派生自上述驱动的同型号校正波形；`EPD_Init_Differential` 的寄存器选择也参考该实现。使用 GPL-3.0，保留归属及原始许可文件。固件对外分发时应随附适用许可和对应源码；不能将新增派生部分按无许可的自有代码分发。安卓/服务代码未复制此库。

维护者明确提示：该型号 OTP 黑白波形有问题；校正后的快速黑白更新仍可能产生黑白边缘失真。使用本参考不代表实物显示质量已验证。
