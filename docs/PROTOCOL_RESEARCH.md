# 运营商查询协议调研

调研日期：2026-09-30。结论来自下载到 references 的上游源码静态检查，未使用真实号码登录、未发送短信、未验证运营商实时响应。上游源码是协议线索，不是运营商承诺稳定的公开 API。

## 结论与实现边界

中国移动可以实现“本机官方页面登录 + 同一 WebView 监听页面请求并提取响应”的候选方案，不必运行 Playwright 后端。上游已有浏览器持久会话、页面请求捕获和响应解析的完整示例。Android WebView 是否被移动接受、验证码和会话能否正常完成，以及首次页面请求能否及时捕获，仍需要真机验证。不能把这个原型标为已完成真实接入。

中国广电的 10099-Tracker 采用微信小程序抓包重放，单凭它不能实现网页登录自动查询。后补参考 China-Broadnet-Flow-Keeper 确认存在官方网页登录和套餐查询页面，因此优先尝试 WebView 官方页面路径，无需要求用户抓包。该扩展没有查询 API 或流量解析实现，尚不能证明统一仪表盘能够获得数据。未解析成功时应显示尚未获得数据，允许查看官方查询页，不显示模拟余额。

## 中国移动证据

上游：https://github.com/shiranzby/ChinaMobileMonitor 。本地文件为 `references/ChinaMobileMonitor/ChinaMobileMonitor-main/chinamobile.py`。`LICENSE` 为 MIT，Copyright (c) 2026 shiranzby，复用源码或实质性内容须保留声明。

`login()` 从第 276 行打开 `https://wx.10086.cn/website/bind/bindAccount/new`，用户通过短信验证码登录；使用 Playwright 持久上下文保存整个浏览器状态，而非仅提取一个 Cookie。`query_single()` 第 507 行打开 `https://wx.10086.cn/website/spa/main/newHome`，拦截页面自行发出的请求。上游并没有给出 Cookie 名称或完整 CSRF/请求签名规范。README 声称登录态设备绑定，此为上游说明，未在本项目验证。

第 463 行附近识别 `getNewMarginInfo`、`getMainPlan`、`getMarginQueryInfo`、`getCustBaseInfo`、`fareBalance`、`accountFeeBalanceQuery`、`getBillSum`。除了套餐名补充查询外，上游没有明确固定这些接口的完整 URL、请求方法与请求体，不能仅按名称猜接口路径。第 536 行确认套餐名补充请求为 `GET https://wx.10086.cn/website/serviceMargin/getMainPlan?t=<毫秒时间戳>`，在已登录页面执行 fetch，`credentials: include`，请求头 `Accept: application/json, text/plain, */*` 和 `X-Requested-With: XMLHttpRequest`。这个补充调用没有显式 CSRF 头，并不证明其余接口不需要 CSRF。

`aes_decrypt()` 第 143 行将十六进制响应按 AES-CBC 解密，源码固定 key 为 `1234123412ABCDEF`、IV 为 `ABCDEF1234123412`，随后去除填充并解析 UTF-8 JSON。两个 ASCII 字符串均为 16 字节，符合 AES-128-CBC 要求，可用等价实现进行候选解密；函数捕获异常后退回原始字符串。密钥是否适用于当前官网仍须真实响应验证。

`parse_margin()` 第 218 行读取 `data.resultData.planRemianFlowInfo`。子对象 `planRemian` 为套餐流量、`directionalFlowInfo` 为定向、`otherRemian` 为其他、`totalInfo` 为总流量；每项读取 `usedNum`、`remainNum`、`sumNum`、`unit`。源码单位为 `03=MB`、`04=GB`，MB 除以 1024 换算 GB。不要忽略单位或把缺失字段默认为零成功展示。语音位于 `planRemianVoiceInfo`，短信位于 `planRemianMSGInfo`。套餐名称为 `object.resultData.curPlanName`；余额为 `data.realFeeQryRsp.curFeeTotal`。

上游以页面包含“套餐”等文本判断会话有效，这只能作为弱提示。本应用应以解析出结构完整、数值有效的真实查询响应为成功条件；HTML 登录页、错误码、缺字段以及解密失败不能替换已有成功数据。

## 广电证据

上游：https://github.com/BiancoCat/10099-Tracker 。本地文件 `references/10099-Tracker/10099-Tracker-main/main.py`、`extract_curl_config.py`、`README.md`。`LICENSE` 为 MIT，Copyright (c) 2026 BiancoCat。

`main.py` 第 7、66 行明确 `POST https://wx.10099.com.cn/contact-web/api/busi/qryUserRes`。JSON 请求体只有 `{"data": "<从本人请求提取的字符串>"}`。程序要求 `Session`、`Access`、`User-Agent` 三个请求头；另设 `content-type: application/json`、`Referer: https://servicewechat.com/wxfa72ff5488bbd1d9/125/page-frame.html`、Host 与压缩相关头。源码不设置 Cookie 或 CSRF 头，但 Session/Access 是敏感认证参数；不应将“不用 Cookie”误说为“无需认证”。`data` 的内部编码/加密/签名没有说明，必须原样取自合法会话，不能构造手机号替代。

