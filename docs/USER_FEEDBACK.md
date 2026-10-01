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

目前提供 Android APK 和 Web 演示，没有可安装的 iOS 版本。项目尚无 iOS Runner 或 WidgetKit 扩展；当前 Windows 工作区也没有 Xcode、iOS 签名或测试设备。Flutter 界面和解析器可复用，但原生通知、桌面组件、账号的 WKWebView 数据隔离和后台调度需要单独适配。iOS 桌面使用 WidgetKit timeline，由系统决定刷新，不能照搬安卓 WorkManager 或承诺定点实时余额。正式 iOS 开发至少需要 macOS/Xcode、签名配置和设备验证；当前未将此条标为已交付功能。

官方环境参考：[Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)、[WidgetKit keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)。精选官方资料保存在 `references/ios-platform-review/`，来源和下载状态记录在其 `index.json`。
