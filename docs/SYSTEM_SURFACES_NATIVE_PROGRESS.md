# Android 系统通知与快捷设置原生实现进展

2026-10-01。先查看 `docs/TECH_LOG.md` 与现有 `TrafficWidgetProvider`、`WidgetPresentation`、小组件测试，复用工作区已有 `references/system-surfaces/` 官方 Android 通知频道、通知权限与 Quick Settings 文档。这里没有另造运营商数据通道：小组件、常驻通知、快捷磁贴从同一份已校验的私有展示缓存读取，缓存最大四个账号，仅存展示字段。

`cn.liuliang/system_surfaces` 提供 `getStatus`、`setNotificationEnabled(bool)`、`setTileEnabled(bool)` 和 `requestAddTile`。状态返回通知偏好、TileService 组件开关、系统及频道通知可用性、API33 添加入口可用性。通知为普通低重要性通知，固定 ID 7312；关闭仅撤销该 ID，不影响低流量提醒。文案按账号展示缓存余额、原始查询时间和失败/过期/待验证状态，不读取或展示电话号码、网页登录信息。Android 13 的通知授权继续沿用既有 `cn.liuliang/notifications` 通道；系统或频道阻断时通知暂停投递但保留用户开关状态。

TileService 默认在 Manifest 禁用，开关开启时启用组件；启用不代表已经固定在快捷设置面板。API33 请求添加经系统确认，并把确认/取消/已添加/不可用结果回传，60 秒内兜底回传；API24–32 返回 `unsupported` 供界面说明手动编辑快捷设置。磁贴展示缓存状态，用户点击才用既有 `widget_refresh` Intent 打开首页并触发前台查询；Android 14 起使用 PendingIntent 版本的 `startActivityAndCollapse`。

新建 `SystemSurfacesTest` 覆盖缓存查询时间与失败状态、缺查询时间不虚构余额、账号标签不得泄露号码、通知偏好与系统阻断状态分离。待根任务统一运行 Gradle 原生测试与真机通知/磁贴验证。缓存时间是上次运营商查询时间，不代表系统面板实时余额；磁贴可否显示副标题及系统添加体验取决于设备与 Launcher。
