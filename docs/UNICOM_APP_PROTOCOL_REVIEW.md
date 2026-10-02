# 联通 App 协议接入复核（2026-10-02）

本次先读 `TECH_LOG.md` 与 `UNICOM_INTERNET_SOLUTIONS.md`，复用已下载的 `references/ChinaUnicomMonitor/`、`references/unicom-solutions-20261002/` 和官方网页归档；没有重复下载、运行上游程序或发出真实账号请求。此文只说明静态证据与实施边界，不代表真实账号验收通过。

## 普通用户登录建议

现有证据不足以交付完整的自建 App 短信登录。普通用户入口应继续使用联通官方网页完成短信、人机和身份验证，由官方页面管理短信发送与认证；认证成功和查到余量必须分别判断。App 认证可以作为独立的后续接入路线，但不能把网页 Cookie 当作 App Cookie，也不能让抓包成为默认新手流程。官方 App 已登录不意味着本应用的 WebView 已登录。

现有网页入口位于 `app/lib/services/page_probe.dart`，为 `https://uac.10010.com/portal/mallLogin.jsp?redirectURL=https://iservice.10010.com/e5/index.html`；`unicom_official_query.dart` 只修复 E5 旧会话初始化并调用官网原查询函数。它没有取得移动服务认证，也没有实现 App 登录。保留当前网页边界，不能因为增加 App 解析器就把网页故障写成已修复。

## 公开请求证据

[Newxin394/main.go](https://github.com/Newxin394/unicom-monitor/blob/7be4b2e56f4fa38bf05e409713b1dc45e69dd956/main.go) 第 1205–1228 行使用 `POST https://m.client.10010.com/mobileService/onLine.htm`，表单为 `appId`、`token_online`、`version`，判断响应 `code == "0"`，读取 `Set-Cookie`、轮换后的 `token_online` 和 `invalidat`。第 1252–1282 行的密码登录为 `POST /mobileService/login.htm`，发送 RSA 加密的 `mobile`、`password` 以及 `appId`、`version`。这些是第三方实现，不是官方稳定接口承诺。

[ChinaUnicomMonitor/ChinaUnicom_Token.py](https://github.com/dengfhqqq/ChinaUnicomMonitor/blob/main/ChinaUnicom_Token.py) 使用另一主机 `https://loginxhm.10010.com/mobileService/onLine.htm`，还带 `reqtime`、`step`、`isFirstInstall`、`deviceModel`、`deviceCode`。其代码借用固定设备信息，不应照搬到本应用。不同参考的参数与主机不一致，说明认证细节仍需实际协议验证，不能自行拼接成所谓通用方案。

[aichuguang/unicom_api.py](https://github.com/aichuguang/unicom-monitor-v3/blob/b78f4265d8692910d0270ebb1c592140e411b1f8/backend/app/utils/unicom_api.py) 第 103–222 行只实现短信提交 `POST https://m.client.10010.com/mobileService/radomLogin.htm`，手机号与验证码经 RSA 加密，由设备对象生成参数并设置 `loginStyle=2`。已有摘录没有完整参数生成函数，不能声称已核实所有必填字段。其前端第 148、195 行明确要求在官方 App 获取验证码。没有发现可复用的短信发送实现，也未证实跨客户端验证码能复用；禁止将提交接口包装成已经可用的“获取验证码”按钮。

三份参考共同使用 `POST https://m.client.10010.com/servicequerybusiness/operationservice/queryOcsPackageFlowLeftContentRevisedInJune` 查询套餐余量，携带 App 会话 Cookie，参考中请求体为空。成功示例协议判断为 `code == "0000"`，数据为 `resources[].details[]`。ChinaUnicomMonitor 另使用 `POST https://m.client.10010.com/servicequerybusiness/balancenew/accountBalancenew.htm`，余额字段 `curntbalancecust`。本次未以真实账号确认余额单位或各省返回差异；不可仅凭字段名换算金额。

## Cookie 与账号归属

公开 Cookie 版实现证明的是“作者代码用 App Cookie 直接请求”，不证明所有有效 Cookie 都可查询，更不证明网页登录态互通。Cookie 版账号手机号来自用户配置，不是服务器身份确认。其 token 版在 onLine 成功时读取服务器 `desmobile`，这是可研究的归属信号；该字段可能脱敏，不能把未知号码或部分掩码当作完整账号匹配。

App 适配层若后续实现，应将凭证、账号、会话版本和查询结果绑定；登录响应中可信的完整手机号须与目标账号一致，切号或会话变化后丢弃在途旧响应。只有脱敏身份时可提示用户核对并记录确认状态，不应自动覆盖已有已验证号码；套餐查询没有身份字段时，单独的 `code=0000` 不能证明账号归属。不得使用导入表单中的手机号充当服务器验证结果。

## 可立即复用的工程结论

可独立实现有来源标记的 App 响应解析器、错误分类及合成数据测试，为未来认证适配留接口；真正联网查询仍需可信 App 会话才能启用。采用精确 HTTPS 主机和路径白名单，拒绝跨域重定向携带认证，按账号隔离会话；日志不记录 Cookie、token、手机号、验证码及原始登录响应。令牌续期最多一次，认证失败回到用户登录，不能以更换设备标识或持续重试处理风控。

解析不能照搬上游“total<=0 就无限量”“空资源就是登录失效”“remain<=0 就 total-use”的宽松推断：零剩余可能是真的，空资源可能是合法套餐或接口异常，缺字段也不等于不限量。App 套餐字段应先确认单位与缺失语义，不明确的类别保留未知，避免合计和分项重复累加。

ChinaUnicomMonitor 与 aichuguang 未发现许可证；Newxin394 的 MIT 与 README 使用限制存在冲突。本项目仅参考公开协议事实，独立编写实现，不复制其业务源码、固定设备标识或敏感日志做法。后续所需验证是老板正常完成官方认证后的一次真实查询与账号归属核对，而非匿名 HTTP 200 或上游 README 宣称。
