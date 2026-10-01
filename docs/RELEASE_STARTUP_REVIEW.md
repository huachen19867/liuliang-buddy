# 1.8 正式版启动退出：只读审核

2026-10-01，收到老板的正式版启动退出反馈后开展。先复核 TECH_LOG.md 的 1.8 构建记录，复用本工作区插件源码、最终 Release 合并清单和 R8 配置/映射文件。未执行 Flutter、Dart、Gradle 或修改产品代码，未获得真实设备崩溃堆栈。因此目前只能列出可验证范围，不能把 R8、系统版本或 WebView 认定为根因。

## 已核实的变化

比较 `2ab0fd7..ecb8903`（1.7 发布回执至 1.8 最终应用构建源码），Android 新增发布签名、ARM64 过滤、应用 R8 与资源裁剪，以及通知/快捷设置入口。vendor 插件与 pubspec.lock 在这一区间没有变化。旧版交付为 Debug，不能用旧 Debug 能启动证明新 Release 能启动。正式签名与旧 Debug 不兼容会导致安装失败，本身不能解释已经安装成功后的启动退出。

Release 合并 AndroidManifest 标记 1.8.0/code11、minSdk24、targetSdk36、普通 android.app.Application，MainActivity 与 TileService 名字完整。R8 mapping 中 MainActivity、TrafficQuickSettingsTileService、GeneratedPluginRegistrant 原名保留。GeneratedPluginRegistrant 有 @Keep，插件用直接构造调用注册，并非通过插件类名字符串反射。未发现活动类或注册器被删的证据。

## 插件、反射与 consumer 规则

`app/build/app/outputs/mapping/release/configuration.txt` 已包含 vendor 的整包 keep `com.pichillilorenzo.flutter_inappwebview_android.**`，JavaScriptInterface 方法保留，JNI/JNI Flutter 整包 keep、WorkManager worker 名字及构造器、Tink shaded protobuf/Datastore protobuf 字段规则。不存在“插件 consumerProguardFiles 完全没传到应用”的问题。

vendor `proguard-rules.pro` 的单条 JavaScriptBridgeInterface 类名写法可疑，WebViewClient 某条签名也有拼写问题，但被后面的插件整包 keep 和 JS 注解规则覆盖，不能据此声称已发现闪退原因。vendor Release 本身也做一次 minify，此设置在 1.7 已存在；两阶段优化仍需以实际 NoClassDefFoundError/NoSuchMethodError 指向确认，而不是盲目添加全部 Kotlin keep。最终 mapping 可见 kotlin.jvm.internal.Intrinsics 被重命名，重命名本身属于正常直接调用优化，不证明依赖缺失。

flutter_secure_storage 11.2.0 采用 Java 直接注册；onAttachedToEngine 创建工作线程和通道，初始化有 Exception 处理。实际安全存储按方法调用延迟创建，Dart 恢复广电会话的读操作有 catch 与三秒超时。插件没有额外 consumer 文件不等于缺规则，其 Tink protobuf 规则已经合入最终配置。当前没有支持“首次启动必由 KeyStore 异常致死”的证据。

## 优先观察的启动路径

Dart main 先初始化 binding 并 runApp；FlowHome.initState 异步 `_restore` 读取 SharedPreferences，然后同步后台计划、发布 Widget 快照。1.8 新增 `TrafficWidgetProvider.updateAll -> SystemSurfaces.refresh -> refreshNotification -> status`。即使通知尚未开启，status 仍先访问通知服务及 TileService 组件状态。该链路确实在冷启动恢复结束时可达，比只有用户点击设置才运行的代码更值得从堆栈核实；服务类型转换/组件状态等系统调用不都有异常隔离，但未在设备上证实有异常。

SharedPreferences.getInstance 与部分恢复流程没有顶层恢复失败 UI；若产生 Dart 异常，可能停留加载界面，但这通常不能直接解释 Android 进程死亡。需要区分“回到桌面”“白屏不动”和“进入后再退”。WebView 插件在 engine 注册时已加载部分管理器，所以不能因为用户没点连接号码就绝对排除 WebView provider/类链接问题；不过相同插件源码此前存在。

## 最快证据与安全修复边界

保持原安装资料，不清数据、不卸载。设备连上 adb 后，先记录 `adb logcat -b crash -d -v threadtime` 与 `adb shell dumpsys activity exit-info cn.liuliang.liuliang_app`；抓一份完整 logcat 到忽略的本地产物目录，随后 `adb shell am force-stop cn.liuliang.liuliang_app`、`adb shell am start -W -n cn.liuliang.liuliang_app/.MainActivity` 重现并结束采集。保留 FATAL EXCEPTION/AndroidRuntime 的完整 Caused by 链、libc tombstone/Flutter 错误附近内容，同时记录 Android 版本、设备 ABI、WebView provider（dumpsys webviewupdate）及所装 code11。不要仅按 PID 过滤，因为进程可能在获取 PID 前已退出，也不要清除现有日志。