README 要求登录微信小程序并通过抓包软件找到该请求，再复制 cURL。`extract_curl_config.py` 只解析 cURL 中以上四项，并不会完成登录。`main.py` 第 90 行以 `status == "000000"` 为成功；数据为 `data.intfResultBean.userResList[]`。明细字段为 `itemName`、`highFee`（总量）、`balance`（剩余）、`addupValue`（已用）、`startTime`、`endTime`。上游把三个数值解释为 KB，除以 1024² 显示 GB，并将所有条目相加。条目是否包含语音、定向或重叠额度仍须真实响应核对，本应用不应无条件将全部明细相加为通用可用流量。

401/403 被上游归类为失效；其他业务错误以 message/msg 中的认证关键词猜测失效。该猜测不应掩盖服务故障。会话过期后上游仍要求重新登录小程序、抓包、更新参数，并没有静默刷新机制。

## Flutter WebView 的可实现方式和限制

后补广电网上营业厅参考：https://github.com/FIONN191/China-Broadnet-Flow-Keeper ，位于 `references/BroadnetFlowKeeper/China-Broadnet-Flow-Keeper-main`。未发现 LICENSE，仅用作协议研究，不复制实现。`background.js` 第 11—15 行确认官网 `https://www.10099.com.cn`、登录页 `/login.html`、查询页 `/personal-center-number-order.html`。`lib/session.js` 定义 `broadnetUserPhoneInfo`、`broadnetUserSessionId`；`background.js` 从 sessionStorage 读取，并可恢复到 sessionStorage。其自设缓存上限七天不是运营商保证的有效期。扩展仅导航、保存与恢复会话，不包含 fetch 或流量解析；不能把 query page reached 状态当数据查询成功。

本次用普通 HTTP GET 读取官方查询页，实际得到含 `aliyun_waf_aa`、`acw_sc__v2` 的阿里云 WAF JavaScript 挑战页，没有取得业务 HTML。这支持使用能正常执行官网脚本的 WebView 再验证，不能依据此响应推断当前业务 API、CSRF 或字段。官方网页登录候选路径与微信小程序接口是两套会话，不应混用凭证。

移动官方页面应在同一个 Android WebView 存储环境内完成登录和查询，保留 Cookie/localStorage。登录动作与短信操作由用户在官方页面完成。可以在 document-start 注入窄范围 XMLHttpRequest/fetch 包装器，复制目标接口响应，经专用 JS bridge 发给 Dart；或页面加载后注入，再由页面内导航触发查询。仅 onPageFinished 注入可能错过页面首次请求，须使用支持 document-start 的插件/平台能力或验证可靠的再次触发机制。不要通过重发所有请求来“捕获”响应，避免重复请求副作用。

同源 fetch 通常可自动携带 HttpOnly Cookie，JavaScript 不需要也不应读取它；但 fetch 不会凭空生成未知的签名/CSRF。已确认的 getMainPlan 可作为低风险试验，流量请求应优先让官网自身脚本生成。网页返回加密数据时，网络捕获仍需使用 AES-CBC 正确解密和去除 PKCS7 填充，并验证 JSON 结构。若官网本身已有解析后的对象，可研究捕获该对象，但当前没有证据确认其位置。

广电微信小程序环境与普通 WebView 不共享会话。浏览器 fetch 不能自由伪造 Host/Referer/User-Agent，跨域还受 CORS 限制；将 Python 请求头照搬到 WebView 无法保证等价。已导入参数的重放应由原生 HTTP 客户端实现，并验证认证、压缩和错误处理，不需 Playwright 服务。凭证保存在设备安全存储中，不写技术日志、崩溃日志或版本库。

后台无界面长期自动查询另受 Android 生命周期、后台限制和 WebView 进程状态影响。本次仅论证前台刷新候选路径，未验证后台刷新或会话保活。两家运营商分属不同域可自然分开 Cookie，但“同手机双 SIM”不代表网页无需身份验证，也不证明本地流量计数与运营商额度相同。

## 尚未验证

未验证真实验证码登录、移动接口当前 URL/响应加密、广电有效会话、会话寿命、不同省份及套餐差异、Android WebView 支持情况或运营商限流。交付时必须明确保留这些边界。

## 广电官网公开脚本实测补充（2026-09-30 14:09）

使用 `.tools/browser/inspect-broadnet.cjs` 调用本机 Chrome，正常打开查询页并让网站脚本自行执行。官网成功加载后因未登录跳到 `/login.html`，标题为“登录-中国广电网上营业厅”。没有输入账号、发送短信或操作验证码。快照和来源索引保存在 `references/broadnet-public/`。这更新了此前“仅获得 WAF 页面”的调查状态，但并未完成真实登录或成功余额查询。

浏览器网络记录确认官方网页自然发送 `https://www.10099.com.cn/contact-web/api/busi/qryUserRes`。官网共用脚本 `6-common-85ed7.js` 将 `queryUserRes` 映射为 POST `/api/busi/qryUserRes`。实际未登录响应为 `{"status":"701","message":"登录已过期，请重新登录","updateMes":null,"data":null,"timestamp":...,"ok":false}`；所以认证失效不仅是 HTTP 401/403，也包括 HTTP 200 下业务状态 701。

