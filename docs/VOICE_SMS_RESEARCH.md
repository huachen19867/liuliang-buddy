# 通话与短信套餐余量协议研究

2026-10-01。已读取技术日志，复用先前下载的官网资源和 ChinaMobileMonitor MIT 参考；本次把可复核片段、来源 URL、原文件 SHA-256 和偏移保存到忽略目录 `references/allowances/evidence-index.json`。新执行的移动公开浏览器访问记录为同目录 `mobile-index.json`，查询页正常跳到登录页，没有输入账号、发送验证码或调用带身份的接口。以下结论是公开页面/参考代码证据，不是真实套餐数值验收。

## 联通：官网直接确认

来源是 `https://iservice.10010.com/e5/index.html`，已归档原文 `references/carrier-public-deep/0-1.html` 第 355 行起 `flowTemplate`，查询页 `1-1.html` 也有同一模板。现有自然响应 `POST /e3/static/query/userinfoE5query` 内的 `resource` 同时包含语音和短信余量，无需新增凭据接口。

整块余量组件在 `resource.successFlow == false` 时显示无法获取数据，因此即使字段名带 Flow，该失败门禁也覆盖本组件内的语音/短信。沿用当前严格来源、HTTP、登录检查；不要把缺字段当成功的零余额。

语音显示门禁是 `voiceFlag`：为真时先检查 `overVoice > 0` 并显示“超出 N 分钟”；否则 `remainVoice >= 0` 才显示“剩余 N 分钟”，剩余非法时是“--分钟”。flag 为假显示“无”，不是可计算的零余量。短信对应 `smsFlag`、`overSms`、`remainSms`，单位明确是“条”，但官网标题明确为“短、彩信”，所以产品可以放在短信区域，实际标题/范围必须标“短信/彩信”或“短彩信余量”，不得声称纯短信额度。

本模板没有确认语音/短信总量或已用字段，不能根据名字虚构 `totalVoice`、`totalSms`。`hasNolimitedFlow` 只用于流量，不可传播为通话/短信不限量。字段缺失、null、空串和 boolean 应排除后再解析有限非负数；不要模仿 JavaScript 将 null 自动比较成 0 的行为。短信条数必须整数。已经超出时保留“已超出 N”的状态，不能继续用旧的正剩余或把超出额当剩余。

## 广电：H5 单位和逐项含义已确认

来源为 `https://www.10099.com.cn/js/personal-center/number-order/index-eba9b.js`，原文在 `references/broadnet-public/4-index-eba9b.js` 及 `7-index-eba9b.js`。`queryUserRes` 的 `respCode == "000000"` 后取 `intfResultBean.userResList`；传输包装、H5 已解包两种情况继续沿用现有状态门禁。

官网 renderList 明确：`busiType == "5"` 为流量并从 KB 换算 GB；`busiType == "1"` 为“分钟”；其余类型仅显示“条”。对非流量，`highFee` 原值是“共”、`balance` 原值是“剩余”、`addupValue` 原值是“已用”，名称为 `discntName`。因此通话可以严格识别类型 1，数值直接以分钟展示，不能再除以 60。每项仍保留套餐名称、用途和有效范围，不把国内/国际/定向等不同规则明细宣称为通用通话总量。

当前公开源码没有显式定义短信 `busiType` 编码。特别不能只因“不是 1、不是 5”就把所有项分类成短信。可实施的保守规则是其他类型且 `discntName` 明确含“短信”或“短彩信/短、彩信/短彩”，并使用官网显示的“条”；名称只有“彩信”则不要当纯短信，名称不明确就不纳入短信余量。若业务希望按固定代码分类，仍需官网代码表或实际打码样本佐证，不能猜成 2。

H5 渲染没有语音/短信不限量的数字哨兵处理；不将 -1、大整数、999999 等改写成不限量。原始余量明确为“不限量/无限量”时可保留文字状态，不能换算成任何数值。`wx.10099.com.cn` 旧接口与这个 H5 的单位证据不混用：旧路径仍须显式 unit 或明确页面证据。

## 移动：可复用 MIT 实现证据，官网业务页未取得

已下载 `shiranzby/ChinaMobileMonitor` 的 `chinamobile.py` 第 174 行起给出 `UNIT_MAP` 与 `parse_margin`。它读取自然 `getNewMarginInfo` 响应的 `data.resultData`，语音对象为 `planRemianVoiceInfo`，明细键 `planRemian`、`otherRemian`、`totalInfo`；短信对象为 `planRemianMSGInfo`，明细键 `notePlanRemian`、`totalInfo`。每项 `remainNum` 是剩余，`sumNum` 是总量，`usedNum` 是已用；`unit == "01"` 映射分钟，`"02"` 映射条。

