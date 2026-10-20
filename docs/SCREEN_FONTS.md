# 屏幕字体

Mac0.4.8 / Android0.7.8及配套固件。

屏幕位图中文使用思源黑体SC Medium；数字与拉丁文本使用Inter Medium，Mac较粗数字使用Semibold；“下班之后”“把时间，还给生活。”“今天的留白，也很珍贵。”使用霞鹜文楷GB屏幕阅读版。原生客户端控件不更换字体，继续遵循系统缩放。

两端继续生成800×480黑白帧，亮度160阈值；不改变红色保留带、布局控制权或局刷协议。字形与宽度发生变化，较长文字仍按原有规则换行/截断。字体变更不会自动切换布局或全刷。自主更新固件需要同步升级，否则时钟/天气可能被旧点阵重新覆盖；固件重启仍需明确建立显示基准。

## 构建

Python3从`resources/fonts/manifest.json`下载SHA256锁定的三款字体，缓存于忽略目录`tools/downloads/screen-fonts/`。Mac构建脚本复制到app的Resources/Fonts，Android preBuild任务复制到忽略的assets/fonts；版权、许可和清单同步打包。直接Gradle构建同样需要Python3，首次构建需联网。完整字体不提交Git，不依赖用户安装字体。

正常入口：`sh tools/build_macos.sh`、`sh tools/build_android.sh`。可单独运行`python3 tools/prepare_screen_fonts.py --destination <输出目录>`准备缓存。校验失败会终止，不静默回退到未知下载版本。

## 固件小字库

天气中文为16×20字形；Inter数字预先生成四种字号，不使用5×7数字放大。常量存于固件，不增加整屏缓存；数字仍沿用原区域和字符步进。用Pillow运行`tools/generate_autonomy_assets.py --font <SourceHanSansSC-Medium.otf> --digits-font <Inter-Variable.ttf>`再生成。完整上游许可在resources/fonts与firmware/resources中。

三款字体均使用SIL OFL1.1，允许软件商业嵌入/捆绑，须保留版权及许可；字体本身不能单独售卖，修改/子集化遵循保留名称条款。详见[第三方清单](../THIRD_PARTY_NOTICES.md)。

预览和缓存回读不能替代实屏光学判断，残影和字形渲染是两类问题。
