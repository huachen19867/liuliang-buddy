# iOS 源码与构建

iOS 工程位于 `app/ios`，基于本机 Flutter 3.44.8 官方模板生成，沿用 Flutter 的 UIScene 生命周期。最低 iOS 17，主应用 bundle ID 为 `cn.liuliang.liuliangApp`，WidgetKit 扩展为 `cn.liuliang.liuliangApp.TrafficWidget`，两者共用 `group.cn.liuliang.liuliangApp`。共享模型只写桌面展示摘要，登录凭据不进入 App Group。

本仓库提供可构建源码和 GitHub Actions macOS 验证，不包含可直接安装到 iPhone 的签名 IPA。Windows 本机不能执行 Xcode 编译；实际远程构建结果应以仓库 Actions 的对应提交记录为准。模拟器产物不适用于真机安装。

## 在 Mac 上验证

准备 Xcode（含 iOS 17 或更新模拟器）、CocoaPods 与 Flutter 3.44.8，在仓库根目录运行：

```bash
bash scripts/verify-ios.sh
```

脚本依次运行 Flutter 静态分析、Flutter 测试、共享快照 Swift 测试，编译未签名模拟器应用并检查嵌入的 `TrafficWidget.appex`，然后启动可用 iPhone 模拟器、安装打开应用并截图。输出为 `app/build/ios/iphonesimulator/Runner.app`、`app/build/ios-verification.log`、`app/build/ios-onboarding.png`。截图只证明初始页面可以启动，不等于真实运营商登录和流量准确性验证。

公开仓库的 `.github/workflows/ios.yml` 在相关源码 push / PR 或手动 workflow_dispatch 时执行上述脚本；使用 macos-15，不需上传 Apple 证书。失败时也保留已生成日志。模拟器应用另存为 `app/build/ios-simulator.tar.gz` 保留执行权限和符号链接。随后用 Flutter integration_test 在真实模拟器检查首次选择→未连接首页、手动添加指引与 iOS 设置，并将两张截图保存到 `app/build/ios-smoke/`。该测试只初始化空的测试偏好，不提供真实号码、会话或余量；原生 bridge 通道未被替换为 mock。Flutter CLI 使用同一 SDK 时串行运行。

依赖统一采用 CocoaPods；脚本关闭 Flutter 的 Swift Package Manager 自动迁移。手动构建时先在 `app` 运行 `flutter config --no-enable-swift-package-manager` 和 `flutter pub get`，再用 `flutter build ios --simulator --debug --no-codesign`。原生编辑应打开 `app/ios/Runner.xcworkspace`，不要单独打开 `.xcodeproj`。

## 真机签名与分发

拥有 Apple 开发者团队的维护者在 Xcode 中为 Runner 和 TrafficWidget 两个 target 选择同一团队，并为两个 identifier 注册 App Groups 能力、关联同一 App Group。需要使用自己唯一的 identifier 时，同步修改两个 target 的 `PRODUCT_BUNDLE_IDENTIFIER`、两份 entitlements 的 App Group，以及 `Shared/TrafficSnapshot.swift` 中共享组常量；插件的独立网站存储不需要加入 App Group。Runner 的 Keychain access group 使用当前签名团队前缀和应用 bundle identifier。

确认 provisioning profile 覆盖这些能力后，使用 Xcode Product → Archive，或在 `app` 运行 `flutter build ipa --release` 并通过 Xcode Organizer 导出/上传。版本与 build number 来自 `app/pubspec.yaml`，扩展通过 `Flutter/Widget.xcconfig` 读取相同的生成版本，避免归档时主应用与扩展版本不一致。本仓库不保存个人团队 ID、证书、私钥或签名 profile。

## 使用边界

iOS 小组件需要用户从系统主屏幕编辑界面手动添加，系统没有 Android 式弹窗固定接口。小组件展示应用保存的最近快照；点按打开应用刷新。iOS 系统不能承诺每小时或每两小时后台网页登录查询，因此后台周期选项应明确标示不支持。真实登录、双号码持久隔离、官网改版、通知授权与真实设备小组件布局仍需 iPhone 验证。

## 文件索引与参考

`Runner/AppDelegate.swift` 和 `Runner/SceneDelegate.swift` 注册平台桥接并处理冷热启动 URL；`Runner/LiuliangPlatformBridge.swift` 提供小组件、通知和后台能力响应；`Shared/TrafficSnapshot.swift` 由 Runner 与扩展共同编译；`TrafficWidget` 是实际 Xcode 扩展 target；`Tests/TrafficSnapshotTests.swift` 是不依赖 Flutter 的共享模型回归。工程依赖、Embed App Extensions 与 App Group 权限已经写入 `Runner.xcodeproj/project.pbxproj` 和 entitlements。

基础工程来自 [Flutter 官方仓库](https://github.com/flutter/flutter/tree/3.44.8/packages/flutter_tools/templates/app/ios.tmpl)。小组件接入参考已下载至忽略目录 `references/ios-home-widget`，来源为 [home_widget](https://github.com/ABausG/home_widget) 的官方 example，固定提交及许可见参考索引。参考目录不进入公开源码。
