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

## 联通官网协议新证据

后续深入直接浏览 `https://iservice.10010.com/e5/index.html` 与 `/e5/query.html`，正常获得“联通网上营业厅”业务HTML（未登录）。已下载 `references/carrier-public-deep/`；index.json记录资源原URL，unicom-protocol-excerpts.txt提供相关原文。此结果取代初查只有入口的限制。

HTML的query_info.personalInfo_back接收data.resource，页面在myE3LoginObj.isLogin为真、有userInfo且nettype为01/02/11时，自然执行 `E3QueryMain.loadData("/userinfoE5query",null,...)`。commonBase.js将请求组成为 `POST https://iservice.10010.com/e3/static/query/userinfoE5query?_=<毫秒>`，Content-Type application/x-www-form-urlencoded;charset=UTF-8，JSON响应，业务载荷null。这里没有参考APP的token、密码或自制签名；应让官网在用户登录后自然请求。

官网没有为该回调显示外层code成功判断，只要求data.resource；余量模板把resource.successFlow严格等于false视为失败，flowFlag为真才显示流量。resource.overFlow>0时显示超出，否则remainFlow>=0显示剩余；commonsFormat.getFlow源码明确输入MB，大于等于1024除以1024显示GB。hasNolimitedFlow且有userInfo时改显示usedFlow（已用），因此无限套餐不能把remainFlow当确定的有限余额。未见通用/定向分类或有限总量字段，不将其汇总误标为通用。

解析器应比网页JS宽松比较更严格：null/空字符串/布尔/非有限数值都拒绝，不让null>=0变为0；successFlow=false拒绝；flowFlag无效拒绝；不限量明确无法得到有限余额；超额值不得伪装成正剩余。不能凭空引入0000/701等APP或广电成功码。此协议尚未取得真实账号成功响应，所以外层缺字段仍应报无法识别。

登录检查来自baseTools.js：官网自然POST `/e3/static/check/checklogin/?_=`，读取data.isLogin及userInfo，使用nettype/provincecode/usernumber区分号码服务。可仅观察isLogin布尔辅助显示登录失效，无需把个人资料或Cookie传出页面。当前没有发现userinfoE5query自己的认证失败码，不能自行猜测。

若需要严格DOM后备，只在已核实的iservice.10010.com/e5/index.html或query.html、登录状态为真时读取可见的`#flowTemplateId .inforUl1 li`，要求左侧标签“流量”且右侧准确“剩余<number>MB/GB”。不能读取隐藏textarea#flowTemplate、营销页、已用、超额或语音分钟；无限套餐同样拒绝。公开HTML已确认这一结构，但DOM路径需真机验证，响应解析仍更可审计。

## 电信进一步尝试及当前边界

深入访问全国my189、上海查询页、广东首页、m.189.cn、北京/安徽省页、浙江移动页和wx.189.cn。浏览器按网站逻辑正常执行防护脚本，全国/省页初次412之后400空白，移动页直接400，wx.189.cn连接被关闭。没有跳过挑战、伪造登录态或发短信。证据在carrier-public-deep及telecom-public-deep的index.json。

进一步下载的WM9116/ahBot引用安徽微信小程序openid及`https://wx.ah.189.cn/wxws/xcxahwx/detailInfo.do`，仍非电信网页登录协议。由此不能确认全国或省分网页余额接口、单位、成功码或DOM选择器。电信目前只有登录入口证据，不能做扫描整个页面文本的泛化“剩余”识别并称自动接通；真实可识别的账务页面是实施前提。

## 电信进一步找到当前官网登录账务页面

GitHub历史代码搜索下载WeiEast浙江旧网厅脚本、CsuLogin，以及dompling/Scriptable的ChinaTelecom.js；来源与许可证在references/telecom-web-history/README.md。Scriptable存在明确WebView网页登录后空POST package_detail.do的路径，但当前浏览旧e.189.cn/index.do真实跳到 `https://e.dlife.cn/portal/web/index.html#/login`，旧API无账号GET/POST均403，不能按旧协议宣称接通。

继续阅读新站公开bundle取得当前业务证据。主脚本 `https://static.e.189.cn/portal/web/assets/index-JxtFhIuN.js` 配置 `getPackageDetail` 指向 `POST https://e.dlife.cn/gw/user/package_detail.do`，页面业务入参 `{data:"a"}`。官方Axios会用sessionStorage内homeArr参与签名加密，发送的不是原始a；响应也由官方interceptor解密，result=-12001时跳Login。应让官网执行完整流程，不复制密码处理/签名/解密，不凭空直接fetch。

公开 `Home-CbXUZRRH.js` 的Account组件在sessionStorage.isLogin存在时自然调用getPackageDetail。解码后result严格等于10000才保存数据，serviceResultCode等于字符串0才显示主流量项。主页面#commonBalance显示“已用流量”，usageCommon除1024显示M，不能拿来当剩余。

用户点击“查看”后显示 `#balanceModal`，其中 `.bill-list > .list` 逐条对应items[].items[]。`.bill-title`为ratableResourcename；`.end-time-text`为endTime；`.bill-balance[data-id="3"]`表示流量，内容为“已使用 <span class=blue-font>已用数值和单位</span> / 总量数值和单位”。底层usageAmount与ratableAmount的单位为KB，官网各自除1024后toFixed(2)，小于1024显示MB，否则除1024²显示GB，因此左右可能不同单位，没有千分位逗号格式化。模板没有轮播复制，仅两层明细遍历。

此结构可支持严格DOM候选：只允许e.dlife.cn/portal/web/index.html的已认证Home路由和特定#balanceModal容器，不读登录页/营销文字。要求用户手动点击“查看”，因为该容器默认v-show=false；读取可见条目并明确标记为官网显示值。对used和total分别解析单位，只有非负有限且total>=used、total>0才可计算剩余；超出、总量零、无限/未知哨兵不得猜测。官网脚本未证明不同套餐没有重叠，所得条目不能直接称通用总量。该计算也受官网两位小数显示舍入影响，无法声称与原始KB完全一致。

新证据推翻此前“电信只有登录入口”的阶段结论，提供了可实现的定向页面解析路径，但没有真实账号登录或余额核验。Home公开bundle可下载，不等于已验证所有账号/省份都支持这一账务组件。公开资源、HTTP记录与协议摘录位于references/dlife-public/，不含用户凭证。

补充结构核对：router中Home的path严格为`/`，即URL hash `#/`，不是`#/home`。Account中的#balanceModal无条件创建，只使用Vue v-show控制display，因此即使用户未点击“查看”，请求成功后仍可能已有已渲染明细。实现可以在已认证Home路由读取该指定容器的textContent而不自动点击，但应明确这是官网已渲染数据计算的估算值，不能声称用户已打开可见弹窗或存在官方剩余字段。已用与总量中间包含NBSP，解析需容忍Unicode空白。首页路由切换、会话失效或数据清空必须让旧DOM结果失效。

主bundle未导出Axios的Oe实例；导出的S是API方法对象ca。通过动态import精确hashed模块并包装getPackageDetail可理论观察Promise解码结果，但会耦合官网版本并修改共享对象，本次不建议为了观察而引入此路径，保守使用定向DOM即可。
