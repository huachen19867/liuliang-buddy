# 联通查询现场协议复核

2026-10-01。先阅读 TECH_LOG.md、UNICOM_1.9_PROGRESS.md 和已下载的 carrier-public-deep 官方协议快照，复用 references/carrier-web-deep.cjs；本轮没有改生产代码，也没有运行 Flutter 或 Gradle。

重新以无账号 Chrome 正常浏览 https://iservice.10010.com/e5/index.html 和 query.html，两个页面均返回联通网上营业厅。公开 HTML/JS 与资源索引保存到 references/unicom-query-20261001/，其 README 解释来源。没有登录、提交短信、读取 Cookie 或调用隐藏业务接口。

发现上一轮判断的限制：旧 baseTools.js 确实定义 myE3LoginObj.sendRequest 和 /e3/static/check/checklogin/，但本轮两页网络记录没有自然请求该接口，也没有 userinfoE5query。实际页头调用 https://www.10010.com/mall/service/check/checklogin，其 HTTP 200 响应是 JSON；脱敏记录仅保留键名 isLogin/num、isLogin=false 和正文长度，不保存原始正文或号码。实际注入现有 responseCaptureScript 后，匿名页面产生的桥接事件为零，见 probe-observation.json。这是实际官网匿名浏览验证，不是合成响应测试。

当前公开 header bundle（归档 0-15.js）的 checkLoginState 写入 window.myLoginObj 和 window.userInfo，没有更新旧 myE3LoginObj。旧 E5 HTML 仍以 myE3LoginObj.isLogin、userInfo 及网别门禁决定是否请求 userinfoE5query；运行时旧对象为 false/null。仅凭旧 sendRequest 函数存在，不能断言页面加载会执行它。匿名情况下不能进一步证明已登录页面必然失败，也不能把商城会话视为 E5 余额授权；因此本轮没有扩大捕获白名单、主动发请求或猜测新的登录成功规则。

现有原始响应路径 /e3/static/query/userinfoE5query 与官方 E3CommonsVariables.RequestPrefixQuery 仍一致；官网 commonsFormat.getFlow 明确以 MB、1024 换算 GB，应用保持 MB 解析正确。successFlow=false、未知资源及不完整余额的拒收有官网模板依据，未找到应据此放宽校验的证据。真实账号的失败阶段仍需用户反馈或真机正常操作定位，不能宣称联通真实余量已修复。

## 官网原函数恢复候选

后续只读研究按已授权查询范围，在新的匿名 Chrome E5 页面正常调用官网 myE3LoginObj.sendRequest() 一次。调用前 sendRequest、E3QueryMain.loadData 和 query_info.personalInfo_back 均为 function；调用后自然产生精确旧 /e3/static/check/checklogin/ POST，HTTP 200、JSON 单键 isLogin=false，官网函数返回 false，旧对象仍为 false/null，页面未跳转。脱敏证据为 official-session-invocation.json。没有请求余量或短信，没有完成登录。

因此最小候选是用户点击查询后，限定原 HTTPS E5 主框架、官网函数已就绪，每个新查询文档仅一次调用原 sendRequest；只有官网确认 isLogin===true、userInfo 存在且 nettype 为 01/02/11 时，再调用页面自身 E3QueryMain.loadData('/userinfoE5query', null, 'query_info.personalInfo_back(data)')。参数和回调来自当前 HTML 原业务入口，不拼接 token、不设置登录标志、不读取凭证、不额外请求积分。原响应继续经过已有来源与业务校验。匿名负例实际可行，登录后正例仍未验证，属于有依据的修复候选而非已确认修复。

实现限制需保留：官网 sendRequest 使用同步 XHR、没有 timeout，而且失败分支不清除旧 true 状态；因此应放在新导航初始化的 false/null 文档里，仅一次触发，不用轮询重复执行，也不能把旧对象的 true 当成本次验证成功。官网在邮箱未绑定号码时可能自行跳转官方绑定页，这是原有账号门禁，不应干预。网络失败或缺函数应回到明确错误/超时，不自行构造响应。

## 最小兼容脚本实现

新增 app/lib/services/unicom_official_query.dart，导出 unicomOfficialQueryScript，供用户查询的 E5 加载完成后调用。严格 HTTPS origin、两个精确页面、主框架、官网函数完整性和每文档一次标志；已登录或部分填充的旧对象不碰。官网 sendRequest 返回和 isLogin 都须严格 true，且网别在允许范围内，才调用原余量查询。异常不传播，也不重试触发；不包含短信或凭证读取。main/background 接线由根代理完成。

Node 合成测试 app/test/services/unicom_official_query_js_test.cjs 的 8 组场景通过，覆盖来源、iframe、路径、缺函数、旧状态、匿名、异常、严格网别和重复执行。另在真实匿名官网 Chrome 同时注入现有响应探针与新兼容脚本，连续执行新脚本两次，只收到一次 HTTP 200 的 unicomSession 负例事件；见 compatibility-script-observation.json。该结果证明匿名会话现在能通过已有桥接被识别，不等于真实已登录余量已验证。没有运行 Flutter 或 Gradle。

根代理接入前台进行中的查询文档与后台加载完成，登录返回刷新优先，避免旧页和新页都触发。完整Flutter148/analyze通过，Node8组通过。新APK真实联通登录后的余量仍待用户反馈。
