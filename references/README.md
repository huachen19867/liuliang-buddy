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

Git 直连在本机失败，前三个项目和广电扩展通过 GitHub codeload 下载并解压，源码保留上游目录名。zip 归档一并保留便于追溯。broadnet-query-page.html 为初次普通 HTTP 请求获得的 WAF 页面；可用业务页面与资源位于 broadnet-public/。

android-widget 的文件与许可证已下载至本地，详细来源在该目录 README.md，实施结论在 docs/WIDGET_RESEARCH.md。GitHub 仓库保留本索引，参考源码不重复上传。
