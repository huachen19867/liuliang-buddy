# 本地依赖补丁

flutter_inappwebview_android 来源为 pub.dev 的 1.1.3，保留原 LICENSE。flutter_inappwebview 6.1.5 通过 pubspec 的 dependency_overrides 使用此目录。

唯一修改：android/build.gradle 中默认 ProGuard 规则由 proguard-android.txt 改为 proguard-android-optimize.txt。Android Gradle Plugin 9.0.1 拒绝前者，导致项目配置阶段直接失败；此调整适配当前 Flutter 3.44.8 模板，不修改 WebView 运行逻辑，也不修改机器共享 Pub 缓存。

将来上游兼容 AGP 9 后可移除 override 和本地副本，需重新运行查询探针测试及 Android 构建。
