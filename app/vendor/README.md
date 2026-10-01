# 本地依赖补丁

flutter_inappwebview_android 来源为 pub.dev 的 1.1.3，保留原 LICENSE。flutter_inappwebview 6.1.5 通过 pubspec 的 dependency_overrides 使用此目录。

本地修改有两组。android/build.gradle 中默认 ProGuard 规则由 proguard-android.txt 改为 proguard-android-optimize.txt。Android Gradle Plugin 9.0.1 拒绝前者，导致项目配置阶段直接失败；此调整适配当前 Flutter 3.44.8 模板，不修改机器共享 Pub 缓存。

为两张同运营商卡隔离网页登录会话，在 Android WebViewChannelDelegate 增加 `setAccountProfile`，调用 AndroidX WebKit 1.12.0 的 `WebViewCompat.setProfile`，仅接受应用命名的第二账户 Profile，且要求首次导航前调用；Dart AndroidInAppWebViewController 暴露支持检测、设置和删除接口。WebViewFeatureManager 增加仅删除 `liuliang_[a-z]+_2` Profile 的清理方法。运行时不支持 `MULTI_PROFILE` 时禁止添加第二账户，不把共享 Cookie 会话当独立号码。默认 Profile 继续服务旧账户，保留已有 Cookie 与 WebStorage。

清理调用携带是否可能存在独立 Profile 的本地标记。仅使用默认会话、从未创建第二 Profile 的设备即使不支持 MULTI_PROFILE 也可正常清除数据；曾用过第二 Profile 而内核失去能力时，仍保持待清理保护。创建前持久化所属标记，完整清理成功才撤销，避免收起卡片后遗漏历史登录。

将来上游兼容 AGP 9 且暴露等价的 Android 多 Profile 接口后，才可移除 override 和本地副本；替换前需核对旧默认会话迁移、第二账户隔离、清理失败保护，并重跑查询探针与 Android 构建。
