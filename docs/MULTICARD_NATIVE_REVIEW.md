# 三、四张卡原生与会话检查

2026-10-02。先读 TECH_LOG.md 当前 1.9.3 回执，复用 WIDGET_RESEARCH.md 引用的已下载 Google AppWidget/RemoteViews 指南；本轮只读审查，不运行 SDK、不改产品源码。

## 必须扩展的身份门禁

Android `TrafficWidgetProvider.kt` 的 `WidgetAccountSelection` 解析在第 112 行只接受 carrier 与 carrier_2，会丢弃第三、第四同运营商号码。应精确允许同一 carrier 的 primary、_2、_3、_4，继续拒绝跨运营商 ID、_1、_5、重复及未知运营商，并保留总数四张的上限。`SystemSurfaces.kt` 第 32 行只识别 _2 编号，应采用已验证的后缀或 accountLabel，避免三、四卡在通知中同名。

Android vendor `WebViewChannelDelegate.java` 第 84 行 setAccountProfile 与 `WebViewFeatureManager.java` 第 43 行 deleteAccountProfiles 都固定正则 liuliang_[a-z]+_2。两处必须同步扩到后缀 [234]，建议同时限定 mobile|broadnet|unicom|telecom。只改设置、不改清理会遗留三四号网页登录会话；只改清理、不改设置会令新卡失败。不同卡需不同 profile，不能共用 _2。

iOS `Shared/TrafficSnapshot.swift` 第 55 行只接受 primary/_2，需要同样扩至 _4，保留 parse 最多四条规则。vendor `InAppWebView/LiuliangAccountDataStore.swift` 的 identifiers 只有四家 _2 的固定 UUID，需要为四家 _3/_4 添加八个固定、不同的新 UUID，必须保持原四个 UUID 不变。clearAll 遍历整份 identifiers，因此扩表可覆盖新旧隐藏账号；不能每次生成随机 UUID，否则重启丢登录、无法完整清理。

`services/ios_account_profiles.dart` 只传 profileName，`background_refresh_runner.dart` 第 245 行按 account.profileName 设置隔离仓库，并无独立 _2 字面量。本次检索 services 未发现额外固定 _2 门禁；其正确性仍依赖账号模型为每张卡生成唯一、稳定 profileName，以及前后台都传该值。Flutter 数据/UI 层的容量与持久化另由负责代理修改，不应只扩原生展示。

## Android 280dp 四张显示

当前 `WidgetAccountDetails.kt/WidgetAccountLayout.visibleCount` 计算 `(height - 68) / 106`；280dp 只得到 2。`res/layout/traffic_widget.xml` 虽有四个 slot，但每个固定 100dp 高并有 6dp 底边距，`TrafficWidgetProvider.createViews` 根据 visibleCount 隐藏后续 slot，并显示 widget_more “另 N 张”。所以只把 visibleCount 返回值改四会导致超出宿主裁切，不能满足要求。

建议保留现有一、二卡详细版，三、四卡采用独立紧凑 RemoteViews XML 和相同字段 ID。四张纵向紧凑卡比两列更容易容纳中文名称与四类明细。默认 280dp 可按外边距上下合计 16dp、标题 28dp、四卡各 56dp、卡间三条 4dp 精确预算，合计 280dp；每卡约四行：运营商标识/备注/号码尾号，话费和状态/原查询时间，通用及定向，其他及通话。该尺寸只是排版候选，9–10sp 字体需要实图核对，不可为容纳字段把缺失额度伪装 0，也不可省略旧缓存状态。

三卡可用约 74dp 行高，同样保持完整卡数；足够高的宿主继续使用 100dp 详细布局。以 `onAppWidgetOptionsChanged` 的高度选布局，沿用 FrameLayout 透明宿主加内层 wrap_content 背景，避免重新引入双卡底部多余底色。大字体、窄宽度与 launcher 系统内边距需额外实测；字号放大后默认 280dp 不一定容得下全部信息，应采用实际可用宽高响应式布局或明确要求用户拉高，而不能声称任何字号都完整显示。

RemoteViews 支持的 LinearLayout/TextView/ImageView 已足够实现紧凑卡，不需要 Flutter 视图或新依赖。无需改 total=4 的存储上限。建议验证同运营商四卡、跨运营商三卡、备注长文本、缺字段、过期缓存、280dp 和扩高布局，以及大字体时不裁切/串号。iOS Widget 当前 small/medium/large 分别限制 1/2/4，是独立 family 设计；扩 ID 不会自动让 medium 显示四张，需要另做紧凑版，不能将 Android 完成当作 iOS 四卡所有尺寸完成。

本轮没有生成截图或运行原生测试；以上为源码与现有布局的可核对分析。

## 身份与隔离实施

随后按根代理分工实施身份层：Android WidgetInstances 与 iOS TrafficAccountSnapshot 接受同家 primary/_2/_3/_4，跳过显式 enabled=false，兼容缺失 enabled 的历史记录；四条上限保持。Android 通知支持 2/3/4 编号。Android vendor 设置与清理均使用严格 `liuliang_(mobile|broadnet|unicom|telecom)_[2-4]`，避免三四卡创建后无法清除。iOS 增加八个源码固定 UUID，原四个 _2 UUID 原样保留，clearAll 自动覆盖全十二个专用仓库。

补充 Android 测试覆盖四张同运营商、非法 _1/_5、跨运营商 ID、禁用记录不抢占后续同 ID 有效记录和通知 3/4 编号；Swift 模型检查补充同类场景。git diff --check 无错误，只有工作区换行符提示。按任务约束未运行 SDK，测试执行交由根代理；没有改 WidgetAccountLayout、createViews、bindCard 或布局 XML，这些由根代理集成。

根集成采用三/四卡独立 traffic_widget_compact.xml，50dp行+4dp下边距，36dp标题+16dp上下壳边距，四卡共268dp。仅compactDetail展示一行附加信息：异常状态与唯一套餐合计优先，其次已确认话费，最后脱敏号码；查询时间单独保留。默认280dp不再遗漏后两张，180dp保留完整两行与遗漏提示。这里未宣称任意大字号/窄宽或真实Launcher已验收，Android节点和profile测试由根统一运行。iOS small/medium/large 原1/2/4 family保持，新增账户ID支持不等于中号四卡展示。
