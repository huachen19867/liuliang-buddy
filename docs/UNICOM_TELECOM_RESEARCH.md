# 联通、电信官网登录初查

2026-09-30，只调研不改应用。复用移动/广电参考，没有重复下载，没有输入账号或发送短信。官网公开入口可打开不等于真实余量已接通。

## 公开浏览器实测

联通 `https://iservice.10010.com/` 实际跳转 `https://uac.10010.com/portal/mallLogin.jsp?redirectURL=https://iservice.10010.com/e5/index.html`，标题“登录”，支持密码/随机密码并显示滑块安全验证。`https://uac.10010.com/portal/homeLogin` 也可打开。WebView候选方案需正确处理uac/iservice官方跨域跳转与Cookie，由用户完成验证。本轮未得到登录后套餐页、查询响应或官网单位证据。

电信 `https://login.189.cn/web/login` 正常显示“电信账号登录”，密码/短信方式及用户协议选项，明确要求启用Cookie。`https://www.189.cn/` 本次浏览器只得到空白页面，未确认个人套餐页或省分跳转；不据此断言网站永久不可用。登录步骤与同意操作仍由用户完成。

本机Chrome检查工具为 `references/carrier-web-research.cjs`，输出 `references/carrier-web-entries.json` 包含最终URL、标题、文本及公开脚本URL，没有保存Cookie。没有提交表单。此实测没有覆盖Android WebView或真实账号。

## 已下载参考与许可

`references/ChinaUnicomMonitor/` 来自 https://github.com/dengfhqqq/ChinaUnicomMonitor ，精选README、ChinaUnicom_Cookie.py、ChinaUnicom_Token.py，未发现LICENSE，不复制源码。README明确联通APP抓包Cookie/token。APP在线登录地址 `https://loginxhm.10010.com/mobileService/onLine.htm`；余量地址 `https://m.client.10010.com/servicequerybusiness/operationservice/queryOcsPackageFlowLeftContentRevisedInJune`，POST。第三方脚本使用 `code == "0000"`，读取 `resources[type=flow].details[]` 的 `remain/total/use`，名称 `feePolicyName/addUpItemName`，按MB格式化。未证实网页登录Cookie能用于此接口，不能据APP协议直接实现“官网接通”。

`references/FlowLite/` 来自 https://github.com/nongchengqi/FlowLite ，精选README、QueryService.kt、CaptureUtil.kt、ParseUtil.kt，未发现LICENSE。CaptureUtil针对联通APP `com.sinovatech.unicom.ui` 抓Cookie，且相关VPN捕获代码已注释；不是官方网页登录方案，不复制实现。

`references/ChinaTelecomMonitor/` 来自 https://github.com/Cp0204/ChinaTelecomMonitor ，精选README、telecom_class.py及LICENSE，实际为AGPL-3.0。只作协议研究，不直接引入其代码。它使用账号密码及加密载荷登录 `https://appgologin.189.cn:9031/login/client/userLoginNormal`，用APP token查询 `https://appfuwu.189.cn:9021/query/qryImportantData`、`/query/userFluxPackage`。第三方解析包含 `flowInfo.totalAmount/commonFlow/specialAmount` 的used/balance及明细带单位文本转换；这不是网页响应证据，未确认网页登录会话互通，不能将APP账号接口伪装为网页登录方案。

## 可实施程度

目前可做联通、电信“官方查询入口”，不能承诺首页真实余额自动提取。完整接入仍需要合法网页登录后页面自然发出的查询地址、成功/失效码、余量字段与单位和号码绑定证据。官网验证码或登录限制必须保留，不绕过。新增首次运营商选择解决账户组织，不能补齐这些协议证据。

可复用现有origin白名单、限定流量响应、桥接就绪缓存和过期状态管理；不可复制广电webpack模块号、成功码、KB单位或移动AES参数。两个同运营商号码还需要独立会话设计，不能认为同WebView Cookie能同时代表两号。公开GitHub与实现范围由根代理跟进；本阶段没有发布行为。
