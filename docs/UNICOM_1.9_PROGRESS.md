# 联通余量反馈：官网停留 E5 时的登录失效识别

2026-10-01。本轮先复核 TECH_LOG.md、UNICOM_REFRESH_PROGRESS.md 与 UNICOM_TELECOM_RESEARCH.md，复用已经下载的联通官网资料及 ChinaUnicomMonitor / FlowLite 参考，没有重复下载或复制无许可证代码。

可证的缺口来自官网源码：`references/carrier-public-deep/0-8.js` 的 `myE3LoginObj.sendRequest` 自然请求 `/e3/static/check/checklogin/`；`0-1.html` 第 75 行附近仅在 `myE3LoginObj.isLogin` 为真、存在 userInfo 且网别符合条件时请求 `userinfoE5query`。因此官网可停留 E5 页面但完全不请求余量，原应用只捕获余量、只以 login URL 判断失效，无法及时说明重新登录，最后只能显示查询超时。这是代码可证路径，不等同于已定位截图用户的唯一原因。

`page_probe.dart` 现在仅在 HTTPS iservice.10010.com 的 `/e5/index.html` 或 `/e5/query.html` 主框架，观察官网自然发出的精确 checklogin 接口响应。只有 HTTP 2xx 且 `isLogin` 严格等于 false 时，向现有 trafficResponse 桥发送 `stage=unicomSession`、固定 body `{"isLogin":false}`。请求 URL 和页面 URL 均去除 query/hash，原始用户资料、号码、凭证不进入该消息或延迟队列；不读取 Cookie，不主动调用接口，不触发登录或短信。登录成功、缺字段、字符串 false、服务端失败均不伪造失效或余额。

`carrier_web.dart` 对 session 和余额区分精确 stage/path，只允许不带查询及 fragment 的 session URL；`response_policy.dart` 的 `isUnicomSessionExpired` 再检查 2xx 与单键 false。主页面接线交由 main.dart 的负责代理：验证 session 后沿现有错误终态保留上次成功快照、结束刷新并显示重新连接提示，正常成功信号不抢占余量解析。

Node `app/test/services/page_probe_js_test.cjs` 已通过：新增失效事件、原响应保真、资料脱敏、document-start 延迟桥接、未知/成功/非 2xx 忽略、登录页拒收回归，并保持既有移动/广电捕获测试。Dart 服务测试已补 session 身份白名单、严格 false 和状态码边界；按代理职责没有运行 Flutter、Dart、Gradle，交由根代理统一串行验收。git diff --check 无差异错误（仅换行符提示）。

限制：未执行真实登录、发短信或验证真实套餐。无法确认截图手机是否登录失效、官网套餐不支持，或另有页面/接口异常；本轮不能宣称真实联通余量查询已全面修复。登录有效但没有余量的情况仍应按超时/无法识别处理，不能猜测 APP 接口 token、成功码或伪造数值。
