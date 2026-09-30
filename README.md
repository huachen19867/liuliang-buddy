# 流量小伙伴

一个可自行选择运营商的安卓流量查询测试应用。首次使用选择至少一家，当前支持移动单卡、广电单卡或移动与广电组合；设置中可随时改选。联通、电信仍在协议研究阶段，暂不开放余额读取。首页采用奶油背景、圆润双色卡片与笑脸水滴，展示每张卡的剩余流量、查询时间、连接状态，以及通用和定向额度。号码验证由用户在运营商官方网页完成，成功会话尽量复用。

当前版本 1.2.0+5，已公开发布：[GitHub 仓库](https://github.com/huachen19867/liuliang-buddy) · [安装包发布页](https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.2.0)。原有私有仓库和历史发布保留。

已生成的安装包：artifacts/liuliang-buddy-debug.apk（约 108.6 MiB，Android 7.0 及以上 ARM64 手机）。APK 构建和 v2 签名检查通过，flutter analyze 无问题，54 项 Flutter 测试、7 项原生卡片测试及网页探针 Node 验证通过。广电监听修复还通过真实公开官网配合本地合成响应的 Chrome 验证；已收到用户真机双卡同步截图，官方余额对照与新版显示仍需实际手机核对。

当前为待真机验证的测试版：移动响应读取与解密已实现；广电官网的真实查询接口、业务字段和 KB 单位已从公开页面核对，使用官网自身解密后的结果。没有真实账号登录验证，不保证各省份或套餐均可读取。运营商没有在调研中提供可稳定依赖的公开余额 API，官网改版或会话失效会影响自动查询。

自动更新发生在打开 APP、回到前台和 APP 前台运行每五分钟；关闭 APP 后不会持续监测。低流量提醒仅使用成功查询的通用额度。未知用途或单位不推算成通用 GB，总览不会把定向流量混进去；没有数据时展示未连接，不使用示例余额。

广电已同步但套餐用途不明确时，卡片主位显示“套餐明细合计”，只有全部明细的剩余额和单位都可确认才计算。这是各项余量的数学合计，用途以各套餐规则为准，不能代表全都可通用；不进入通用总览或低量提醒。首页和桌面使用同一摘要，明细可展开并点击查看完整名称。移动的“流量总览”可能包含分类，不纳入这个合计。

## 文件索引

| 位置 | 内容 |
| --- | --- |
| app/lib/main.dart | 生命周期、官方 WebView、会话、查询与提醒集成 |
| app/lib/ui/dashboard_screen.dart | 按所选运营商展示的可爱首页与各种连接状态 |
| app/lib/ui/carrier_selection_screen.dart | 首次运营商选择与后续改选页面 |
| app/lib/data/carrier_selection.dart | 选择保存、旧版迁移及查询门禁 |
| docs/ONBOARDING_DESIGN.md | 选择流程、旧版迁移与本地记录行为 |
| docs/UNICOM_TELECOM_RESEARCH.md | 联通、电信入口及尚未接通的证据边界 |
| app/lib/data/ | 数据模型及移动、广电响应解析 |
| app/lib/data/traffic_summary.dart | 首页与桌面共享的通用余额/广电套餐明细摘要 |
| app/lib/services/page_probe.dart | 限定接口的响应观察、移动解码与广电会话脚本 |
| app/lib/services/response_policy.dart | 广电明文成功结果回退与迟到原始响应门禁 |
| app/lib/services/widget_bridge.dart | 桌面展示数据与原生通信 |
| app/lib/ui/widget_preview_card.dart | 添加桌面卡片入口与样式示意 |
| app/android/ | 安卓入口、权限、通知、自绘启动图标与原生桌面卡片 |
| app/test/ | 数据、探针及 UI 验证 |
| app/vendor/README.md | WebView 安卓依赖的 AGP 9 兼容补丁 |
| artifacts/ui-preview.png | 可视预览，使用显著标注的演示样本 |
| artifacts/broadnet-summary-preview.png | 广电套餐明细摘要预览，使用演示样本 |
| artifacts/liuliang-buddy-debug.apk | 已验证签名的个人测试安装包 |
| artifacts/README.md | 输出版本、哈希、构建记录与签名检查索引 |
| scripts/build-android.ps1 | 使用本工作区工具生成 ARM64 安卓调试包 |
| scripts/test-broadnet-browser.cjs | Chrome 公开官网脚本与本地合成响应的桥接回归验证 |
| docs/TECH_LOG.md | 需求、阶段进展、踩坑与复用方法 |
| docs/PROTOCOL_RESEARCH.md | 官方协议证据与未验证范围 |
| docs/DATA_NOTES.md | 余额类型、单位和解析约束 |
| docs/PRIVACY.md | 本地存储、登录与清除数据行为 |
| docs/THIRD_PARTY_NOTICES.md | 上游参考声明 |
| docs/WIDGET_RESEARCH.md | Android AppWidget 官方参考、支持范围与实施边界 |
| docs/RELEASE_1.1.0.md | 版本说明、验证与安装包哈希 |
| docs/RELEASE_1.1.1.md | 广电查询修复、验证与安装包哈希 |
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

使用标准 Android 环境在 app/ 执行 `flutter build apk --debug --target-platform android-arm64`。本机 Gradle 官方下载与部分插件仓库的 TLS 连接曾失败，可在工作区根目录运行 `./scripts/build-android.ps1 -UseMirrors`；它使用本地经过官方 SHA-256 核验的 Gradle 9.1.0 与仅本次构建生效的依赖镜像。调试包属于个人测试用途，没有商业发行签名。

广电公开页面回归验证在根目录执行 `node scripts/test-broadnet-browser.cjs`，再加 `--delayed-bridge` 验证桥接延迟。需要已安装 Chrome 与 Playwright；本工作区复用 .tools/browser/node_modules/playwright，其他环境可通过 LIULIANG_PLAYWRIGHT_MODULE 指定该包路径，通过 LIULIANG_CHROME_PATH 指定浏览器路径。请求由本地 route 拦截，响应为合成数据，不使用账号、不发送验证码。该检查需要官网可访问，官网 bundle 改版也可能使其失败。

## 界面演示

在 app/ 执行 `flutter run -d chrome --dart-define=DEMO=true` 或 `flutter build web --dart-define=DEMO=true` 可看可交互的界面演示。它不查询个人账号，不写入运营商会话；顶部固定显示“界面演示 · 非真实流量”。安卓测试包不设置此参数。

## 真实手机验证

首次安装后分别点击两张卡的连接入口，在各自官方网页输入号码并完成短信验证，然后点击“查询流量”。关闭官方页面回到首页时，只有解析出真实响应才会显示余额。若官网拒绝 WebView、字段变化或无法识别结果，页面给出失败状态，仍可在同一入口查看官方查询页。真机验证时请比较两张卡各自官方显示的额度、分类与查询时间，不将演示图作为准确性证据。

尚需确认真实登录、当前移动传输密钥、各地套餐差异、会话寿命、安卓 WebView 脚本时机与通知行为。

安卓桌面小组件现已加入：在 APP 中点击“添加桌面卡片”，接受系统桌面确认；不支持直接固定的桌面可以长按空白处手工添加。卡片显示最近查询的两卡余量、查询时间及状态，点击卡片打开 APP 更新。API 24 及以上支持系统小组件，直接申请固定从 API 26 起且取决于桌面支持情况。APP 关闭后的后台持续查询尚未实现。

## GitHub 上传范围

源码、测试、说明、经过必要兼容修改的依赖源码与界面演示图进入仓库。测试 APK 通过 GitHub Release 分发，不提交到 Git 历史。构建工具、SDK、Pub 缓存、未修改的参考源码、构建输出和个人会话数据不上传。
