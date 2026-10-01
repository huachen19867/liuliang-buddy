# 同运营商多号码实现复核

2026-10-01。已先检查 `docs/TECH_LOG.md`、现有四家官网探针、`references/` 参考索引及本地 `flutter_inappwebview_android` 1.1.3 源码。现有首页、缓存、控制器、超时与查询都按 `Carrier` 作键，直接增加第二张 UI 卡会显示同一份余额，也会共享 Android WebView 默认 Cookie。已有本地 AndroidX WebKit 1.12.0 AAR 的 API jar 经 `javap` 核对，包含 `ProfileStore`、`WebViewCompat.setProfile(WebView, String)` 和 `WebViewFeature.MULTI_PROFILE`。插件的 `WebViewEnvironment` 仅支持 Windows，并不能让 Android WebView 使用独立会话。

本版为每张卡建立稳定 `CarrierAccount.id`。第一张沿用运营商名，如 `mobile`，继续使用旧 `snapshot_mobile`、`connected_mobile` 和 Android WebView 默认 Profile，故升级不搬移或丢弃旧 Cookie 与记录。第二张用 `mobile_2` 等稳定 ID，独立记录写入 `snapshot_mobile_2`、`connected_mobile_2`，Android Profile 名为 `liuliang_mobile_2`。广电安全存储分别用旧 `broadnet_session` 和新增 `broadnet_session_broadnet_2`。`carrier_accounts_v1` 只保存 ID、运营商与展示标签，不保存手机号或凭证。隐藏或收起第二张卡保留本地历史；明确执行“清除本地连接”时才枚举四家主副八组已知键并尝试删除所有应用命名 Profile。

在选卡页轻点选择运营商，连续轻点两下请求加入第二张；最多展示四张，每家最多两张。隐藏的历史账户不占四张展示配额，最多保存八个元数据。第二账户加入前先检查本机 `MULTI_PROFILE`；不支持时明确解释无法隔离会话，并阻止创建第二卡。第二账户的 `InAppWebView` 不设置 `initialUrlRequest`，在 `onWebViewCreated` 中等待原生 `setAccountProfile` 确认成功后才加载官网地址。原生再次检查特性、Profile 名和 WebView 尚未导航；失败后不加载任何官网页面。默认 Profile 只留给第一账户。任何第二账户读取快照时都不回退第一账户数据，Widget 与后台也按 `accountId` 独立传递或存储。

前台刷新按账号独立记录控制器、30 秒限频、35 秒超时和进行中状态。进行中的请求才接受官网探针响应；接收前核对响应来源、当前 WebView 的页面 URL 和代次，避免切回登录页后的迟到响应恢复旧余额。登录页返回业务页只启动一次受控查询，初建 WebView 也只加载一次，防止重复 `onLoadStop` 触发循环。超时错误会保存到对应账号的快照，完成响应会取消超时。不限量套餐只显示官网明确标记和规则说明，不换算成无限 GB，也不触发有限通用额度的低量提醒。

清除前先持久化 `account_profiles_cleanup_pending=true`，再停止后台与网页、卸载视图并清理默认和独立 Profile、安全存储及各账户记录。全部完成并成功持久化后才清 pending 标记；清理失败、进程中断或 WebView Profile 暂时被占用时，重启后仍保持 pending，前后台所有账号都暂停查询，首页提示到设置里重试，不会把部分清理报告为全部成功。清理重试成功后才能重新连接。

Flutter 定向测试覆盖旧数据键迁移、同运营商双卡 ID、隐藏历史与重加、双击选择、受支持与不受支持的加入行为、不同卡片回调、不限量显示、清理中断后保持 pending。静态分析和 Android 编译由集成阶段记录在技术日志。当前没有真实手机与两个运营商账号，因此 WebView Provider 是否支持 `MULTI_PROFILE`、官方网页登录及两号码真实余额仍需要在老板手机上分别对照官网验证。支持检测只说明能力存在，不等于完成真实账号验收。

应用组件导出图 `artifacts/dashboard-two-mobile-unlimited-demo.png` 经目视检查，能区分“中国移动 1”和“中国移动 2”，并把明确不限量套餐显示为文字与规则提示，没有伪造 GB 数值。定向 Flutter 测试、选卡与首页原有测试通过；完整套件和 Android 原生构建仍以集成阶段记录为准。