公开查询脚本 `7-index-eba9b.js` 的 `queryUserRes` 请求业务参数为 `sessionId`、`channelId`、`accessNum`。共用层添加版本、timestamp，生成 Access 并封装加密 data。应让官网完成这些步骤，不自行重建签名。官网会话中的 `broadnetUserPhoneInfo` 和 `broadnetUserSessionId` 是官网加密存储字符串，备份恢复应原样保存。

官网共用层先解析响应 JSON，若整个对象只有一个字符串字段 data，会先调用内置解密再 decodeURIComponent 解析；这意味着存在加密响应分支，仅原始 XHR JSON 捕获不一定覆盖成功查询。随后要求外层 `status == "000000"`，并把 `e.data` 返回给查询脚本。查询脚本要求内层 `respCode == "000000"`，读取 `intfResultBean.userResList`。明文成功响应的候选完整路径与小程序参考相同：`data.intfResultBean.userResList`。调用官网 dataFilter 本身可能再次触发弹窗、导航等副作用，不建议为了获取明文直接调用它。

官网明确以 `busiType == "5"` 识别流量、`busiType == "1"` 识别分钟，其余显示条数。因此处理 H5 明细必须排除明确非流量类型，不可把语音当 KB。名称字段为 `discntName`，可兼容小程序的 `itemName`。`highFee` 为总量、`balance` 为剩余，官网对流量除以 1024² 显示 G，印证其 KB 单位；官网流量已用按总量减余额展示，非流量才直接显示 `addupValue`。另有 `userExtResList` 表示套餐外计费，字段 `extTotalValue` 和 `extDiscntFee`，它不是剩余额度，不应加进可用流量。

仍未获得真实成功响应，也不能据公开脚本确定哪些套餐属于通用/定向、是否重叠。新证据足以补充 H5 字段解析和 701 失效判断，但不能宣称广电真机查询已验证。

最终登录页实测暴露 `window.jQuery`，版本 3.5.1，而 `window.$` 为 undefined。应用探针补充了限定 `qryUserRes` 的 jQuery `ajaxSuccess` 观察器，从 `xhr.responseJSON` 获取已由官网转换的结果，以 `stage: officialDecoded` 传回，不调用官网 dataFilter，也不为结果虚构成功状态。官网公共业务脚本未发现禁用 jQuery 全局 Ajax 事件的设置；仍需成功登录后确认实际事件。Node VM 测试验证该观察器不替换或修改官方结果，以及原始 701 响应完整转发。

## 广电失败复核：不同 jQuery 实例（2026-09-30）

老板报告查询失败后，使用真实公开网页与本地拦截合成响应复核，证实上段的全局 jQuery 假设有缺陷：`window.jQuery` 3.5.1 不是官网业务实例，它没有业务 dataFilter/http；webpack module 0 的 jQuery 为 3.6.0，有 dataFilter 且 global=true。官网 `vendor-21074.js` 的模块0按 CommonJS `n(e,!0)` 导出，明确 noGlobal，不会把业务实例赋给 window。

在原应用探针下，使用业务 jQuery 发出被本地 route 接管的合成成功请求，官网 done/responseJSON 正确产生顶层 respCode + intfResultBean，但桥接只收到 raw，完全没有 officialDecoded。根接收逻辑不会用 raw 成功体更新余额，因此形成查询超时。测试与输出位于 `references/broadnet-public/failure-review/`。这是可复现的代码缺陷，尚不能断言用户设备没有额外网络或会话问题。

修复建议是在 document-start 观察同步 script load：polyfill 定义 webpackJsonp 后、vendor 注册模块0前，将注册函数做代理并保持原 this/参数/返回值；仅包装模块0 factory，在原factory自然执行结束后绑定 module.exports 的 ajaxSuccess。不主动重新发送请求、调用dataFilter或重建RSA。全局实例可以作为额外兼容，但必须支持多实例去重，不能绑定第一个全局实例后停止观察。官网当前加载顺序为 polyfill → vendor → common → 页面index，因此此方案具有源码依据，仍需浏览器验收。

另一个独立风险是原send在flutter_inappwebview.callHandler不存在时直接丢弃响应。插件明确提供 flutterInAppWebViewPlatformReady 事件，探针应短暂缓存限定接口的响应并在就绪时发送，设条数/大小上限；不要把就绪丢包伪装成运营商失败。现有Node mock一开始就注入可用bridge且只有单一jQuery实例，未覆盖这两种真实环境差异，必须追加对应回归场景。

根代理实现模块自然初始化观察与桥接缓存后，独立Chrome重跑同一公开网页合成响应：探针正确收到一次 officialDecoded，官网业务 done/responseJSON 的内容不变；随后发送的raw保留原包装。另在官网请求结束后才创建bridge并触发ready，缓存解码结果仍成功送达。两种浏览器复核均未使用用户账号，不能替代真机登录查询，但已验证所定位缺陷的修复路径。
