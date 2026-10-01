# 用户反馈与支持范围

2026-10-01 收集。反馈原文是用户报告，不能作为已复现或已验证的结论。对应实现和验收结果更新到技术日志。

## 自动刷新是否可用

运营商余量以官网成功查询为准，桌面展示最近查询时间。后台一小时、两小时、每天是系统调度的尝试间隔，Android 省电、网络和官网登录状态都会影响实际执行。设置应显示后台最近一次实际尝试与结果，不能仅凭周期已配置就声称正在实时更新。

本轮排查后台任务取消和超时、前台网页重复加载引发的连续刷新、登录失效后的状态，以及账号隔离后的后台同步。真实余额、长期后台运行和厂商省电策略仍需安卓设备核对。实现细节见 [刷新可靠性复核](REFRESH_RELIABILITY_REVIEW.md)。

## 两个移动卡

重复选择运营商需要生成两个独立账号，不能把同一份官网 Cookie 的结果放到两张卡。安卓账号隔离依赖系统 WebView 的多 Profile 支持；不支持时应阻止添加重复运营商并说明升级 Android System WebView 的条件。每家最多两张、合计最多四张，各自保存登录、查询时间、流量和后台状态。旧账号和记录要平滑迁移。实现和限制见 [多账号复核](MULTI_ACCOUNT_REVIEW.md)。

## 不限量套餐一直查询

目前未知报告来自哪家，按四家排查。官网明确标记不限量时，应结束加载、记录成功查询时间并显示不限量，不转换成无穷 GB、零余额或低流量提醒。不限量套餐可能达量限速或有用途限制；巨大数值、负数或格式缺失不能单凭猜测当作不限量。已实现四家明确标记的定向解析与缓存验证；实际套餐字段仍需官方余额对照。

## 点添加没有桌面弹窗

老板确认失败发生在点击后没有系统弹窗。Launcher 接受固定小组件请求并不代表用户已完成添加。应用需要区分已有组件、请求等待确认、不支持和失败，并始终提供手动入口：长按桌面空白处，进入“小组件”，找到“流量小伙伴”并拖到桌面。S25 Ultra 的 One UI 弹窗、缩放和后台省电须真机验收。实现细节见 [桌面兼容性复核](WIDGET_COMPATIBILITY_REVIEW.md)。

## S25 Ultra 安装与反馈

欢迎在评论区或 [GitHub Issues](https://github.com/huachen19867/liuliang-buddy/issues)反馈。安装包适用 Android 7.0 及以上 ARM64 设备，S25 Ultra 属于目标架构，但这不等于已验证该机型。反馈请说明应用版本、系统版本、WebView 版本、默认桌面、所用运营商和复现操作；手机号打码，避免分享登录凭证与验证码。本工作区没有连接该手机，不能代替机主安装或验收。

## 是否有 iOS

1.6.0 源码新增 iOS 17 Runner、原生通知、持久化 WKWebView 双账号隔离和 WidgetKit 小/中/大号桌面组件。老板没有 Mac，改用公开仓库 GitHub macOS runner 编译、模拟器启动与截图，详细入口见 [IOS_BUILD.md](IOS_BUILD.md)。当前仍没有可安装的签名 iPhone 版本，也未测试真实运营商账号。组件 timeline 只更新最近快照的展示，不查询运营商，iOS 设置不提供安卓后台周期选项。真实 iPhone 分发需要开发者团队签名、App Group provisioning 与设备验证，未交付 TestFlight 或 App Store 版本。

官方环境参考：[Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)、[WidgetKit keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)。精选官方资料保存在 `references/ios-platform-review/`，来源和下载状态记录在其 `index.json`。

## 联通登录后一直转圈

新增截图反馈明确来自联通，但未提供应用版本或官网余量画面。排查发现登录返回被上一轮刷新节流拦截、旧 loading 快照恢复后没有计时器，以及官网合法页面地址变化导致响应拒收的路径；修复与回归证据见 [联通刷新记录](UNICOM_REFRESH_PROGRESS.md)。查询失败应结束加载并说明原因，保留旧余量及原查询时间；这不等于已验证反馈者的实际套餐或官网响应。

## 移动特殊卡需要官方 App 人脸验证

截图中的“哑巴卡”尚不能确定正式卡型或登录规则。移动连接页增加帮助说明和核实过的[中国移动官方 App 入口](https://www.10086.cn/cmccclient/)。需要人脸验证时由用户在官方 App 完成，返回后仍需在本应用官网会话中独立验证；官方 App 的登录不会自动同步。如果该号码只允许官方 App 查询，当前方式暂不支持自动查询。官方资料与限制见 [移动人脸登录研究](MOBILE_FACE_LOGIN_RESEARCH.md)，未验证真实号码。
# 2026-10-01 通话与短信余量反馈

新增反馈要求查询剩余通话和短信：首页每账号新增独立面板，复用官网账务响应，不读取短信或通话记录。四家字段与证据边界见 [VOICE_SMS_RESEARCH.md](VOICE_SMS_RESEARCH.md)，界面与截图用例见 [VOICE_SMS_UI_PROGRESS.md](VOICE_SMS_UI_PROGRESS.md)。缺失不是零，联通短彩信不改为纯短信，电信舍入差值标约，短信次数不擅自换条；桌面暂仍流量。真账号结果待复测。
