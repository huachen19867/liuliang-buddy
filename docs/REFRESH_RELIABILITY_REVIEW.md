# 后台刷新可靠性复查（2026-10-01）

本次先阅读 TECH_LOG.md，复用 references/android-workmanager-sample 中 Google 官方示例和现有 AndroidX WorkManager，不重复下载依赖。1.4.0 的后台实现属于定时查询尝试，并非实时推送；没有真实运营商账号或 S25 Ultra 测试结果，不能把构建成功等同于可用。

## 已确认问题与修复

旧任务检查只看当前 Activity 可见性和配置版本，没有检查 WorkManager 的停止信号。用户快速打开再退出应用，旧后台任务可能再次被认为有效。现改用原子版本号，在前台进入时永久作废当轮任务，并将停止、超时、配置改变纳入同一任务门禁。根集成负责 MainActivity.onStart 调用 invalidateRunningTask。

Flutter 初始化被主线程排队时，初始化超时后旧 Runnable 仍可能创建引擎。新增取消标志，在初始化之前、初始化之后和启动 Dart 前检查；清理阶段先失效任务再销毁引擎。Headless WebView 的启动另设 15 秒上限，响应等待保持 40 秒，避免启动无返回导致整轮无限等待。

旧 Worker 无论是否查询成功都没有记录原因，无法区分没被系统调度、页面超时、没有已登录号码和真正取得新数据。现在持久化最近任务开始、结束及结果。成功、部分成功、无新结果、无可查询号码、取消、初始化失败和超时分别记录。记录里不保存账号、Cookie 或官方响应。进程被系统终止时可能只留下 running，因此 UI 文案明确为“后台任务曾启动，结果尚未确认”。记录的执行时间独立于每张卡的成功查询时间，不伪造新余额时间。

后台 JS 回调增加任务有效性及当前页面检查，已返回登录页的旧响应不能恢复成功态。无限量套餐只要已有成功查询时间即可进入后台查询，不再用 buckets 非空作为先决条件。

后台账号由 CarrierAccounts 的稳定 id 枚举，snapshot、connected、auth_required 和广电备份 session 均按账号隔离，第一张沿用旧键。第二张账号在创建空白 Headless WebView 后检查 MULTI_PROFILE 支持、设置专用 profile，之后才加载官网。profile 不可用时明确失败并保留旧值，不回退到第一张账号的默认会话。

后台发布桌面数据时传入完整 accounts 与 accountSnapshots，使用 schema 2 的独立实例列表，避免两张同运营商卡被旧 carrier 键合并。

## 验证与边界

根集成继续补上当前页面必须与响应 pageUrl 一致、Headless 超时后不再接收迟到回调、待清理标记暂停全部后台，以及账号 Widget 快照不从同运营商第二号码回填第一号码。另对照本机 Flutter SDK `dart:ui` 源码，移除新 FlutterEngine 的根 isolate 对 `DartPluginRegistrant.ensureInitialized` 的误调用；该 API 文档明确用于派生 isolate，Android FlutterEngine 已自动注册插件。单卡且从未创建独立 Profile 的安装在不支持 MULTI_PROFILE 时仍可完整清除；曾创建过独立会话则保留待清理保护。

新增 3 项 Flutter 定向测试通过，覆盖任务诊断桥接、未知结束状态不误报成功及后台间隔恢复；新增原生版本失效测试，应用模块 :app:testDebugUnitTest 编译并通过。完整集成验证和最终构建由根任务统一执行。

WorkManager 在省电、Doze、厂商限制或强行停止之后可能延迟或不执行，一小时/两小时/每天不是准点保证。运营商官网本身也可能延迟入账。电信仍依赖前台账务 DOM，不宣称支持后台读取。后台 WebView 的真实会话共享、独立 profile 在具体系统 WebView 版本上的运行和桌面宿主更新仍需真机验证；本次修复不构成 S25 Ultra 适配认证。

任务门禁检查与 Dart 偏好写入之间仍不是跨引擎原子事务，极短的前后台交接窗口需要真机竞态验证；如果后续仍发现旧快照覆盖，应把提交合并到原生主线程事务或增加持久化版本比较。本轮在查询返回和快照提交前均检查永久失效版本，未直接依赖 Flutter 插件私有的偏好底层格式。
