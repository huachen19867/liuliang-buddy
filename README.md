# 流量小伙伴

**安卓下载：**[下载正式版（28.04 MB）](https://github.com/huachen19867/liuliang-buddy/releases/download/v1.10.5/liuliang-buddy-release.apk)。适用 Android 7.0 及以上 ARM64 手机。iPhone 暂无可安装的签名包。

一个可自行选择运营商的流量查询应用。首次选择移动、联通、电信、广电，至少一家；每家直接选择一至四个号码，合计最多四张，各自在官网登录。额外号码需要系统 WebView 支持独立 Profile，不支持时明确阻止添加。设置可调整数量或收起卡片，保留备注、登录资料和历史本地记录。联通读取官网套餐余量，电信按官网已用/总量显示值估算并标「约」，均不混入已确认通用额度或提醒。首页采用奶油背景、圆润卡片与水滴插画，展示每个账号的余量、时间、状态和明细；官网明确标记不限量时结束加载并显示不限量，不生成零或无限 GB。

本机待发布版本 1.10.6+23（GitHub 网络连接失败，尚未上传）：电信名称含“定向”的归定向，其余归其他；同名子项合并估算，原始明细保留，旧缓存与桌面同步应用规则。[分类与合并说明](docs/RELEASE_1.10.6.md)。1.10.5：桌面组件补齐电信单项余量与缺项提示，收起无数据格子；通知、快捷设置和 iOS 源码同步单项标记。[桌面同步说明](docs/RELEASE_1.10.5.md)。1.10.4：电信部分流量读取显示项数和缺项；同名套餐折叠为组，逐项余量保留，空字段压缩，展开限制长度。[本次调整](docs/RELEASE_1.10.4.md)。1.10.3：补联通官网脚本延迟就绪的有限等待，保留明确不限量通话结果，查询超时结束加载并提示官网确认。未验证反馈中的双不限卡真实登录，不宣称该号码问题已经解决。[本次小修](docs/RELEASE_1.10.3.md)。1.10.2：在 APP 的套餐明细弹窗中选择自动识别、通用或定向，保存后自动同步首页、桌面卡片及已启用的通知栏余额。每个号码分别记住选择，刷新和重启保留，恢复自动可撤销；通用套餐仍保留编辑入口。汇总和同名套餐不手动分类，未知单位不制造数值。[分类说明与截图](docs/RELEASE_1.10.2.md)。此前版本：联通新增可选 App 查询试验，手动导入自己的 Cookie 或 token 会话后查询套餐和独立话费；不是一键登录，没有自动获取验证码。网页登录继续保留。已有 App 会话启动时刷新，并接入原有 Android 后台周期与桌面卡片。四家认证失效后暂停自动重试，后台复用前台页面判断，缓存异常不会生成负流量或错误低量提醒；用途不明的套餐标“用途未知”。完整范围见[联通接入与限制](docs/UNICOM_APP_QUERY_PROGRESS.md)。[GitHub 正式发布页](https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.10.5)只提供独立发布证书签名的 Release ARM64 主包。签名与安装说明见[安卓分发说明](docs/ANDROID_RELEASE.md)。通知栏余额和快捷设置入口默认关闭；通话短信不读取手机记录，字段边界见[通话短信研究](docs/VOICE_SMS_RESEARCH.md)。iOS 17 源码包含持久化多账号会话和 WidgetKit 工程，尚无签名的 iPhone 安装包。

没有 Mac 也可通过 [GitHub Actions](https://github.com/huachen19867/liuliang-buddy/actions/workflows/ios.yml)执行 macOS 编译、模拟器启动与截图。操作和签名说明见 [iOS 构建说明](docs/IOS_BUILD.md)，实现边界见 [会话隔离](docs/IOS_SESSIONS.md)与 [iOS 小组件](docs/IOS_WIDGET.md)。模拟器应用不适用于 iPhone；iOS 初版前台查询，组件展示最近结果，点击打开应用更新，设置不提供安卓后台周期选项。

[此前 iOS 云端验收](https://github.com/huachen19867/liuliang-buddy/actions/runs/36965455032)已通过 Flutter/Swift 检查、应用与组件编译、独立冷启动和界面流程。四张真实模拟器空账号截图见输出索引，不代表真实运营商余额或真机小组件验收，也不代表 1.10.6 已完成 iOS 云端验收。

主安装包路径为 artifacts/liuliang-buddy-release.apk，适用 Android 7.0 及以上 ARM64 手机。构建、测试、签名和哈希结果见 [1.10.6 版本说明](docs/RELEASE_1.10.6.md)。1.8.1 启动热修曾在荣耀真机通过；本轮尚未连接真机，官网余额、多账号 Profile 会话、S25 Ultra / One UI 添加弹窗及长期后台调度仍待设备验证，完整边界见 [后台刷新说明](docs/WIDGET_BACKGROUND_REFRESH.md)。

联通依据公开官网 E5 查询页自然发出的 userinfoE5query 响应，套餐余量单位 MB；不限量已用字段不当成剩余。电信当前天翼账号首页返回加密账务结果，应用读取首页已渲染的指定账务明细（含隐藏的官网明细弹窗），不复制其加解密代码、不自动点击或发送登录请求。每项按已用/总量的 MB/GB 显示值换算后估算差值；缺项、无单位、超额或无限哨兵不算合计。它有官网显示值舍入误差，共享/重叠额度以套餐规则为准。

运营商查询仍待真实账号验证：移动响应读取与解密已实现；广电官网的真实查询接口、业务字段和 KB 单位已从公开页面核对，使用官网自身解密后的结果。没有真实账号登录验证，不保证各省份或套餐均可读取。运营商没有在调研中提供可稳定依赖的公开余额 API，官网改版或会话失效会影响自动查询。

安卓版后台自动更新可关闭，或选择每小时、每两小时、每天尝试一次；设置还显示最近实际尝试时间和结果，Android 可能延迟任务。后台尝试移动、联通、广电各个已连接账号，电信仍需打开 APP。前台五分钟尝试查询，每个账号最多一轮进行中的请求，超时结束加载。低流量提醒仅使用成功查询的有限通用额度。未知单位不推算成通用 GB，不限量不触发低量提醒；没有数据时展示未连接，不使用示例余额。

点击“添加桌面卡片”后会说明是否已添加、等待系统确认或需要手动添加。没有系统弹窗时，长按桌面空白处，进入“小组件”，找到“流量小伙伴”拖到桌面。桌面支持最多四个账号，三、四张使用紧凑布局；组件过矮时显示隐藏张数，并提供点击刷新入口。目前没有 iOS 安装版；S25 Ultra 反馈、iOS 开发条件和各条用户反馈处理范围见 [反馈说明](docs/USER_FEEDBACK.md)，欢迎到 [GitHub Issues](https://github.com/huachen19867/liuliang-buddy/issues)提交设备与复现信息。

广电已同步但套餐用途不明确时，卡片主位显示“套餐明细合计”，只有全部明细的剩余额和单位都可确认才计算。这是各项余量的数学合计，用途以各套餐规则为准，不能代表全都可通用；不进入通用总览或低量提醒。首页和桌面使用同一摘要，明细可展开并点击查看完整名称。移动的“流量总览”可能包含分类，不纳入这个合计。

新版使用奶油白与青瓷绿的微缩温泉治愈风，角色只在页头和桌面卡片边缘陪衬。支持卡片备注与脱敏号码；无可确认数据时显示待确认。页面演示见[首次选择](artifacts/carrier-selection-four-demo.png)、[双移动卡](artifacts/dashboard-two-mobile-unlimited-demo.png)、[首页](artifacts/ui-preview.png)。素材来源见[素材索引](app/assets/resort/README.md)。

1.10.0 修复电信页面扫描不断推迟及提前回传漏收，联通官网会话检查改为异步并限时，网页工具栏明确显示“查询流量”。移动若只返回通话/短信，会说明尚未取得流量；移动独立话费来源仍未接入。本轮网页回归和真实账号验证范围见[查询兼容复核](docs/CARRIER_COMPATIBILITY_1.10.md)，不保证所有省份和套餐已可用。

三、四张卡演示：[数量选择](artifacts/carrier-count-four-demo.png)、[首页](artifacts/dashboard-four-accounts-demo.png)、[桌面四卡](artifacts/widget-four-preview.png)、[桌面三卡](artifacts/widget-three-preview.png)。首页是 Flutter 实际界面样本，桌面是读取原生 XML 的合成预览，均非真实账号或手机实拍。

本机正在验收 1.10.7：移动话费余额读取及 Android 桌面同步，并包含此前未公开的电信分类/合并修改。详见 [1.10.7 说明](docs/RELEASE_1.10.7.md)。

## 文件索引

| 位置 | 内容 |
| --- | --- |
| docs/RELEASE_1.10.7.md | 移动话费、两路结果合并与正式分发 |
| docs/MOBILE_BALANCE.md | 移动官网渲染余额读取与严格单位边界 |
| docs/MOBILE_BALANCE_SURFACES.md | Android 多卡紧凑余额展示 |
| app/lib/services/mobile_query_assembly.dart | 同一查询轮次的流量和余额合并 |
| scripts/test-mobile-balance-browser.cjs | 无账户、拦截网络的 Chrome 余额回归 |
| docs/RELEASE_1.10.6.md | 电信名称分类、同名合并估算与正式分发 |
| app/lib/data/telecom_name_classification.dart | 含定向/其余其他的共享名称规则 |
| docs/TELECOM_NAME_RULE_DATA.md | 旧缓存重算、手动优先、同名求和边界 |
| docs/TELECOM_NAME_RULE_UI.md | 电信其他显示、同名合并行与详情核对 |
| artifacts/telecom-directed-other-partial-preview.png | 电信定向与其他分类实际 Flutter 合成预览 |
| artifacts/widget-classified-2-preview.png | 桌面两卡定向/其他 XML 合成预览 |
| artifacts/widget-classified-3-preview.png | 桌面三卡定向/其他 XML 合成预览 |
| artifacts/widget-classified-4-preview.png | 桌面四卡定向/其他 XML 合成预览 |
| docs/RELEASE_1.10.5.md | 桌面电信单项余量、空框压缩与正式分发 |
| docs/WIDGET_PARTIAL_DATA.md | 双 schema 缓存、单项预览与用途/提醒边界 |
| docs/WIDGET_PARTIAL_IOS.md | WidgetKit 部分套餐与 Swift 验证边界 |
| artifacts/widget-partial-2-preview.png | 两卡部分余量真实 XML 合成预览 |
| artifacts/widget-partial-3-preview.png | 三卡部分余量真实 XML 合成预览 |
| artifacts/widget-partial-4-preview.png | 四卡部分余量真实 XML 合成预览 |
| docs/RELEASE_1.10.4.md | 电信部分同步、同名套餐折叠与正式分发 |
| docs/TELECOM_PARTIAL_UI.md | 电信首页压缩、逐项保留与布局验证 |
| artifacts/telecom-partial-preview.png | 电信多套餐实际 Flutter 合成预览 |
| docs/RELEASE_1.10.3.md | 联通脚本延迟就绪、不限量通话与验证边界 |
| docs/RELEASE_1.10.2.md | APP 手动套餐分类与卡片同步、正式分发和预览 |
| app/lib/data/traffic_classification.dart | 每账号用途覆盖、唯一套餐名匹配与自动恢复 |
| docs/TRAFFIC_CLASSIFICATION_DATA.md | 分类数据与单位保护契约 |
| docs/TRAFFIC_CLASSIFICATION_UI.md | 套餐弹窗、保存失败与大字布局 |
| docs/TRAFFIC_CLASSIFICATION_REVIEW.md | 前后台、通知及账号身份审查 |
| artifacts/traffic-classification-preview.png | 实际 Flutter 套餐分类弹窗合成预览 |
| docs/RELEASE_1.10.0.md | 三四卡、网页查询兼容与正式分发 |
| docs/MULTI_ACCOUNT_PROGRESS.md | 数量选择、保留历史及独立会话契约 |
| docs/MULTICARD_NATIVE_REVIEW.md | 原生紧凑组件与双平台身份门禁 |
| docs/CARRIER_COMPATIBILITY_1.10.md | 电信、移动、联通的当前证据和限制 |
| app/lib/main.dart | 生命周期、官方 WebView、会话、查询与提醒集成 |
| app/lib/data/carrier_accounts.dart | 稳定账号 ID、旧键迁移、每家四个账号与隐藏历史 |
| app/lib/services/background_refresh.dart | 周期选择与 WorkManager 设置通道 |
| app/lib/services/background_refresh_runner.dart | 后台 Flutter 引擎、无界面官网 WebView 与安全响应解析 |
| app/lib/services/ios_account_profiles.dart | iOS 独立持久化 WKWebView 仓库与清理通道 |
| app/ios/ | iOS 17 Runner、UIScene、App Group 权限与 WidgetKit 扩展 |
| app/ios/Shared/TrafficSnapshot.swift | 主应用和 WidgetKit 共用的白名单展示快照 |
| docs/IOS_BUILD.md | 没有 Mac 时的云端验证、模拟器产物与真机签名说明 |
| docs/RELEASE_1.6.0.md | iOS 源码预览的实现与交付范围 |
| app/integration_test/ios_smoke_test.dart | 真实 iOS 模拟器的首次选择、首页与平台指引验收 |
| app/test_driver/ios_smoke_driver.dart | 导出模拟器页面截图的测试驱动 |
| artifacts/ios-selection-simulator.png | iOS 云端实际首次选择页，无真实账号 |
| artifacts/ios-dashboard-simulator.png | iOS 云端实际未连接首页，无流量样本 |
| artifacts/ios-widget-guide-simulator.png | iOS 手动添加桌面小组件的指引 |
| artifacts/ios-settings-simulator.png | iOS 设置及后台能力说明 |
| docs/IOS_SESSIONS.md | iOS 持久化双账号、前台查询与清理保护 |
| docs/IOS_WIDGET.md | 小/中/大号组件、通知与手动添加的范围 |
| docs/IOS_FOUNDATION_PROGRESS.md | Xcode 工程接线与本地静态检查 |
| scripts/verify-ios.sh | macOS Flutter/Swift 验证、编译、模拟器安装与截图 |
| scripts/generate-ios-icons.cjs | 复用统一治愈风素材生成 Android/iOS 图标 |
| .github/workflows/ios.yml | GitHub macOS 构建、日志与模拟器产物 |
| .github/workflows/publish-ios-artifact.yml | 手动取回已成功验收的主分支产物并上传现有发布草稿 |
| .github/ISSUE_TEMPLATE/ios_bug_report.yml | iOS 编译、查询和组件反馈模板 |
| app/lib/ui/dashboard_screen.dart | 海滨温泉主题首页、每账号余额分类与状态操作 |
| app/lib/ui/carrier_selection_screen.dart | 海滨温泉主题的首次运营商选择与后续改选页面 |
| app/lib/ui/resort_theme.dart | 青瓷绿主题、参考角色小互动与票券组件 |
| docs/RELEASE_1.9.0.md | 新界面、账号身份、正式 APK 与验证边界 |
| docs/ACCOUNT_IDENTITY_PROGRESS.md | 备注、脱敏号码与分类余额 |
| docs/WIDGET_CLEAN_PROGRESS.md | 桌面卡片可选行、状态精简和玻璃质感 |
| docs/RELEASE_1.9.3.md | 桌面留白、官方网页兼容和联通查询候选 |
| docs/LOGIN_TOUCH_PROGRESS.md | 移动验证码触摸排查与键盘布局边界 |
| docs/UNICOM_QUERY_PROGRESS.md | 联通官网新旧初始化兼容及匿名验证 |
| docs/UNICOM_INTERNET_SOLUTIONS.md | 联通 App / 小程序开源方案、登录限制与接入方向 |
| docs/UNICOM_APP_QUERY_PROGRESS.md | 联通可选 App 查询、会话隔离、首页与后台接线 |
| docs/UNICOM_APP_PROTOCOL_REVIEW.md | 开源接口与认证可行性审查 |
| docs/UNICOM_APP_PARSER_PROGRESS.md | App 套餐解析、零值、不限量与余额边界 |
| docs/UNICOM_APP_SESSION_UI_PROGRESS.md | 高级会话导入页和键盘布局回归 |
| docs/PRODUCT_QUERY_REVIEW_1.10.1.md | 四家前后台、多卡状态与清除复核 |
| docs/PRODUCT_DATA_REVIEW_1.10.1.md | 四家单位、缓存异常及余额复核 |
| docs/RELEASE_1.10.1.md | 联通可选 App 通道及查询稳定性正式发布 |
| app/lib/data/unicom_app_parser.dart | 联通 App 套餐与独立话费的单位及错误边界 |
| artifacts/unicom-app-session-preview.png | 实际 Flutter 高级导入页的合成预览 |
| app/test/unicom_app_flow_test.dart | 双会话、认证失效保留旧值及修改号码的主流程回归 |
| app/lib/services/unicom_app_client.dart | 精确 App 请求、一次续期、完整号码与本机会话 |
| app/lib/ui/unicom_app_session_screen.dart | 联通 App 会话输入与逐号确认 |
| app/lib/ui/carrier_browser_shell.dart | 官方页窄屏工具栏、键盘与导航区布局 |
| app/lib/services/unicom_official_query.dart | 每文档一次官网原查询初始化 |
| docs/RELEASE_1.9.2.md | 四家官网原版Logo与正式包 |
| app/assets/carriers/README.md | 运营商原图来源与商标归属 |
| scripts/generate-carrier-assets.cjs | 从归档原图导出双端运营商标识 |
| docs/RELEASE_1.9.1.md | 桌面卡片精简正式包与验证边界 |
| scripts/preview-native-widget.cjs | 从实际安卓XML生成合成数据布局预览 |
| docs/WIDGET_RESORT_PROGRESS.md | 原生小组件布局和缩放 |
| scripts/generate-brand-assets.cjs | 统一素材导出双平台图标和安卓桌面贴纸 |
| docs/RESORT_UI_PROGRESS.md | 首页治愈风重做范围、数据展示约束与验证状态 |
| app/lib/data/carrier_selection.dart | 选择保存、旧版迁移及查询门禁 |
| docs/ONBOARDING_DESIGN.md | 选择流程、旧版迁移与本地记录行为 |
| docs/UNICOM_TELECOM_RESEARCH.md | 联通、电信入口及尚未接通的证据边界 |
| app/lib/data/ | 四家数据模型、移动/广电/联通响应解析与电信DOM估算 |
| docs/VOICE_SMS_RESEARCH.md | 四家通话短信字段、单位、公开证据与限制 |
| docs/VOICE_SMS_UI_PROGRESS.md | 每账号服务余量展示与组件截图验证 |
| docs/ANDROID_RELEASE.md | 发布签名、Release 构建与旧证书升级路径 |
| docs/RELEASE_1.8.0.md | 系统入口、正式分发及验证回执 |
| docs/SYSTEM_SURFACES_RESEARCH.md | 快捷设置、通知权限及官方示例证据 |
| docs/SYSTEM_SURFACES_NATIVE_PROGRESS.md | 原生缓存通知、磁贴与验证范围 |
| docs/SYSTEM_SURFACES_UI_PROGRESS.md | 设置开关及授权/取消/失败行为 |
| app/lib/ui/system_surfaces_settings.dart | 安卓即时保存的系统入口设置 |
| app/android/app/src/main/kotlin/cn/liuliang/liuliang_app/SystemSurfaces.kt | 缓存通知与 TileService |
| artifacts/android-system-surfaces-settings-demo.png | 设置组件演示，非系统面板实拍 |
| docs/RELEASE_1.7.0.md | 通话短信新增功能与本轮交付验证 |
| artifacts/dashboard-voice-sms-demo.png | 通话短信首页真实组件渲染，明确演示数据 |
| app/lib/data/traffic_summary.dart | 首页与桌面共享的通用余额/广电套餐明细摘要 |
| app/lib/services/page_probe.dart | 限定接口的响应观察、移动解码与广电会话脚本 |
| app/lib/services/response_policy.dart | 广电明文成功结果回退与迟到原始响应门禁 |
| app/lib/services/carrier_web.dart | 四家登录/查询入口与响应页面门禁 |
| app/lib/services/refresh_throttle.dart | 按账号限制重复刷新，登录返回和加载失败可立即重试 |
| app/lib/services/query_state.dart | 配置切换取消查询后结束旧加载状态，保留原余额和时间 |
| app/lib/services/telecom_page_probe.dart | 当前电信官网已渲染套餐明细读取，不采集登录数据 |
| app/lib/services/widget_bridge.dart | 桌面展示数据与原生通信 |
| app/lib/ui/widget_preview_card.dart | 添加桌面卡片入口与样式示意 |
| app/android/ | 安卓入口、权限、通知、自绘启动图标与原生桌面卡片 |
| app/android/app/src/main/kotlin/cn/liuliang/liuliang_app/BackgroundRefreshWorker.kt | WorkManager 周期任务与后台小组件缓存更新 |
| app/test/ | 数据、探针及 UI 验证 |
| app/vendor/README.md | WebView 安卓依赖的 AGP 9 兼容补丁 |
| artifacts/ui-preview.png | 可视预览，使用显著标注的演示样本 |
| artifacts/broadnet-summary-preview.png | 广电套餐明细摘要预览，使用演示样本 |
| artifacts/liuliang-buddy-release.apk | 独立发布证书签名的 Release 主安装包 |
| artifacts/README.md | 输出版本、哈希、构建记录与签名检查索引 |
| scripts/build-android.ps1 | 构建唯一的正式签名 Release 安装包 |
| scripts/test-broadnet-browser.cjs | Chrome 公开官网脚本与本地合成响应的桥接回归验证 |
| docs/TECH_LOG.md | 需求、阶段进展、踩坑与复用方法 |
| docs/PROTOCOL_RESEARCH.md | 官方协议证据与未验证范围 |
| docs/DATA_NOTES.md | 余额类型、单位和解析约束 |
| docs/PRIVACY.md | 本地存储、登录与清除数据行为 |
| docs/THIRD_PARTY_NOTICES.md | 上游参考声明 |
| docs/WIDGET_RESEARCH.md | Android AppWidget 官方参考、支持范围与实施边界 |
| docs/WIDGET_BACKGROUND_REFRESH.md | 后台自动刷新架构、四家支持边界与真机验证项 |
| docs/REFRESH_RELIABILITY_REVIEW.md | 任务取消、超时、最近实际状态和多账号后台复核 |
| docs/MULTI_ACCOUNT_REVIEW.md | 独立 WebView Profile、两张同运营商卡与前台查询门禁 |
| docs/WIDGET_COMPATIBILITY_REVIEW.md | 系统添加回执、无弹窗手动入口、尺寸与多账号桌面 |
| docs/USER_FEEDBACK.md | 用户反馈、S25 Ultra 验证条件和 iOS 支持范围 |
| docs/UNICOM_REFRESH_PROGRESS.md | 联通登录返回、旧查询状态与响应页面门禁修复 |
| docs/MOBILE_FACE_LOGIN_RESEARCH.md | 移动特殊卡人脸登录的官方入口与支持边界 |
| .github/ISSUE_TEMPLATE/bug_report.yml | 设备、WebView、运营商与复现信息反馈模板 |
| docs/RELEASE_1.1.0.md | 版本说明、验证与安装包哈希 |
| docs/RELEASE_1.1.1.md | 广电查询修复、验证与安装包哈希 |
| docs/RELEASE_1.3.0.md | 四家选择、联通读取、电信估算和公开测试发布 |
| docs/RELEASE_1.4.0.md | 后台刷新测试发布与安装包信息 |
| docs/RELEASE_1.5.0.md | 用户反馈修复、多账号测试发布与安装包信息 |
| scripts/test-telecom-rendered-browser.cjs | Chrome全本地合成官方结构DOM读取验证 |
| artifacts/carrier-selection-four-demo.png | 四家运营商首次选择DEMO截图 |
| artifacts/dashboard-unicom-broadnet-demo.png | 联通与广电组合DEMO截图 |
| artifacts/dashboard-telecom-demo.png | 电信估算余量DEMO截图 |
| artifacts/carrier-settings-four-demo.png | 四家运营商管理DEMO截图 |
| artifacts/dashboard-two-mobile-unlimited-demo.png | 两张移动账号分别展示有限余量与不限量的DEMO截图 |
| docs/RELEASE_1.2.0.md | 首次选择、单卡适配与公开测试发布 |
| artifacts/carrier-selection-demo.png | 首次运营商选择DEMO截图 |
| artifacts/dashboard-single-demo.png | 移动单卡首页DEMO截图 |
| artifacts/dashboard-multiple-demo.png | 移动/广电组合首页DEMO截图 |
| artifacts/carrier-settings-demo.png | 运营商设置DEMO截图 |
| docs/RELEASE_1.1.2.md | 广电摘要显示修正、验证与安装包哈希 |
| references/README.md | 下载的参考项目和公开页面索引 |
| .tools/ | 本工作区构建依赖与缓存，不属于应用业务源码 |

## 开发与验证

需要 Flutter 3.44.8 / Dart 3.12.2，以及 Android SDK、JDK 17 和 CMake 3.22.1。工作区已准备本地工具，没有修改系统全局配置。移动页面流量传输依赖 encrypt，官网 WebView 使用 flutter_inappwebview，会话备份使用 flutter_secure_storage，查询记录与设置使用 shared_preferences；包版本固定于 app/pubspec.lock。

在 app/ 运行：

```powershell
$env:PUB_CACHE = (Resolve-Path ../.tools/pub-cache).Path
D:\AI\tools\flutter\bin\flutter.bat pub get
D:\AI\tools\flutter\bin\flutter.bat analyze
D:\AI\tools\flutter\bin\flutter.bat test
node test/services/page_probe_js_test.cjs
```

使用标准 Android 环境并注入自己的私有签名后，在 app/ 执行 `flutter build apk --release --target-platform android-arm64`。本工作区根目录可运行 `./scripts/build-android.ps1 -Mode Release`，外部环境签名变量与迁移说明见 [ANDROID_RELEASE.md](docs/ANDROID_RELEASE.md)。缺签名会拒绝 Release，私钥和密码不在公开仓库中；需要镜像时加 `-UseMirrors`，临时wrapper与镜像配置会恢复。

广电公开页面回归验证在根目录执行 `node scripts/test-broadnet-browser.cjs`，再加 `--delayed-bridge` 验证桥接延迟。需要已安装 Chrome 与 Playwright；本工作区复用 .tools/browser/node_modules/playwright，其他环境可通过 LIULIANG_PLAYWRIGHT_MODULE 指定该包路径，通过 LIULIANG_CHROME_PATH 指定浏览器路径。请求由本地 route 拦截，响应为合成数据，不使用账号、不发送验证码。该检查需要官网可访问，官网 bundle 改版也可能使其失败。

## 界面演示

在 app/ 执行 `flutter run -d chrome --dart-define=DEMO=true` 或 `flutter build web --dart-define=DEMO=true` 可看可交互的界面演示。它不查询个人账号，不写入运营商会话；顶部固定显示“界面演示 · 非真实流量”。安卓测试包不设置此参数。

## 真实手机验证

首次安装后分别点击两张卡的连接入口，在各自官方网页输入号码并完成短信验证，然后点击“查询流量”。关闭官方页面回到首页时，只有解析出真实响应才会显示余额。若官网拒绝 WebView、字段变化或无法识别结果，页面给出失败状态，仍可在同一入口查看官方查询页。真机验证时请比较两张卡各自官方显示的额度、分类与查询时间，不将演示图作为准确性证据。

尚需确认真实登录、当前移动传输密钥、各地套餐差异、会话寿命、安卓 WebView 脚本时机与通知行为。

安卓桌面小组件现已加入：在 APP 中点击“添加桌面卡片”，接受系统桌面确认；不支持直接固定的桌面可以长按空白处手工添加。卡片显示最近查询的两卡余量、查询时间及状态，点击卡片打开 APP 更新。API 24 及以上支持系统小组件，直接申请固定从 API 26 起且取决于桌面支持情况。APP 关闭后的后台持续查询尚未实现。

## GitHub 上传范围

源码、测试、说明、经过必要兼容修改的依赖源码与界面演示图进入仓库。测试 APK 通过 GitHub Release 分发，不提交到 Git 历史。构建工具、SDK、Pub 缓存、未修改的参考源码、构建输出和个人会话数据不上传。
