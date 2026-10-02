# iOS 网页会话与平台行为

2026-10-02 更新：每家数量扩到一至四张、总四张；第三/第四账号采用新增固定 UUID，旧第二账号 UUID 保持不变，清理遍历全部十二个副账号仓库。快照门禁接受 primary/_2/_3/_4。Widget small/medium/large 仍分别展示1/2/4张；本轮源码与验证进度见 [多账号说明](MULTI_ACCOUNT_PROGRESS.md) 和 [版本说明](RELEASE_1.10.0.md)。以下原双账号说明保留作实现沿革。

2026-10-01。公开 Flutter iOS 工程复用现有四家运营商官网链接、响应来源门禁、解析器和前台五分钟查询。主账号继续使用 `WKWebsiteDataStore.default()`，保留升级前可能已有的 Cookie 和网站存储。每家第二账号使用 iOS 17 的 `WKWebsiteDataStore(forIdentifier:)`，对应固定的四个 UUID；同一账号跨应用启动仍用同一持久仓库。没有使用 `nonPersistent()` 代替持久隔离。

`app/vendor/flutter_inappwebview_ios` 是 pub.dev `flutter_inappwebview_ios` 1.1.2 的项目内副本，保留 Apache-2.0 `LICENSE`。`AccountWebViewSettings.toMap()` 传递 `liuliangAccountProfile`；本地 Swift 补丁在创建 `WKWebView` 之前设置 `WKWebViewConfiguration.websiteDataStore`。无效或不支持的 profile 不创建网页，避免落入主账号默认仓库。插件的管理通道 `com.pichillilorenzo/flutter_inappwebview_manager` 增加 `liuliangSupportsAccountProfiles` 和 `liuliangDeleteAccountProfiles`，后者遍历四个固定仓库清空全部 WebKit 网站数据，不依赖当前卡片列表，因此收起的历史第二账号也会清理。

添加第二账号前持久化 `account_profiles_may_exist`；恢复已保存账号时也先写该标记，再让账号网页出现。Native 在打开独立仓库前另写 UserDefaults 所属标记。清理先持久化 `account_profiles_cleanup_pending`，停止请求、卸载网页，再清理默认 Cookie/WebStorage、四个独立仓库、各账号快照和安全存储中的广电会话。任何清理失败都保留 pending 并锁住查询，避免旧网页会话混入新账号。

iOS 桌面小组件只显示应用上次查询结果。点击卡片会打开应用并请求前台刷新；应用开启时仍可自动查询。iOS 设置页不提供 Android 的 1 小时、2 小时、每天后台间隔，调度通道只配置关闭状态。低流量通知经用户授权后由本机投递。小组件需要用户在主屏幕手动添加，系统没有与 Android 相同的直接固定弹窗。

验证边界：Windows 上可执行 Dart/Flutter 静态分析和模拟平台通道测试；无法运行 Xcode、CocoaPods 编译、iOS 模拟器或真实运营商登录。Mac 上应执行 `scripts/verify-ios.sh`，再在 iOS 17 及以上设备检查第二号码隔离、应用重启后的登录保持、清除后的重新验证、WidgetKit 时间线和通知授权。尤其要核对官网页面在 WKWebView 中的登录跳转和 Cookie 规则。
