# 参考项目索引

`system-surfaces/` 保存 2026-10-01 下载的 Android 官方 Quick Settings、TileService API、通知权限、通知渠道和 Android 14 ongoing 通知变化网页；`index.json` 记录原始 URL、HTTP 状态与 SHA-256。复用平台方案，不复制业务代码，官方网页按页脚 CC BY 4.0／代码示例 Apache 2.0 使用。API 分界、系统授权与不能承诺不可清除的研究结论见 `docs/SYSTEM_SURFACES_RESEARCH.md`。

同目录 `platform-samples/` 已下载 Google 官方 Quick Settings 模块源码/资源和 Apache-2.0 LICENSE，固定 commit `0445045024fafb3e15104c4f4f7a016e2d0d71ee`，`sample-index.json` 保存文件来源与 blob/SHA-256。`flutter-android-release.md` 是 Flutter 官方网站 Android 发布文档（blob `451913d810c7b80d4ebae5ad4513caf8c15c9af8`），签名与 R8 资料来源见 `flutter-release-index.json`。以上仅参考，不随应用公开打包。

2026-09-30 下载，供调研和复用评估。项目采用的方案与代码引用须记录在技术日志。

| 目录 | 上游 | 许可证 | 用途 |
| --- | --- | --- | --- |
| ChinaMobileMonitor | https://github.com/shiranzby/ChinaMobileMonitor | MIT | 移动网页登录、会话与流量查询 |
| 10099-Tracker | https://github.com/BiancoCat/10099-Tracker | MIT | 广电登录和套餐流量查询 |
| DataMonitor | https://github.com/itsdrnoob/DataMonitor | GPL-3.0 | 只研究安卓统计与权限限制，不复制源码 |
| BroadnetFlowKeeper | https://github.com/FIONN191/China-Broadnet-Flow-Keeper | 未提供许可证 | 仅检查官网地址和会话字段，不复制实现 |
| broadnet-public | https://www.10099.com.cn/personal-center-number-order.html | 运营商公开页面 | 浏览器正常打开后的公开 HTML/JS，核对 H5 请求、字段与单位；未登录 |
| android-widget | https://github.com/android/user-interface-samples/tree/main/AppWidget | Apache-2.0 | Google 官方 AppWidget 精选源码、RemoteViews 与固定入口；固定上游 commit 2c0b04e9092410a14381b86c168034a52243b85b |
| android-workmanager-sample | https://github.com/android/architecture-components-samples/tree/main/WorkManagerSample | Apache-2.0 | Google 官方 WorkManager 周期任务与 Worker 生命周期参考；固定上游 commit e849ce3004ccd1132a121cf513bbcb7996d95c30 |

Git 直连在本机失败，前三个项目和广电扩展通过 GitHub codeload 下载并解压，源码保留上游目录名。zip 归档一并保留便于追溯。broadnet-query-page.html 为初次普通 HTTP 请求获得的 WAF 页面；可用业务页面与资源位于 broadnet-public/。

android-widget 的文件与许可证已下载至本地，详细来源在该目录 README.md，实施结论在 docs/WIDGET_RESEARCH.md。GitHub 仓库保留本索引，参考源码不重复上传。

android-workmanager-sample 使用 sparse checkout 下载，仅保留 WorkManagerSample、根 README 与 LICENSE。实现结论及周期任务限制见 docs/WIDGET_BACKGROUND_REFRESH.md；参考源码不进入公开应用仓库。

ios-platform-review 保存 2026-10-01 的 Flutter 官方 iOS 开发环境源文档和 Apple WidgetKit 刷新说明。Flutter 文档站 HTTPS 请求在本机 TLS 失败后，改从 flutter/website 的官方 GitHub 内容 API 获取 `sites/docs/src/content/platform-integration/ios/setup.md`；来源、blob SHA 和下载状态记于目录内 index.json。仅用于平台可行性研究，不表示已有 iOS 构建或签名。

