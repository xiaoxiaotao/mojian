# 锁定的 GxEPD2 参考源码子集

来源：[ZinggJM/GxEPD2](https://github.com/ZinggJM/GxEPD2)，Jean-Marc Zingg。
标签 `1.6.9`，提交 `de82887e77a78528ea386e68bba2cb0291d2c319`。
`manifest.json` 记录原始下载文件的 SHA-256，保留 GPLv3 `LICENSE`。

本目录保留基类、面板枚举及 GDEY075Z08 面板类的原始字节，未复制整个绘图库。仅用于显式选择的参考实验环境，不替换默认驱动。

构建前 `firmware/tools/prepare_gx_reference.py` 核验原始文件，再在忽略目录 `.pio/reference-libs/` 生成实验库。面板 `.cpp/.h` 不修改；基类增加故障锁存后的写入保护、接入有界 BUSY 等待和只读诊断。正常初始化/局刷/休眠的 SPI 字节记录，与未适配的原始基类逐字节比较通过。

因此，该实验应称为“原始面板驱动加安全适配”，不能宣称整个库完全未修改。修改及源文件的许可和归属随对应源码保留。

分页输入适配在项目 `reference_partial.cpp`：沿用原始 `writeImagePartToCurrent/Previous`，逐个40行内存页写入，整个窗口只执行一次 `refresh_bw`，不新增连续48KB缓存。实验范围和限制见 [参考驱动对照](../../docs/REFERENCE_DISPLAY_TEST.md)。
