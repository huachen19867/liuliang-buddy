# 移动话费余额采集

2026-10-02，复用工作区已下载的 `ChinaMobileMonitor`、移动匿名官网与 `docs/TECH_LOG.md`，没有复制上游业务代码或引入新查询框架。已有 MIT 参考把 `fareBalance.data.realFeeQryRsp.curFeeTotal` 直接当作元；现有官方归档只有登录页，尚未提供首页业务接口的字段标签和单位证据，因此本次不照抄该推断，不把 `realFee`、`curFeeTotal` 或通用 `balance` 字段当作话费余额。

`app/lib/services/page_probe.dart` 增加 `mobileBalanceCaptureScript`。它只在 HTTPS `wx.10086.cn/website/spa/main/newHome` 主框架读当前可见 DOM：标签必须精确为“话费余额”或“账户余额”，三层以内局部容器的完整可见文本必须仅由标签、金额和“元”构成。金额可为零或负数；混入实时费用、其他标签、多个冲突余额、缺少元、隐藏节点、其他页面都不采集。这个限制可能跳过带充值按钮等附加文字的官网布局，宁可保持未提供，不误读本月费用。没有取得真实登录后的首页 DOM，当前标签支持是保守的采集契约，不声称已完成所有省份实号适配。

桥接使用独立 `mobileBalanceRendered` stage，`url` 与 `pageUrl` 必须等于当前官方首页。body 为 `{"source":"officialRendered","balanceText":"12.34元"}`，不转发号码、凭证、DOM 全文或其他账单内容。`carrier_web.dart` 校验精确主页/阶段/URL；`parseMobileBalanceRendered` 返回 `num?`，只接受严格元格式和现有一十亿元上下界，保留零值及欠费。移动流量解析和其他运营商规则未改。

文档开始注入后每 300ms 合并 DOM 变动、最多六秒，MutationObserver 采用固定截止时间，不因持续 DOM 变化延长；重复注入会主动读取当前 DOM 并重启有限窗口，即使余额相同也重新发送，因为先前事件可能发生在本轮查询开始前。官网请求、登录、验证码、页面数据都不修改，也不会主动调用接口。前后台本轮装配由主任务接线：余额先到不结束流量查询，流量先到最多再等五秒，余额失败或缺失仍保留成功流量，不能沿用旧余额冒充本次。

本地 Node 合成回归与既有 fetch/XHR 桥接回归均通过。实际 Chrome 的 17 类完全本地拦截页面通过，验证精确标签、元/零/负数、嵌套分离单位、混杂费用/缺单位拒绝、来源/框架/隐藏门禁、重复注入、当前 DOM 变化及持续变动下固定截止清理，结果为 `artifacts/mobile-balance-browser.json`。第一轮 Chrome 夹具未声明 UTF-8，中文被浏览器错误解码后严格标签正确拒绝；补 `text/html; charset=utf-8` 后才记录通过。文档开始时 `documentElement` 可能尚未建立，探针已补有限轮询期间延迟安装 observer。

Dart 新增余额解析和网址门禁回归，Flutter/Dart SDK 由主任务统一串行运行；不把合成测试当实号/桌面 Launcher 验证。可复用命令为 `node app/test/services/mobile_balance_probe_js_test.cjs`、`node scripts/test-mobile-balance-browser.cjs`。后者复用工作区 Playwright 和本机 Chrome，所有页面均由 route 本地拦截，不请求移动官网、不发送验证码。
