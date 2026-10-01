# 本地依赖补丁

flutter_inappwebview_android 来源为 pub.dev 的 1.1.3，保留原 LICENSE。flutter_inappwebview 6.1.5 通过 pubspec 的 dependency_overrides 使用此目录。

本地修改有两组。android/build.gradle 中默认 ProGuard 规则由 proguard-android.txt 改为 proguard-android-optimize.txt。Android Gradle Plugin 9.0.1 拒绝前者，导致项目配置阶段直接失败；此调整适配当前 Flutter 3.44.8 模板，不修改机器共享 Pub 缓存。

为两张同运营商卡隔离网页登录会话，在 Android WebViewChannelDelegate 增加 `setAccountProfile`，调用 AndroidX WebKit 1.12.0 的 `WebViewCompat.setProfile`，仅接受应用命名的第二账户 Profile，且要求首次导航前调用；Dart AndroidInAppWebViewController 暴露支持检测、设置和删除接口。WebViewFeatureManager 增加仅删除 `liuliang_[a-z]+_2` Profile 的清理方法。运行时不支持 `MULTI_PROFILE` 时禁止添加第二账户，不把共享 Cookie 会话当独立号码。默认 Profile 继续服务旧账户，保留已有 Cookie 与 WebStorage。

清理调用携带是否可能存在独立 Profile 的本地标记。仅使用默认会话、从未创建第二 Profile 的设备即使不支持 MULTI_PROFILE 也可正常清除数据；曾用过第二 Profile 而内核失去能力时，仍保持待清理保护。创建前持久化所属标记，完整清理成功才撤销，避免收起卡片后遗漏历史登录。

将来上游兼容 AGP 9 且暴露等价的 Android 多 Profile 接口后，才可移除 override 和本地副本；替换前需核对旧默认会话迁移、第二账户隔离、清理失败保护，并重跑查询探针与 Android 构建。

`flutter_inappwebview_ios` 来源为 pub.dev 1.1.2，保留原 Apache-2.0 `LICENSE`。本地 Swift 补丁为第二账号在 WKWebView 创建前设置 iOS 17 的持久 `WKWebsiteDataStore(forIdentifier:)`，并通过插件管理通道检测与清理四个固定账号仓库。主账号继续使用默认持久仓库。配套 Dart 创建参数与清理约束见 `docs/IOS_SESSIONS.md`；将来升级插件需复核创建顺序和完整清理，不可退回共享会话或临时会话。

iOS 18.4/18.5 模拟器的 WebKit Swift overlay 打包缺陷会导致本插件在进入 main 前报 `Library not loaded: /usr/lib/swift/libswiftWebKit.dylib`。见 [WebKit 官方问题 293831](https://bugs.webkit.org/show_bug.cgi?id=293831#c2) 与 [插件上游问题 2636](https://github.com/pichillilorenzo/flutter_inappwebview/issues/2636)。保留 podspec 正常链接及所有 WebKit API；弱链接可能把启动失败延迟到调用时失败，不作为修复。`scripts/verify-ios.sh` 从选中 simulator 的 JSON 动态解析 runtimeRoot，只有普通库路径缺失且 Apple Cryptex 同名库实际存在时，才设置模拟器子进程的 `DYLD_FALLBACK_LIBRARY_PATH`；普通启动与 Flutter drive 共用该环境。真实设备签名产物、最低 iOS 17 与账号隔离不受影响。路径和条件记录在 CI 的 `ios-diagnostics/webkit-runtime.json`；未来正常 runtime 不应用该兼容设置。官方页面与上游回帖已归档至忽略目录 `references/ios-webkit-linker`。
