# 产品可交付性只读复核（2026-10-06）

本次受根任务委派，复核前台查询、会话持久化、后台刷新到 Widget 的稳定性。先阅读 `docs/TECH_LOG.md`、`docs/REFRESH_RELIABILITY_REVIEW.md`、`docs/PRODUCT_QUERY_REVIEW_1.10.1.md` 与 `references/README.md`，复用本地已下载的运营商公开页面、监控项目、Google WorkManager/AppWidget 参考；不重新下载同一资料、不调用真实运营商接口、不运行 SDK。只修改本文，下面是修复前代码证据，落实状态以根任务最终技术日志和测试回执为准。

## 移动查询在取得流量后可能永久停留在查询中

`app/lib/main.dart` 的 `_receive` 在移动流量成功后提前取消 `_timeouts[accountId]`（复核时约 1274 行），接着等待余额组装，最后再次执行无期限的 `controller.getUrl()`。后一次 URL 读取抛错、返回空值或与捕获页不匹配时直接返回；没有移除 `_inFlight`、没有将 loading 收敛到可重试状态，也没有重新启动超时。插件永不回调时同样没有剩余总期限。`_refreshAccount` 又会跳过 `_inFlight` 内账号，因此这是可达的无限查询状态，单纯补上 `getUrl.timeout` 并在 catch 中 return 仍不能解决。

建议为整轮保留终止保证，包括余额组装后的页面验证；页面变化或插件异常时只终止仍属于本轮的请求，保留上次成功时间。对应集成测试需要模拟“已收到成功流量，第二次 getUrl 挂起/失败/导航变化”，验证有限时间内退出 loading、可再次刷新、不把无效页的结果发布到 Widget。现有 `mobile_query_assembly_test.dart` 只验证独立组装等待，不覆盖主状态机这一段。

## 网页查询缺少每轮身份，迟到回调可能作用到下一轮

`app/lib/main.dart` 的 `_refreshAccount`、`_armOfficialTimeout` 和 `_receive` 主要依赖全局 `_generation` 与账号 `_inFlight`。正常同账号超时重试不会改变 generation。旧轮 `_receive` 先通过 `_inFlight` 检查，再等待 `getUrl()`；等待期间旧轮超时，新轮开始，旧回调恢复时相同 URL 与 generation 仍通过，可能将旧响应作为新轮数据接收。移动分支在第一次 await 之后才取 `_mobileQueries`，还可能取得新轮 assembly。另一条路径是旧 `loadUrl()` 在下一轮已经开始后才抛错，catch 会取消新轮 timer 并移除新轮 `_inFlight`。

建议网页流程采用与联通 App 模式类似的每轮 ticket，启动、超时、load 失败、所有异步恢复和提交前均检查当前 ticket。仅 Dart ticket 不能识别“旧网络响应在新轮才首次进入回调”的情况，网页探针可携带开始请求时捕获的 query epoch，避免同 URL 的旧文档请求混入新轮。已有来源/页面白名单应继续保留，它们解决来源校验，不代替请求时序隔离。测试需用可控 Future 让旧 `getUrl` 或 `loadUrl` 在第二轮才完成，并确认第二轮仍可正常完成、旧时间与余额不会覆盖。

## 安全存储写入仍可挂住账号队列

`app/lib/services/background_refresh_runner.dart` 在联通续期写入和 `_saveBroadnetSession` 中仍直接 await `_secureStorage.write`；读取已限制三秒，但写入没有期限。首卡写入插件不返回时，后续卡不会查询，直到原生 `BackgroundRefreshWorker` 四分钟总期限销毁引擎。前台 `main.dart` 的联通保存和 `_saveVerifiedBroadnetSession` 也把无期限的 secure write 放入 `_store` 串行队列，可能阻断后续快照、Widget 发布和清理动作。它并非运营商明确声明认证失效，不宜把本地读写故障自动记为永久跳过后台查询的 authExpired。

