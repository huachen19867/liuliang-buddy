# iOS 小组件与原生桥接

2026-10-02 更新：每家数量扩到一至四张、总四张；第三/第四账号采用新增固定 UUID，旧第二账号 UUID 保持不变，清理遍历全部十二个副账号仓库。快照门禁接受 primary/_2/_3/_4。Widget small/medium/large 仍分别展示1/2/4张；本轮源码与验证进度见 [多账号说明](MULTI_ACCOUNT_PROGRESS.md) 和 [版本说明](RELEASE_1.10.0.md)。以下原双账号说明保留作实现沿革。

本实现最低 iOS 17，Runner 标识为 `cn.liuliang.liuliangApp`，扩展为 `cn.liuliang.liuliangApp.TrafficWidget`，二者共享 App Group `group.cn.liuliang.liuliangApp`。签名时必须在开发者账户中为两个 target 配置同一 App Group；Windows 源码检查不能替代 Xcode 构建、签名和真机验收。

已读取技术日志，复用 `references/ios-home-widget` 中固定提交的 BSD-3-Clause home_widget 示例和已保存的 Apple WidgetKit 说明，采用 App Group + WidgetKit 的公开平台方案。本项目不引入 home_widget 插件或它的后台执行能力，沿用自己的显示快照协议。

## 数据与查询语义

`Shared/TrafficSnapshot.swift` 同时编译进 Runner 和扩展，只保存白名单显示字段。schema 2 的 `instances` 最多四个独立账号，账号 id 校验为运营商名或其 `_2` 后缀，重复 id 丢弃。未知运营商丢弃，未知状态保守显示失败；无查询时间时不展示确认余额，负数、布尔数值和非有限数值不作为余额。不限量可以独立于有限 GB 展示，失败后仍保留原查询时间与旧值，但注明需验证或保留记录。不会将 Cookie、会话或原始运营商响应写入 App Group。

小组件展示上次前台查询缓存。WidgetKit 每小时的 timeline 更新只用于显示数据变旧，不请求运营商、不更新 `queriedAt`，系统也可能延迟时间线。查询成功后 Runner 请求 `reloadTimelines`，是否立即重绘仍由系统决定。小号显示第一张卡，中号前两张，大号最多四张；超出容量会提示还有其他卡。所有尺寸都支持 `liuliang://refresh`，打开应用完成前台查询。

## 原生接口

`LiuliangPlatformBridge.register(messenger:)` 返回需由 AppDelegate 持有的桥接对象，`handle(url:)` 接收冷启及运行中的小组件 URL。冷启标记保留到 Dart 调用 `consumeLaunchRefresh`；运行中同时发送 `openFromWidget`，前台查询通过自身请求门禁合并重复唤醒。

`cn.liuliang/widgets` 提供 `updateSnapshot`、`clearSnapshot`、`consumeLaunchRefresh`、`requestPin` 和 `installationStatus`。iOS 不提供从应用弹出固定桌面的 API，`requestPin` 返回 `unsupported` 及手动添加说明。安装检查使用 WidgetCenter 当前配置返回 `already_added` 或 `not_added`，读取失败明确返回未知，不把方法调用成功当成添加成功。

`cn.liuliang/notifications` 使用 UNUserNotificationCenter 实现授权、低流量通知和取消。桥接对象由 AppDelegate 持有，并注册为通知 delegate，让前台余额检查也能展示横幅。授权及通知异步回调回到主线程后再完成 FlutterResult。`cn.liuliang/background_refresh_schedule` 只接受关闭；非零间隔返回 `unsupported_platform`，状态也明确为不支持后台流量查询。没有注册 BGTask、假定时任务或后台 WebView。

## 可复用验证

macOS CI 可执行 `swiftc app/ios/Shared/TrafficSnapshot.swift app/ios/Tests/TrafficSnapshotTests.swift -o /tmp/traffic-model-tests`，再运行生成的测试程序。覆盖独立双账号、重复 id、错误运营商映射、无查询时间、不限量旧值、负数/布尔数值、数据过期、编码白名单、往返时间保持、最多四卡、损坏缓存和清除缓存。扩展 SwiftUI 和 Flutter 原生桥接仍须 Xcode 构建验证。

实施机器是 Windows，没有 Swift/Xcode；本阶段仅完成源码与协议检查，模型测试及两个 target 的编译结果由 macOS CI另行记录。小/中/大实际布局、深链冷启、授权弹窗、App Group 跨进程可见性、真实运营商登录及设备余额均需要 iPhone 或模拟器进一步验证。
