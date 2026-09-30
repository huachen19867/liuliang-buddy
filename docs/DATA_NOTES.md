# 运营商数据解析说明

数据入口是应用内官方页面返回的响应。调用方必须先确认响应来自对应官方域名与接口，并在必要时解密、JSON 解码，再调用 `app/lib/data/parsers.dart`。解析器不处理 Cookie、Session、Access、手机号或原始响应的持久化；快照只保留脱敏号码、查询时间、明细名称、数值和状态。

中国移动参考项目 `references/ChinaMobileMonitor/ChinaMobileMonitor-main/chinamobile.py` 通过 Playwright 捕获 `wx.10086.cn` 的 `getNewMarginInfo`，必要时将十六进制 AES 响应解密。流量字段是 `data.resultData.planRemianFlowInfo`。`planRemian` 为通用，`directionalFlowInfo` 为定向，`otherRemian` 为其他，`totalInfo` 是官方总览。各项的 `remainNum`、`sumNum` 必须结合实际 `unit` 换算；参考实现中的 `03` 为 MB，`04` 为 GB。总览可能已包含各分类，解析器保留其原值但不参与通用余额求和。响应缺单位、缺剩余额或不是可识别结构时，不输出零余额。

中国广电微信小程序参考项目 `references/10099-Tracker/10099-Tracker-main/main.py` 请求 `https://wx.10099.com.cn/contact-web/api/busi/qryUserRes`，成功码 `000000`，明细位于 `data.intfResultBean.userResList`，字段包括 `itemName`、`balance`、`highFee`。参考代码直接将数值当 KB 换算，但小程序响应未见单位字段或实际响应样本来证实这一假设。`parseBroadnet` 仅在明细明确提供 `unit` 时换算成字节；否则保存 `rawRemaining`，字节余额留空并提示单位待确认。此规则仅适用于小程序响应，不应与官网 H5 响应混用。

广电官网 H5 的独立 `parseBroadnetH5` 依据 `references/broadnet-public/7-index-eba9b.js` 和 `6-common-85ed7.js`。官网查询地址为 `https://www.10099.com.cn/contact-web/api/busi/qryUserRes`。未登录响应实测保存在 `references/broadnet-public/unauthenticated-qryUserRes.json`，业务外层 `status="701"` 表示登录过期。官网公共脚本解开外层 `status="000000"` 后，把 `data` 交给页面；页面再次要求 `respCode="000000"`，读取 `intfResultBean.userResList`。应用的 jQuery 监听器可能直接收到解开的顶层 `respCode` 对象，因此解析器只接受“外层成功且内层成功”或“顶层业务成功”两种形式，不因 URL 命中或空对象自行宣布成功。

官网脚本以 `busiType="5"` 判定流量，以 `busiType="1"` 判定语音；流量名称为 `discntName`，剩余为 `balance`，总量为 `highFee`。官网对流量数值除以 1024² 显示 GB，证明该 H5 路径的原数单位是 KB。解析器仅处理 type 5，将 KB 换算成字节；语音、短信和套餐外计费列表都不参与。只有名称同时明确出现“流量”和“通用”的明细进入通用合计；包含“流量”且出现“定向”或“专属”的归入定向，其余保持未知分类，但各条仍保留名称和余额供界面展示。成功响应若没有可确认的流量条目，返回错误状态而不是零余额。

`QueryStatus.success` 表示接口结构被识别，不代表每个明细的单位都已确认。`generalRemainingBytes == null` 表示没有可验证的通用字节余额；`0` 才表示确认剩余零字节。HTTP 401/403 和明确认证失效提示归为 `authExpired`，其他非成功或结构未知归为 `error`。查询时间由调用方传入响应到达时间，未传时使用解析时的本机时间；它不是运营商账单生效时间。

广电官网登录页 `/login.html` 和查询页 `/personal-center-number-order.html` 已通过公开页面观察。普通安卓 WebView 完成真实登录、官网解密后的 jQuery 事件能否稳定捕获，仍需真实账号与真机实测。中国移动参考方案依赖 Playwright 浏览器捕获与解密，也未证明 Flutter WebView 能直接获得已解密响应。测试中成功数据为合成结构，未登录样本是真实公开网页请求；尚未取得真实成功余额响应。