修复需同时考虑期限和迟到副作用：Dart `Future.timeout` 不会取消平台写入，不能超时后让旧写入在清除或新登录之后静默覆盖新凭证。可先对 UI/后台任务作有界失败和当前轮失效处理，保留持久化写入顺序；需要彻底解除写队列时，应使用平台级版本化/原子提交或明确的故障门禁。测试应模拟写入永不完成、超时后才完成、在此期间清除/新登录，确认旧凭证不会复活，且其他可独立账号仍能得到明确处理结果。

## 验收边界

以上三项是具体代码可达风险，没有伪装成真机已经复现。本次未修改生产代码、未跑 SDK、未新增真实运营商验收结果。修复后除针对性回归外，应检查新请求可以重试、失败保留旧成功时间、账号身份与查询轮次变化拒绝旧回包，以及主界面和 Widget 对同一已提交快照一致。没有发现足够证据要求重写现有解析器或采用未经公开授权的号码认证 SDK。

达到可交付状态仍需要真实账号验证官网登录、跨日前后台会话、实际套餐与余额单位、目标系统 WebView 多 Profile、桌面宿主刷新和系统节电行为。自动化、合成截图和构建通过只能证明其覆盖的行为；尤其移动/广电约三日官方认证失效，当前没有可据此保证永久免登录的公开契约。应将这些未完成项清楚记录在交付说明，不能用测试数量或包签名成功替代真号和真机验收。

## 安全存储最小修复设计补充

复核实际依赖为 `.tools/pub-cache/hosted/pub.dev/flutter_secure_storage-11.2.0`。Android `FlutterSecureStoragePlugin.java` 的 `workerThread`、`workerThreadHandler` 和 storage cache 均为实例字段，`initInstance` 每次创建线程；两个 FlutterEngine 并不共享 FIFO。`onDetachedFromEngine` 调用 `quitSafely`，不是取消已经运行的加密写入。`FlutterSecureStorage.java` 的默认 write 路径在同步 `cipher.encrypt` 后执行 `SharedPreferences.Editor.apply()`，再回调完成；默认 AndroidOptions 不要求生物认证，但插件也支持异步认证/初始化，不能一般性地把 Runnable 返回当作完整操作结束。

若本轮不 vendor 插件，安全的有限改动是只给业务等待设置期限，底层写入原 Future 仍保留在串行队列中。超时后 UI 可退出 loading，后台可继续处理不依赖该存储的账号，但清理必须保持 pending，不能因业务 timeout 就宣布凭证已删除。`_clearData` 当前首先通过 `_store` 保存 pending，队头已挂起时清理连门禁都无法建立；应在进入清理时直接 await 普通偏好保存 pending（独立于安全存储队列），然后作废查询和后台任务，等待既有写入真实完成再删。只做 Dart 改动仍不能证明跨引擎 delete 后无旧 write，交付说明必须保留此限制。

若本轮要求真正关闭跨引擎竞态，建议只 vendor 现有插件的 Android 调度层，不自建密码库，不改密文格式、key 或迁移算法。用进程级共享 FIFO 处理全部存储操作，队列出队条件是原插件操作的真实完成/失败回调，不能是 Dart timeout，也不能是 MethodRunner.run 返回。读取也应经过同一 FIFO，因为 initialize、迁移与 resetOnError 可能修改存储。每个引擎具有 owner，有 attached 状态；后台引擎通过新增的非密码学配置方法绑定现有 Worker 的 `current()` guard，前台 owner 正常启用。队列在开始初始化和执行实际存储方法之前检查 owner，过期后台请求直接失败，不读取/写入。后台 `current()` 涉及 app-visible、WorkManager 停止和 revision，现有原生永久失效版本可以复用。