2026-10-01 的 iOS 实施新增 `ios-home-widget/` 精选参考，来自 [ABausG/home_widget](https://github.com/ABausG/home_widget)，固定 commit `a3e6b641e365c0a5d25f206d543ef9b88bdb8617`。下载包内 BSD-3-Clause LICENSE、WidgetKit 示例、App Group entitlements、Xcode target 配置和原生桥接源码，来源及 blob SHA 保存到目录内 index.json。仅复用 App Group + WidgetKit 的平台方案，未引入该插件或其后台执行代码；现有 payload 直接由本项目桥接展示。官方 Flutter 3.44.8 iOS 模板通过本地 Flutter SDK 生成到 `.tools/ios-scaffold/`，只复制 iOS 子树到应用，保留现有安卓业务。

`ios-platform-review/wkwebsitedatastore-identifier.json` 为 Apple 官方文档 [WKWebsiteDataStore.init(forIdentifier:)](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/init(foridentifier:))的 JSON 原文，确认 iOS/iPadOS 17.0 起可用、UUID 对应持久化 Profile。新建 iOS 工程最低 17.0 的依据记录在 IOS_SESSIONS.md，不用无持久性的临时仓库冒充跨启动独立登录。

`ios-webkit-linker/` 保存 [WebKit 官方问题 293831](https://bugs.webkit.org/show_bug.cgi?id=293831#c2)和插件上游回帖，确认 iOS 18.4/18.5 模拟器的 Swift WebKit overlay 打包问题。云端脚本仅在实际 Cryptex 库存在时采用官方模拟器环境修复，不改产品强链接或最低版本。

`mobile-face-login/` 保存中国移动公开官网的下载链接、官方 App 入口页面和请求来源索引。复用 ChinaMobileMonitor 参考核对网页登录边界，未输入号码或取得人脸授权协议；结论见 `docs/MOBILE_FACE_LOGIN_RESEARCH.md`。

广电失败复核记录位于 broadnet-public/failure-review/，使用新的公开官网加载与本地合成响应核对两套 jQuery 实例、原探针漏数及修复后桥接。可复用的验证脚本收录于 scripts/test-broadnet-browser.cjs；证据范围和复用方法见 docs/PROTOCOL_RESEARCH.md，不含真实账号或凭证。

新增联通/电信精选参考：`ChinaUnicomMonitor/` 来源 https://github.com/dengfhqqq/ChinaUnicomMonitor （未发现LICENSE）；`FlowLite/` 来源 https://github.com/nongchengqi/FlowLite （未发现LICENSE）；`ChinaTelecomMonitor/` 来源 https://github.com/Cp0204/ChinaTelecomMonitor （AGPL-3.0，附LICENSE）。仅协议研究，不复制到应用，这些项目依赖APP认证，不能作为网页登录已接通的依据。

`carrier-web-research.cjs` 与 `carrier-web-entries.json` 为本机Chrome公开入口检查工具及无账号结果。结论见 `docs/UNICOM_TELECOM_RESEARCH.md`。

深入官网记录位于carrier-public-deep/和telecom-public-deep/，每个index.json保留原URL与HTTP状态。联通已取得userinfoE5query请求、resource.remainFlow字段、MB单位与登录门禁原文；电信省分/全国页面仍在正常执行防护后返回空白。ahBot/精选文件来自https://github.com/WM9116/ahBot，未发现LICENSE，仅小程序线索研究。工具为carrier-web-deep.cjs，未输入账号或发送短信。

电信新官网Account结构的可复用浏览器验收脚本为 scripts/test-telecom-rendered-browser.cjs，全部网页请求本地拦截，结果 artifacts/telecom-rendered-browser.json。它验证探针与已归档公开DOM结构，不验证真实账号，也不调用电信余额接口。

通话/短信扩展证据归档在 allowances/：evidence-index.json 记录既有联通/广电/电信官方页面片段的URL、原文件SHA-256和偏移，以及移动MIT参考解析代码；mobile-index.json为2026-10-01重新无账号浏览移动查询页后跳登录的公开请求记录。研究结论与谨慎分类契约见 docs/VOICE_SMS_RESEARCH.md，不含真实号码或余额响应。

carrier-brand/记录2026-10-01四家官网Logo下载调查与公开HTML/CSS，原始资源与具体URL见scripts/carrier-originals/和app/assets/carriers/README.md。仅裁切原版图形保留原色，标识识别使用不改变商标归属；不复制运营商业务代码。

unicom-query-20261001/记录当前联通公开E5/头部JS及无账号会话形态；匿名只验证正常官网函数调用，无登录/验证码或真实余额，观察JSON脱敏为URL、状态、键名和真假标志。研究见docs/UNICOM_QUERY_PROGRESS.md。最小兼容通过官网原函数，不复制认证或令牌生成。

carrier-compatibility-20261002/记录三家官方登录入口的移动视口匿名观察，以及联通异步原函数查询的脱敏负例验证。电信登录iframe临时参数不保留在索引中；公开页面归档仅研究，不当作真实登录或余量验收。结论、有限修复与接线要求见docs/CARRIER_COMPATIBILITY_1.10.md。

unicom-solutions-20261002/ 保存 Newxin394/unicom-monitor 的 App 登录/续期/套餐查询摘录、aichuguang/unicom-monitor-v3 的验证码提交和前端官方 App 获取验证码说明，以及 Paladinfeng/CHU-Widget 的小程序查询源码。index.json 记录原文件 URL、blob SHA 和摘录行号；许可证分别为 MIT（Newxin README 有额外限制，未复制到应用）、未发现、MIT。只下载公开研究文件，不运行上游二进制或取得真实凭证；既有 ChinaUnicomMonitor 不重复下载。研究结论见 docs/UNICOM_INTERNET_SOLUTIONS.md。

2026-10-02 手动套餐用途优化复用既有 FlowLite/README.md 的“首次个性化分组”使用说明，沿用用户修正分类的思路；不复制其移动套餐包或清除计数实现，不重复下载。应用实现按独立账号与唯一套餐名存覆盖，保留自动结果，首页与组件共用摘要；实现及边界见 docs/TRAFFIC_CLASSIFICATION_REVIEW.md。

1.10.3联通双不限反馈复用unicom-query-20261001/0-1.html的官方personalInfo_back与flowTemplate成功门禁，以及既有FlowLite边界资料；不重新下载，不凭套餐名扩大认证或宣称无限GB。有限脚本就绪等待与部分结果保留见docs/RELEASE_1.10.3.md。
