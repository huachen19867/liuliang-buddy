# 双卡桌面小组件调研

桌面卡片针对 One UI 添加回执、Launcher 退路、尺寸和多账户 schema 的实现复核见 [`WIDGET_COMPATIBILITY_REVIEW.md`](WIDGET_COMPATIBILITY_REVIEW.md)。下文“建议契约”是最初调研时的 schema 1 草案；实现现兼容 schema 1，并由复核说明 schema 2。

2026-09-30。已定位 `docs/TECH_LOG.md` 并核对现状：Flutter 首页已有两运营商查询状态、通用流量与查询时间；安卓 Kotlin MainActivity 已使用 MethodChannel。当前查询是前台 WebView 行为，APP 关闭后不会持续查询。因此小组件展示最近结果，并明确显示其时间和状态；点击进入 APP 再由既有逻辑查询，不把桌面缓存称为实时数据。

## 官方参考与支持范围

已下载 Google 官方 `android/user-interface-samples` 的 AppWidget 相关精选源文件至 `references/android-widget/`，许可证 Apache-2.0，下载文件与来源见该目录 README。上游定位版本 `2c0b04e9092410a14381b86c168034a52243b85b`。`WeatherForecastAppWidget.kt` 明确继承 AppWidgetProvider，在 onUpdate 中创建 RemoteViews 并 updateAppWidget；其 provider XML 声明 `resizeMode="horizontal|vertical"`。这正适合圆角大数字天气卡式双卡摘要，无需让 Flutter UI 进程常驻，也无需增加 Compose/Glance 依赖。

Android 标准 AppWidget 与荣耀、华为、小米或其他厂商专属卡片不是同一机制。本项目使用标准 AppWidgetProvider/RemoteViews，不依赖荣耀 Launcher 的私有接口。宿主 Launcher 必须支持 Android AppWidget；不能保证每种桌面的尺寸、字体缩放或圆角裁切完全一致。

当前最低 API 24 可以通过桌面长按、小组件列表手动添加。`AppWidgetManager.requestPinAppWidget` 和 `isRequestPinAppWidgetSupported` 自 API 26 提供；必须同时判断系统版本与 Launcher 支持。官方样例 MainActivity 第 79 行检查支持，第 111 行发起请求；样例注释明确某些 Launcher 的成功回调不可靠，取消不会回调。返回 true 仅代表请求已受理，不证明用户已添加。API 24/25 或不支持 pin 的 Launcher 显示手动添加说明，不应请求无关权限或伪称已添加。

官方 API 链接：https://developer.android.com/reference/android/appwidget/AppWidgetManager#requestPinAppWidget(android.content.ComponentName,android.os.Bundle,android.app.PendingIntent) 。整体指南：https://developer.android.com/develop/ui/views/appwidgets 。RemoteViews 仅支持有限的传统 View，因此选 FrameLayout/LinearLayout/TextView/ImageView 和 drawable shape；不要把 Flutter Widget、任意自定义 View 或完整 Activity 布局直接交给 Launcher。

## 建议契约

采用独立 `MethodChannel('cn.liuliang/widgets')`，避免与已有通知权限 channel 混淆。Flutter 的 `updateSnapshot` 发送一个全量对象，原生校验后原子写入 `context.getSharedPreferences("flow_widget", MODE_PRIVATE)` 的单个 JSON 值，再查询 provider 全部 appWidgetIds 并更新；不要直接读取 Flutter shared_preferences 内部命名或文件布局。建议 payload 为以下形态，具体命名可随实施统一：

```json
{
  "schemaVersion": 1,
  "updatedAtEpochMs": 1790748649321,
  "cards": [
    {
      "carrier": "mobile",
      "status": "success",
      "remainingBytes": 25340307046,
      "queriedAtEpochMs": 1790748649321
    },
    {
      "carrier": "broadnet",
      "status": "authExpired",
      "remainingBytes": null,
      "queriedAtEpochMs": null
    }
  ]
}
```

`remainingBytes` 只取模型已经确认的通用剩余量，不重新聚合定向或用途未知额度。缺数据用 null，显示“待查询”或“待验证”，不转换为 0 GB。若保留上一成功数值而最新状态失败，必须清楚标注“上次”并使用原成功 queriedAt，不刷新成当前时间。`updatedAtEpochMs` 是缓存写入时间，不能冒充 queriedAt。保留每张卡独立时间，不能把一张成功的时间套到另一张。

`clearSnapshot` 删除这一原生缓存并立即重绘全部实例为空状态。Flutter 清除账号数据时必须纳入同一世代/串行写保护，避免旧异步查询在清除后再次写入小组件。添加请求应返回 `already_added`、`request_pending_confirmation` 或 `unsupported` 等明确状态；系统接受请求并不代表用户已添加。实际状态契约、15 分钟等待回执与手动添加说明见兼容性复核。不向原生小组件传手机号原文、cookie、Session、Access 或 WebView 凭证；桌面可见数据仅为额度、账户显示名、运营商品牌和状态时间。

## 原生生命周期与交互

Manifest 注册非导出 `AppWidgetProvider` receiver，监听 APPWIDGET_UPDATE，并以 metadata 指向 provider XML；Google 样例的天气 receiver 使用 `android:exported="false"`。provider 建议 `updatePeriodMillis="0"`，不复制天气样例每天一次的定时周期。此值禁止系统定期 onUpdate，但初次添加、APP主动推送、系统要求重建等事件仍可调用缓存渲染；APP进程被杀后 Launcher 可继续显示已提交的 RemoteViews，后续 provider 被启动时从原生缓存重建。

点击整张卡用显式 `Intent(context, MainActivity::class.java)` 创建 `PendingIntent.getActivity`，标志 `FLAG_UPDATE_CURRENT | FLAG_IMMUTABLE`，RemoteViews.setOnClickPendingIntent 绑定根容器。以 Activity PendingIntent 直接打开 APP，避免先走广播再启动 Activity 的后台限制；无需对 WebView 或运营商发出后台查询。可添加 NEW_TASK/CLEAR_TOP/SINGLE_TOP 以配合现有启动模式，具体与现有 Manifest 统一。

provider XML 使用 `resizeMode="horizontal|vertical"` 与适当 minWidth/minHeight/minResizeWidth/minResizeHeight。API 31 的 targetCellWidth/targetCellHeight、maxResizeWidth/maxResizeHeight 可作为新桌面提示，旧版本使用 dp 最小尺寸。固定两列大数字时至少测试横向 2x2/4x2 与纵向拉伸；onAppWidgetOptionsChanged 可以按可用 dp 宽度选择紧凑布局或字体，不能只声明可缩放而让文字裁切。圆角 drawable 可作旧版本背景，Android 12+宿主可能施加自己的裁切，根背景与内容留边应能容忍此差异。

## 验证与边界

本调研已核对并下载官方源代码、许可证及元数据，但没有连接手机，尚未验证荣耀或其他 Launcher 的添加、缩放、重启恢复与点击体验。实施后可先编译验证Manifest/XML/Kotlin，再用原生缓存模拟未连接、成功、失效、超长时间和大数值绘制；模拟数据必须与真实账号交付分开。真机最终检查手工添加、支持时 pin 请求、取消 pin、点击打开、双卡独立更新时间、清除数据立即清空及 APP被杀后的缓存显示。

用户同时授权上传 GitHub，仓库 owner 与 release 可见性由根代理确认实际账户后处理；未明确公开时采用私有仓库，发布文件不得包含会话、浏览器快照用户凭证、签名私钥或本地工具缓存。此调研本身不创建仓库或发布。
