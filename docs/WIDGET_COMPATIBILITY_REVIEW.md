# 桌面卡片添加与 One UI 兼容性复核

2026-10-01。复用已下载的 Google `android/user-interface-samples` AppWidget 参考（`references/android-widget/`），并对照 Android `AppWidgetManager.requestPinAppWidget` 约定与当前桌面卡片实现。此复核针对老板反馈的“添加不好使”，重点校正系统 pin 请求回执、Launcher 手动添加指引、尺寸约束和多账号展示契约。

## 添加回执

`requestPinAppWidget()` 返回 `true` 代表 Launcher 接受了 pin 请求，不能证明用户已经确认或桌面实例已经创建。Flutter 现在通过 `requestPinDetailed()` 取得 `WidgetPinResult`；旧的 `requestPin()` 保留为布尔便利方法，`true` 仅表示请求仍等待确认。`installationStatus()` 查询真实安装状态。原生接口返回以下状态：

| 状态 | 含义 |
| --- | --- |
| `already_added` | Provider 查询到桌面实例，或收到 Launcher 的成功回调 |
| `request_pending_confirmation` | 请求已受理，仍需用户在 Launcher 确认；这不是添加成功 |
| `unsupported` | 系统低于 API 26、Launcher 不支持快捷固定，或 Launcher 拒绝请求；`reason` 会说明可识别原因 |
| `not_added` | 查询状态时尚未添加且没有等待中的 pin 请求；Launcher 支持快捷固定 |

系统成功回调使用显式、不可变、非导出的 BroadcastReceiver，并关联一次性请求 token。Launcher 取消 pin 时通常不会回调；未完成的等待状态在 15 分钟后过期。查询是否已添加优先读取 `AppWidgetManager` 的实例 ID。这样可以在进程重启后继续区分等待确认和已添加状态。

每次请求后，应用应明确显示系统仍待确认，并同时给出手动入口：长按桌面空白处，打开“小组件/窗口小工具”，找到“流量小伙伴”，拖到桌面。Android 7 / API 24–25 不提供 pin API，但仍可从 Launcher 手动添加。Launcher 不支持固定或没有展示系统确认时，结果标为 `unsupported` 并显示同一手动指引。

## 尺寸与刷新入口

Provider 仍允许横向、纵向缩放，删除了强制 4×4 网格提示。声明的最小尺寸从 260×210dp 调整到 210×180dp，可缩到 180×150dp。该尺寸降低 Launcher 放置门槛，四运营商组合仍保留足够的双行内容空间。实际网格跨度由桌面宿主决定，不能用 XML 尺寸推断 One UI 的最终外观。

卡片标题的“点我刷新”现在绑定真实 `PendingIntent`；卡片根区域也保留点击入口。两处都会打开应用并触发当前所选账户的前台查询，成功或失败结果通过现有快照同步回桌面。桌面本身不访问运营商，也不承诺实时账单。

## 多账号和显示数据

Widget payload 支持 schema 1（按运营商的旧字段）和 schema 2。schema 2 的 `instances` 每条仅携带 `accountId`、运营商、`accountLabel`、状态、主数值及标签、原始查询时间和不限量标记；不含手机号、凭证或网页响应。全局最多四个账户、同一家最多两个，每个账户独占一个现有桌面槽位，所以同一运营商的两张账户会显示为两个条目。旧按 `mobile` / `broadnet` 等运营商键保存的快照仍能读取。

有限的已确认主数值优先显示。只有存在有效的成功查询时间且没有有限主数值时，原生卡片才显示“不限量”；刷新中、失效或查询失败时保留上次不限量标记与原始时间，同时显示当前状态，也不会触发低流量提示。首次查询没有时间时不显示不限量。查询失败不会把一次失败伪装成新成功。

## 验证边界

2026-10-01 的针对性 Flutter 测试通过：`widget_bridge_test.dart` 与 `widget_preview_card_test.dart` 共 11 项，覆盖 schema 2 同运营商双账户各占一槽、隐私字段排除、不限量缓存门槛、pin 状态区分和桌面手动添加指引。`flutter analyze` 对 bridge、预览卡和 bridge 测试文件无问题。Android `:app:testDebugUnitTest --tests cn.liuliang.liuliang_app.WidgetPresentationTest` 通过，覆盖 12 项原生展示、最多四账户槽位和 pin 状态规则。没有执行整套应用测试或 S25 真机测试。

本环境没有连接 Samsung Galaxy S25 Ultra，也没有 One UI Launcher。因此不能确认该机的系统弹窗时序、桌面手势路径、最小网格跨度或缩放裁切；本变更提供 Android 标准接口回执和手动退路，不代表 S25 真机验证。Google 官方示例特别指出 Launcher 的 pin 成功回调可能不可靠，而且用户取消时不回调，这条限制继续适用。
