# 桌面卡片后台刷新

应用设置提供关闭、每 1 小时、每 2 小时和每天四个选项，默认关闭。前台在打开/返回及每 5 分钟尝试查询；每个账号同时最多一轮查询，已结束的网页加载不触发循环重载。设置保存后由 Android WorkManager 建立唯一联网周期任务，以 Flutter 后台引擎与 `HeadlessInAppWebView` 打开运营商官网，沿用响应门禁与 Dart 解析器。成功解析后按账号更新本地记录和桌面卡片。

后台只查询当前选中、曾连接且已有成功查询时间的账号，移动、广电和联通可尝试；电信依赖前台账务 DOM 与临时网页状态，仍需打开 APP。第一账号沿用旧默认会话，第二个同运营商账号必须先绑定独立 WebView Profile 再加载；不支持时失败而不回退至第一账号的会话。广电会话备份也按账号隔离，仅成功查询后更新。明确的不限量结果不要求有限余额即可视为成功，不生成零或无限 GB。后台不替用户输入登录资料，不读取或发送短信。

WorkManager 周期执行不精确。Android 最小周期是 15 分钟，设置的一小时、两小时和一天都可调度，但 Doze、省电策略、厂商限制、网络可用性和官网响应都可能推迟或跳过本次执行。成功时小组件时间取运营商结果时间；失败时保留上次数据与原查询时间并标记失败/待验证。运营商账单同步本身也可能延迟，因此不承诺实时余额。

若检测到登录失效，后台停止该账号的重复尝试，需用户在官网重新验证。初始化最多等待 30 秒，之后整轮最多等待 4 分钟；每张卡的 Headless 启动和响应另有超时。停止、改设置或进入前台会永久作废当轮任务，迟到回调不能继续更新桌面。清除网页登录数据未完整完成时，持久化待清理标记会暂停后台，直到用户重试清理成功。点击桌面卡片仍会进入 APP 按前台路径查询。

设置中的最近后台状态来自实际任务记录，区分成功、部分成功、无新结果、取消、超时、无可查询账号和待清理暂停；时间是任务时间，独立于官网余额查询时间。进程中途终止可能只留下“曾启动、结果未确认”，不能据此推断成功。

本版新增周期选项、执行状态和任务永久失效回归验证，最终结果见版本说明与 [可靠性复核](REFRESH_RELIABILITY_REVIEW.md)。目前仍没有安卓设备：真实官网 Cookie/Profile 会话、双移动号码、厂商省电、实际任务触发与 Launcher 更新未经真机验收；极短前后台交接也尚非跨引擎原子事务。源码测试和编译不等于 S25 Ultra 或任意套餐已经验证。

参考 Google 官方 `android/architecture-components-samples/WorkManagerSample`，精选仓库源码和 Apache-2.0 许可证保存在 `references/android-workmanager-sample/`。官方周期任务说明见 https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work ，周期 API 见 https://developer.android.com/reference/androidx/work/PeriodicWorkRequest 。
