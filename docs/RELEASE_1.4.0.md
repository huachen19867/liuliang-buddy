# 1.4.0+7 后台刷新测试版

桌面卡片自动刷新可设置为关闭、每小时、每两小时或每天。Android WorkManager 仅在有网络时尽力调度；系统省电、厂商限制和官网响应可能延后任务。移动、联通、广电通过无界面 WebView 尝试查询已成功连接的官方网页，电信仍需打开 APP，因为当前读取依赖已渲染账务页面。失败时沿用上次余额和原查询时间，并显示失败或待验证状态。

后台任务沿用官网响应来源门禁、现有 Dart 解析器和本地会话存储。不会打开登录流程替用户输入资料，不读取短信，不向开发者服务器发送账号数据。详细支持边界见 [后台刷新说明](WIDGET_BACKGROUND_REFRESH.md)。

Android ARM64 调试 APK：`artifacts/liuliang-buddy-debug.apk`，114,399,238 字节（约 109.1 MiB）。
SHA-256：`53a782a6a4c5730f29a53fb8d6df3a6f4da6d2bc1337632498ca4872812b2b4b`。

APK 元数据显示版本 1.4.0/code 7、最低 API 24、目标 API 36；Android Debug 签名 v2 验证通过。`flutter analyze` 无问题，Android `assembleDebug` 构建成功。此版本未运行测试套件，也没有连接真机；WorkManager 实际触发、后台 Cookie 共享、真实号码余额与各厂商 Launcher 更新仍待手机验证。