本次重新访问 `https://wx.10086.cn/website/spa/main/newHome`，302 到 `/website/bind/bindAccount/new`，获得正常登录 HTML 和公开登录 JS，没有业务页和带账号响应。因此这组证据来自已有 MIT 参考实现，不能写成运营商公开契约已验收。可以按已知结构、严格显式单位实现兼容解析，再通过用户真机与官方 App 对照验证。未知字段不递归遍历猜数字，缺单位不默认分钟/条。参考代码的缺值默认 0、缺单位默认 GB 不应复用。

`totalInfo` 已是汇总，不得与 plan/other 再相加。产品主位可优先取有效 `totalInfo`，没有汇总时展示套餐明细；若仅 plan 有值，标明“套餐内”。短信 `notePlanRemian` 不等同已确认所有短彩信总量。没有确认这两个对象的无限数字哨兵或秒单位代码，负数和异常大值不可自行转换成不限量。若未来响应带明确“秒”文本单位，可以按秒保留/精确换算分钟；当前 unit01 明确是分钟。

## 电信：官网固定 DOM 可扩展，但“次”不等于短信

来源为 `https://static.e.189.cn/portal/web/assets/Home-CbXUZRRH.js`，原文 `references/dlife-public/Home-CbXUZRRH.js` 的 Account 组件。`getPackageDetail` 返回 `result === 10000` 后保存套餐资源，模板遍历 `items[].items[]`，资源名 `ratableResourcename`，`usageAmount` 是已用，`ratableAmount` 是总量。单位函数明确 `unitTypeId == 1` 为“分钟”、`== 2` 为“次”、`== 3` 为流量。实际 DOM 为 `#balanceModal .bill-list .list`，内部 `.bill-title` 是名称，`.bill-balance[data-id]` 保存 unitTypeId，文字为“已使用 X单位 / Y单位”。

沿用现有 `e.dlife.cn/portal/web/index.html#/` 精确来源和 SPA 登录失效门禁，仅读已渲染的 Account 套餐组件，不访问加密接口、不扫描营销文本或登录短信验证码。语音可识别 data-id1 且分钟，并保留名称；数据为已用/总量而非直接剩余，所以 `总量 - 已用` 应标“套餐估算余量”，不能宣称官网直出的剩余。若已用大于总量，显示超出/未知，不能负数或钳制成假的零余量。

短信可识别 data-id2 且套餐名称明确是短信或短彩信，显示单位沿用官网“次”。其他次数资源（权益、服务调用等）不得混入短信；仅出现“短信登录”一类页面文本更不能使用。没有明确短信资源时显示未返回，不制造零。当前模板没有确认不限量标记；页面显示的未知、无限、缺总量或缺已用只保留相应状态，不作差。有效期可留在明细帮助解释套餐范围，不跨期相加。

## 共同实施约束

建议通话与短信作为独立 resource kind，保留 sourceLabel、unit、remaining、total、used、isEstimated 与 status；不能塞入 TrafficBucket.bytes 后再变更单位。短信/短彩信分类、分钟/次/条应保持可追溯。未返回、已超出、明确不限量、有限 0 是四种不同状态；旧快照没有新字段应兼容为未返回。

语音或短信有可信明细而流量没有时，可以形成套餐查询成功结果，但不合成流量余额；反过来流量成功不意味着通话/短信为零。新资源不能进入流量阈值提醒、流量 GB 汇总或流量桌面颜色。多个套餐可能共享额度，除非官方给出汇总，否则默认展示逐项或标注“明细合计、适用范围以套餐为准”。两个同运营商账号继续独立保存，不按运营商名称把两张卡额度加到一起。

最低回归应覆盖真正的零、字段缺失/null/空串、单位不明、totalInfo 与明细不重复求和、联通超出优先和短彩信标签、广电未知业务类型不能当短信、电信次数权益不能当短信以及仅通话/短信成功不伪造流量。没有真实账号验收，发布说明应保留这项边界。

## 2026-10-01 数据层落地记录

`app/lib/data/models.dart` 增加独立 `ServiceAllowance`、语音/短信类型、原始单位、超额及估算标记；旧快照缺少该字段时按空列表读取，复制快照时保留该字段。`app/lib/data/parsers.dart` 接入四家各自已经存在的查询来源：联通以 `successFlow` 为整块组件成功门禁，`flowFlag` 为假但语音/短信有效时仍能结束查询；移动只接受语音 `unit=01` 和短信 `unit=02`，优先采用合法 `totalInfo`，否则按明细逐项保留，绝不叠加汇总与明细；广电 H5 仅把 `busiType=1` 当分钟，其他非流量项目必须有明确短信名称才按条；电信只按探针给出的账务行、名称与同单位已用/总量作差，保留“次”或“条”并标估算。四家都允许只有可信通话/短信结果、流量桶为空的成功快照；未取得账号真值，结果仍需与官方 App 核对。

数据定向测试在 `app/test/data/allowances_test.dart`，覆盖零、缺值、旧缓存、超额、仅通话/短信、移动汇总回退、广电未知类型、电信短信 19 次与权益排除。格式化与 `git diff --check` 已通过；完整 Flutter 测试和静态分析由主任务串行执行并记录最终回执。
