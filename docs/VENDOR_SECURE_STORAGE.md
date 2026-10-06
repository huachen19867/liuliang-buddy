# Secure Storage Android 跨引擎调度补丁

2026-10-06 从现有 `.tools/pub-cache/hosted/pub.dev/flutter_secure_storage-11.2.0` 复制必要源码到 `app/vendor/flutter_secure_storage`，复用上游 11.2.0，不重复联网下载。上游为 https://github.com/mogol/flutter_secure_storage ，许可证 BSD-3-Clause，原文完整保留在 `app/vendor/flutter_secure_storage/LICENSE`。保留上游 lib、Android 源码和测试、Gradle 配置、README、CHANGELOG 与 pubspec；未复制 example、缓存或构建产物。仅移除 pubspec 的上游 monorepo `resolution: workspace`；其余平台仍使用原 federated dependency（包括 Darwin），没有复制或修改其他平台密码实现。

Android 新增 `CompletionSerialQueue`，一个进程共享线程/FIFO 包含初始化、读取、写入和删除。只有真实原生成功/失败回调才释放下一个操作，Runnable 返回、Dart 超时和引擎 detach 都不释放。`MethodResultWrapper` 对重复完成去重，消息回传失败不阻断已完成队列。引擎 detach 只将 owner 失效，不停止公共线程、不清空活动操作正在使用的 context/cache；操作引用自然释放之后实例可以回收。

`FlutterSecureStoragePlugin.setOwnerCurrentGuard(BooleanSupplier)` 由 `BackgroundRefreshWorker` 在创建引擎后、执行 Dart 前绑定现有 `current()`。排队操作在开始 initialize 前检查 owner，初始化完成后再次检查，再执行请求；已开始的加密/初始化不能强行取消，其真实结束后才轮到前台删除。所有前台删除必须通过相同插件，且只有真实删除返回后才能宣布清理成功。没有新增加密算法、密码、令牌、密文格式或键迁移逻辑。

本补丁不保证损坏或永久无响应的 KeyStore 能恢复。Dart 层需要对观察等待设期限、允许用户得到明确错误，并在删除未完成时保留 cleanupPending；不能以超时充当物理删除完成。后台存储 owner 失效不能被业务误判成运营商认证失效。原插件 apply 的语义保留，不额外声称介质安全擦除或断电持久性增强。iOS 原平台存储调度没有改变。

新增纯 Java JUnit 队列测试覆盖异步完成前不调度删除、失效后台排队任务不写入、重复完成不能越过下一在途操作。它们验证调度原语，不伪装为 KeyStore 或真实账号测试。生产插件编译、单元测试执行和根 Dart 接线由根任务统一串行验证；本文创建时尚未运行 SDK。

根串行验证：新增CompletionSerialQueueTest三项零失败/零错误，Android app35项零失败/零错误，插件与Worker已编译通过（Worker registry返回基类，需显式安全cast后绑定guard）。Flutter完整328项及analyze通过，后台真实入口的读取抛异常/挂起两项验证本地故障不误判authExpired；FlowHome清理超时保留pending。该证据不等于真实KeyStore损坏恢复或目标设备长时后台验收。
源码暂存检查发现上游README/CHANGELOG及两份Java文件带尾随空白，仅规范行尾空白以通过diff检查，未改任何密码学语句或原许可证。
