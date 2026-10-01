# 参考项目索引

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

广电失败复核记录位于 broadnet-public/failure-review/，使用新的公开官网加载与本地合成响应核对两套 jQuery 实例、原探针漏数及修复后桥接。可复用的验证脚本收录于 scripts/test-broadnet-browser.cjs；证据范围和复用方法见 docs/PROTOCOL_RESEARCH.md，不含真实账号或凭证。

新增联通/电信精选参考：`ChinaUnicomMonitor/` 来源 https://github.com/dengfhqqq/ChinaUnicomMonitor （未发现LICENSE）；`FlowLite/` 来源 https://github.com/nongchengqi/FlowLite （未发现LICENSE）；`ChinaTelecomMonitor/` 来源 https://github.com/Cp0204/ChinaTelecomMonitor （AGPL-3.0，附LICENSE）。仅协议研究，不复制到应用，这些项目依赖APP认证，不能作为网页登录已接通的依据。

`carrier-web-research.cjs` 与 `carrier-web-entries.json` 为本机Chrome公开入口检查工具及无账号结果。结论见 `docs/UNICOM_TELECOM_RESEARCH.md`。

深入官网记录位于carrier-public-deep/和telecom-public-deep/，每个index.json保留原URL与HTTP状态。联通已取得userinfoE5query请求、resource.remainFlow字段、MB单位与登录门禁原文；电信省分/全国页面仍在正常执行防护后返回空白。ahBot/精选文件来自https://github.com/WM9116/ahBot，未发现LICENSE，仅小程序线索研究。工具为carrier-web-deep.cjs，未输入账号或发送短信。

电信新官网Account结构的可复用浏览器验收脚本为 scripts/test-telecom-rendered-browser.cjs，全部网页请求本地拦截，结果 artifacts/telecom-rendered-browser.json。它验证探针与已归档公开DOM结构，不验证真实账号，也不调用电信余额接口。
