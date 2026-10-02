# 联通互联网方案核查（2026-10-02）

老板询问互联网是否已有解决联通查询失败的方案。本次只研究公开代码，不改应用认证、不发送验证码、不登录真实账号，也不重新构建或发布安装包。

## 结论

有现成实现可作为协议研究依据，主要路线是使用联通 App 登录态调用移动服务接口，另有旧小程序方案。当前应用依赖 E5 网页初始化和网页会话；App 登录态与网页登录态不能假定互通，单独替换查询 URL 或 User-Agent 不足以完成接入。建议下一轮优先验证 App 登录态到套餐查询的完整链路，先取得真实账号成功证据，再决定用户登录交互。

## 已核对的项目

[ChinaUnicomMonitor](https://github.com/dengfhqqq/ChinaUnicomMonitor) 已在工作区下载，不重复下载。它提供 Cookie 与 token_online 两种路径，通过 onLine.htm 获取/更新登录态，再查余量。首个凭证通常需要用户从官方 App 获取；README 提及切换账号导致 Cookie 失效及设备校验风险，不能宣传永久有效。未发现 LICENSE，仅作协议研究。

[Newxin394/unicom-monitor](https://github.com/Newxin394/unicom-monitor) 的 main.go 有实际请求代码：tokenOnlineLogin 调用 m.client.10010.com/mobileService/onLine.htm，passwordLogin 调用 mobileService/login.htm；fetchAndCalculate 调用 servicequerybusiness/operationservice/queryOcsPackageFlowLeftContentRevisedInJune，解析 resources/details 的 total、use、remain、limited、flowType，并处理会话失效、空资源及非 JSON 响应。它可以帮助研究续期、多账号归属与不限量状态，但不提供短信发送流程。代码自述纯 AI 生成，未验证实际可用性；LICENSE 为 MIT，README 又含禁止商业用途等文字，两者存在许可表述冲突，不直接复制实现。读取时 HEAD 为 7be4b2e56f4fa38bf05e409713b1dc45e69dd956；摘录另保存具体文件 blob SHA。

[aichuguang/unicom-monitor-v3](https://github.com/aichuguang/unicom-monitor-v3) 确实实现短信验证码提交：backend/app/utils/unicom_api.py 的 sms_login 将参数提交至 mobileService/radomLogin.htm，保存响应的 token_online、Cookie 等；query_flow 调用同一套餐余量接口。重要限制是 frontend/src/components/AccountManager.vue 第 148、195 行明确让用户打开官方联通 App 点击“获取验证码”，再回来填写。它并未提供完整的应用内验证码获取体验，也不能保证跨客户端验证码可以复用。接口参数依赖 AppID/设备信息，并处理 ECS99999 风控；参考日志会输出登录请求/响应，不适合照搬到公开应用。未发现 LICENSE，不复制业务实现。仓库 pushed_at 为 2025-10-15，HEAD 为 b78f4265d8692910d0270ebb1c592140e411b1f8。

[Paladinfeng/CHU-Widget](https://github.com/Paladinfeng/CHU-Widget) 是 MIT 的 iOS Today Widget 老项目。README 要求从联通微信小程序取得 stoken；TodayViewController.swift 调用 mina.10010.com/wxapplet/bind/getIndexData 与 getCombospare。证明还有小程序查询路线，但代码停留在 2019 年，不作为现今稳定可用的依据。HEAD 为 9398fe5aec4c594827d0d97e57fd3250e26a532b。

同名 GO_UnicomMonitor 实际是摄像头监控，cherry10086/unicom-monitor 是公开资费目录监控，均排除，不用它们证明个人余量查询可行。

## 如何用于本项目

优先研究 App 查询路线，关键不是解析字段，而是取得可用且归属正确的认证，再验证续期、风控与不同套餐。用户不应被迫日常抓包；手工导入凭证更适合作为受控验证工具，不能当作普通用户的一键登录方案。若要提供短信登录，需要另外验证完整获取验证码和提交链路，保持官方安全验证流程；本次研究并未证明该链路可用。

现有网页兼容代码只能有限补齐网页初始化，不能据此声称解决了所有联通账号问题。系统手机的流量校正可能使用运营商合作接口或短信，不等同第三方应用天然拥有同样能力。

## 下载与验证范围

精选公开源码、带行号摘录、许可证和 blob SHA 索引位于 ignored 的 references/unicom-solutions-20261002/。既有 ChinaUnicomMonitor、FlowLite、ahBot 保留原位置，不重复下载。没有下载或运行上游二进制，没有上传真实账号、Cookie、验证码或 token。

本次验证为源码交叉核对，确认真实请求实现及前端入口，未运行上游程序、未实测真实账号、未证明接口当前对所有省份和套餐可用。生产认证实现尚未更换，不把研究结果写成已修复。
