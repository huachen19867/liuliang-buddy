# 桌面卡片后台刷新

应用设置提供关闭、每 1 小时、每 2 小时和每天四个选项，默认关闭。前台原有的打开/返回刷新与每 5 分钟尝试查询不变。设置保存后由 Android WorkManager 建立唯一周期任务，并要求设备有网络；周期任务启动 Flutter 后台引擎，以 `HeadlessInAppWebView` 打开运营商官网，复用同一应用沙盒中的 WebView Cookie，并沿用现有响应门禁与 Dart 解析器。成功解析后更新本地查询记录和原生桌面卡片缓存。

后台任务只查询已选中、曾连接且已有成功查询记录的运营商。它不会打开登录页面替用户输入资料，也不读取或发送短信。移动、广电和联通进入后台网页查询流程；当前电信读取依赖官网账务页的 `sessionStorage` 与已渲染 DOM，未纳入后台刷新。电信仍在 APP 前台查询。广电的两个必要 `sessionStorage` 字段从 Android 安全存储注入临时 Headless WebView；仅取得有效余额后才更新会话备份，后台认证失败时不会删除现有备份。

WorkManager 周期执行不精确。Android 最小周期是 15 分钟，设置的一小时、两小时和一天都可调度，但 Doze、省电策略、厂商限制、网络可用性和官网响应都可能推迟或跳过本次执行。成功时小组件时间取运营商结果时间；失败时保留上次数据与原查询时间并标记失败/待验证。运营商账单同步本身也可能延迟，因此不承诺实时余额。

若检测到登录失效，后台暂时停止该运营商的重复尝试；请在 APP 打开官方页面重新验证。一次后台任务最多等待四分钟，并按运营商顺序处理。系统杀掉进程或用户切回 APP 时，当前后台 WebView 会释放；下次周期可重新尝试。点击桌面卡片仍会进入 APP 并按前台路径查询。

本功能技术验证只覆盖源码集成与 Android 编译。尚未在真机上确认四家官网的后台 Cookie 共享、移动/联通/广电真实余额、厂商省电策略、WorkManager 实际触发时刻或桌面 Launcher 更新。部署后需要在老板手机上以真实号码核对，尤其检查认证过期时的状态与广电会话续用。

参考 Google 官方 `android/architecture-components-samples/WorkManagerSample`，精选仓库源码和 Apache-2.0 许可证保存在 `references/android-workmanager-sample/`。官方周期任务说明见 https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work ，周期 API 见 https://developer.android.com/reference/androidx/work/PeriodicWorkRequest 。
