# 1.5.0 双账号与刷新修复测试版

本版处理公开反馈中的重复运营商账号、不限量一直刷新、桌面添加没有弹窗以及后台更新难以确认的问题。首次选择时，同一家运营商连续点两下可加入第二张卡，每家最多两张、合计最多四张。两个号码分别登录，第二号码依赖 Android System WebView 的独立 Profile 支持；设备不支持时会明确阻止添加，不借用第一号码的登录与余额。旧单卡账号和缓存键保留，设置可收起第二张。

四家官网明确标记“不限量”时结束加载并保存查询时间，首页和桌面显示不限量；巨大数字、负数或缺字段不会猜成不限量。前台每个账号只保留一轮查询，超时、迟到响应、登录返回重复加载和清理失败都有门禁。清理未完成时暂停查询，避免继续使用残留会话。

后台可关闭，或选择每小时、每两小时、每天尝试刷新，并显示最近实际开始、完成时间与结果。调整周期、进入前台或关闭任务会使旧任务失效，防止继续提交结果。Android 的省电、网络和官网登录状态可能延迟或阻止执行，这些间隔不是准点实时保证。移动、联通、广电可尝试后台读取；电信仍需打开应用，从指定官网账务 DOM 估算余量并标“约”。

桌面添加区分已有组件、等待系统确认、不支持和未添加，系统受理请求不再视为添加成功。没有弹窗时可长按桌面空白处，进入“小组件”，找到“流量小伙伴”并拖到桌面。组件支持两个同运营商账号分别占位、缩放和点击刷新入口，缺少某个账号数据时不会借用另一个账号。

## 安装包与验证

公开仓库为 [liuliang-buddy](https://github.com/huachen19867/liuliang-buddy)，[本版下载页](https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.5.0)附有 `liuliang-buddy-debug.apk`。版本为 1.5.0/code 8，Android 7.0/API 24 及以上，target API 36，仅 ARM64。使用 Android Debug 签名，APK v2 验签通过，未启用 DEMO 编译参数。包大小 90,035,780 字节，约 85.9 MiB。

SHA-256：`8657856bd3f79380568b6ee786ec03059c877e7225a63ba177a669f6e31a65fa`。

完整 Flutter 95 项通过，`flutter analyze` 无问题，应用模块原生 JUnit 13 项通过（12 项桌面展示与 1 项任务永久失效）。Node 页面探针回归通过，Chrome 全本地合成电信账务 DOM 的 8 个场景通过，`actualAccountVerified=false`。最终 Android ARM64 构建、版本/API/架构和签名检查通过。构建脚本先用工作区 ASCII PUB_CACHE 重新执行 pub get，避免 JNI CMake/Ninja 读取中文全局缓存路径失败。

两张新应用内截图为 `artifacts/dashboard-two-mobile-unlimited-demo.png` 和 `artifacts/carrier-selection-four-demo.png`，来自实际 Flutter 组件，带明显演示标记。其号码、时间和余量为合成样本，不代表真实运营商账号验证。

## 尚待验证

本工作区没有连接安卓设备，未验证真实双号码登录、四家的真实不限量套餐、后台长期触发或 Samsung S25 Ultra / One UI 的 Launcher 弹窗与缩放。前后台任务检查与偏好快照写入尚不是跨引擎原子事务，极短交接窗口仍需真机竞态验证。官网改版或会话失效也会影响查询；电信显示值存在舍入及共享额度边界。请到 [GitHub Issues](https://github.com/huachen19867/liuliang-buddy/issues)或原评论区反馈版本、设备、WebView 与复现操作，并打码手机号。

目前没有 iOS 安装版。现有 Flutter 界面和解析器可复用，但 iOS Runner、WKWebView 账号隔离、WidgetKit、后台调度以及 macOS/Xcode 签名与设备验证还需独立开发。各条反馈的处理范围见 [USER_FEEDBACK.md](USER_FEEDBACK.md)，实现与风险已登记到技术日志及三个复核文档。