用与实际 APK 一致的 mapping.txt 还原 Java/Kotlin 栈；若是 SIGSEGV/libflutter/Impeller 栈，不能当作 keep 规则问题。若堆栈明确指向反射目标，补最小精确 keep 并验证相同设备 Release 冷启动。若指向新增系统入口调用，让非核心系统展示失败可降级并返回可观察状态，避免吞掉所有 Throwable。如果没有设备证据，只能制作本地诊断包或跑同构 Release smoke，不能宣称根因已修。暂时关混淆做对照能缩小范围，但不等于完成定位，更不应直接覆盖公开正式包。

本次结果为静态核查，无真机启动验证。最终 APK 签名/大小及构建通过的历史记录不能替代 Release 实际启动 smoke；应把正式签名 Release 冷启动、进入首页、打开连接页纳入下一次交付验收。

## 多设备反馈后的 JNI 补核

老板补充荣耀设备与 iQOO 13 / Android 16 均出现退出。根代理另行核查已发布 APK 的四个 SO ELF LOAD 及 ZIP 16 KiB 对齐，本代理不重复其结论。这里继续核对实际 Release 名称与源码调用，仍没有设备堆栈。

默认 proguard-android-optimize 片段虽然只写 android.support.annotation.Keep，最终合并配置第 566 行起另有 `META-INF/proguard/androidx-annotations.pro`，明确保留带 androidx.annotation.Keep 的类和成员。因此“Flutter embedding 使用 androidx Keep 而应用不识别”不成立。mapping 第 96818 行 FlutterJNI 原名保留，FlutterOverlaySurface、FlutterMutatorsStack、SurfaceTextureWrapper、TextureRegistry.ImageConsumer、FlutterCallbackInformation 亦保留；FlutterJNI 的 handlePlatformMessage、onPreEngineRestart、decodeImage 等原生回调保持原名。

复用本机 Flutter engine 源码 `shell/platform/android/platform_view_android_jni_impl.cc`：RegisterNatives 使用 FlutterJNI，GetFieldID 使用 nativeShellHolderId；与实际 `artifacts/liuliang-buddy-release.apk` 做只读 ZIP/二进制字符串核对，classes.dex 和 libflutter.so 均含 FlutterJNI、nativeShellHolderId、nativeInit、handlePlatformMessage、onPreEngineRestart。字符串检查不能代替全部 DEX 签名或执行验证，但没有观察到这一组名称失配。

JNI 1.0.3 的 JniPlugin 在静态初始化执行 System.loadLibrary("dartjni") 和 setClassLoader；生成注册器仅捕获 Exception，UnsatisfiedLinkError 等 Error 仍可能致死，这是需要栈证据的真实启动边界。当前 JNI/JNI Flutter 类及成员由 consumer 整包 keep，classes.dex 含 JniPlugin/setClassLoader，libdartjni.so 含预期 `Java_com_github_dart_1lang_jni_JniPlugin_setClassLoader` 名称。其 C 初始化查询 java/lang/Object、Exception 等平台类；无证据说明应用类被 R8 改名导致此处失败。flutter_secure_storage 本身是 Java/Tink 实现，不能把这条 dartjni 链错误归因为 secure storage 自带 JNI。

SystemSurfaces.status 的局部 SecurityException/IllegalArgumentException 或服务类型保护可提升兼容性，但应返回保守 unavailable 并记录错误，不能假装功能开启。还需明确 Flutter MethodChannel.java 的 IncomingMethodCallHandler 在第 285 行捕获 RuntimeException，转换 error envelope；由 Dart 发起的系统面板查询失败通常导致 PlatformException/恢复中断，不足以独立证明 Android 整个进程退出。广播/服务上下文另当别论。本轮未实施无证据的 blanket keep、关闭 R8 或全局吞 Throwable。

## 2026-10-01 已确认的启动根因

后续荣耀 BKQ-AN00 Android 16 原始 1.8 Release 栈明确为 WorkManager Room 数据库 WorkDatabase_Impl 的无参构造被 R8 移除，产生 NoSuchMethodException。proguard-rules.pro 精确保留该构造，1.8.1 正式签名包覆盖安装和冷启动成功，用户确认正常。本页前文是取得堆栈前的排查记录，不再作为未找到根因的结论。1.9 沿用该 keep 规则，不关闭 R8。