已经执行中的写入不能强行取消，但共享 FIFO 保证后续清理 delete 只能在它真实完成后执行；因此清理不会先完成、旧写才复活。后台排队请求在 app-visible 失效后跳过，前台新登录写入和清理按队列顺序执行。detach 只作废 owner/解绑其消息通道，不能清空正在使用的 context/cache 或停止共享 worker；排队任务应使用捕获的 applicationContext，活动操作资源延迟到其回调完成再释放。向已经断开的 messenger 返回结果可作 best-effort，但必须在 finally 释放队列槽位。

业务层可对原 Future 的观察限三秒；超时后记录本地存储错误而不是 authExpired。后台下一账号仍可执行网络查询，安全存储确实卡住时其读取也应按已有期限失败，不能宣称所有账号还能刷新成功。清理 delete 若同样超时，保留 pending 且禁止新登录；迟到 delete 完成后用户可重试清理，只有全部删除成功才解除 pending。原 write 若永久卡死，安全边界优先于伪造清理成功；无需让界面一直转圈。

候选版本 key 不是本轮优先方案。旧后台在清除之后才写出候选 key，虽然前台不 promote 可以避免逻辑恢复，却留下磁盘凭证，违反“删除本地登录会话”的正常用户理解；必须同样提供跨引擎屏障或持久化候选注册与清理，复杂度并未消失。不要用这一方案把逻辑不可见说成已物理删除。

此设计最小验证应证明两个 owner 的 write/delete 不重排、异步 initialize 完成前不释放槽位、后台 owner 失效后排队 write 被跳过、运行中 write 完成后 delete 最后生效、Dart timeout 不释放底层槽位、detach 不使活动任务崩溃。删除成功只能表述为应用级数据已删除；现插件使用 apply，不额外宣称底层存储介质安全擦除。本文仍只提供设计，未修改插件或运行 SDK。

## 实施后复核进展

根任务后续明确授权实际实施 Android 调度补丁，现已新增 `app/vendor/flutter_secure_storage`，来源与改动详见 `docs/VENDOR_SECURE_STORAGE.md`，后台 Worker 已绑定 `setOwnerCurrentGuard`。2026-10-06 根任务反馈插件三项队列测试与应用原生检查通过；此回执为根任务实际执行，不是本审查独立重复运行。上文“只提供设计”描述的是该阶段的状态。

只读回看实际实现，默认非 biometric 的初始化、操作和真实完成回调均被同一 FIFO 包住；排队 owner 在初始化前与操作前检查，detach 不停止队列或清空活动引用。Dart 三秒 timeout 不再释放原生槽位，前台清理先独立保存 pending，任一 delete 超时保留 pending。当前未发现这条 Android 路径新增的可达“清除成功之后旧凭证复活”漏洞，也没有把永久卡死的 KeyStore 描述成可以自动修好。

实际集成回看仍指出三个具体收尾点并已通知根修正。广电 onLoadStop 登录分支在取消 query epoch 后 await 会话删除；删除超时直接抛出会跳过 `_inFlight` 清理，而失效 epoch 使原 timer 无法收尾，应先同步终止查询，再处理可失败的清理。后台联通读取超时转 null 后仍在本地异常 catch 返回 authExpired，二次读取同样 null 时会永久设置后台认证门禁；本地故障应返回 error，服务器明确过期才保持 authExpired。清理中的 stopLoading、Cookie/WebStorage/Profile 插件等待仍需有界，否则虽然 pending 安全保留，界面会一直停在 clearing；超时应记录未完成并继续独立清理，不能解除门禁。上述反馈是当次读取时的状态，根任务可能随后已修复，应以最终日志和代码为准。

根随后已落实上述三点：广电先结束查询再有界清理，联通本地读失败改error且用真实后台入口回归，清理的停止网页/Cookie/WebStorage/Profile和系统桥接都有期限。任一清理未完成保留pending；stopLoading超时也保留未完成状态。原生无epoch错误不结束轮；本轮35秒deadline仍有效。对应FlowHome和后台存储合成测试由根实际运行，最终全量回执另见TECH_LOG。未新增真号或KeyStore故障实机验收。
