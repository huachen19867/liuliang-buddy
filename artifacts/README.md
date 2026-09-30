# 输出索引

ui-preview.png 为应用 UI 实际组件渲染的预览，使用演示数据，不能证明真实手机号流量查询准确性。顶部显示“界面演示 · 非真实流量”。

liuliang-buddy-debug.apk 为 1.1.0+2 安卓个人测试包，89,496,179 字节（约 85.4 MiB），Android 7.0/API 24 及以上，目标 ARM64 手机。它使用调试签名，未使用 DEMO 编译参数。安装后两个号码需分别在官方网页完成验证。下载见 [GitHub Release](https://github.com/huachen19867/liuliang-app/releases/tag/v1.1.0)，私有仓库需要有权账号登录。

android-build.log 保存成功的本地安卓构建输出；apk-signature.txt 为 apksigner 签名检查（v2 通过，Android Debug），apk-metadata.txt 为 aapt2 元数据检查（名称、版本、SDK 与权限）。应用申请网络与通知权限，没有短信读取权限。本目录不含真实号码、验证码、登录凭证或成功账号的原始响应。

APK SHA-256：72a57ebaa68dec4811e212416665cf7c810fb2a37dbe56976759708bb10bd520。

此版本加入标准 Android 双卡桌面小组件。卡片显示上次查询时间与状态，点击打开 APP 更新。Manifest 已核对非导出 provider 与小组件元数据；原生 5 项展示测试全部通过，完整 Flutter 24 项测试、静态分析及 Node 探针检查通过。未连接真机，Launcher 添加、缩放、冷暖启动以及真实号码查询仍需确认。卡片不会在亮屏时自动向运营商联网。

可交互 Web 演示位于 app/build/web/，以 DEMO=true 构建，需通过本地 HTTP 服务访问。源码与运行说明见根 README.md。
