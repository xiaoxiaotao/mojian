# 墨间 Android 图标

原创图形，随项目采用 GPL-3.0-only。墨绿底、米白桌面墨水屏、朱红小印章，无字体或外部图片依赖。

- `mojian-android.svg`：可编辑的矢量预览。
- `mojian-android-preview.png`：Android 实际加载应用图标后的离线资源渲染，并非桌面截图。
- APK 使用 `android/app/src/main/res/drawable/ic_launcher_*` 与 `mipmap-anydpi-v26/v33` 下的原生矢量和自适应图标。
- `IconPreview` 为 debug 离线资源预览入口，不启动业务界面、不访问设备或改用户清单。

后续更改主图形时，应同步 SVG 与原生矢量，并重新导出预览。
