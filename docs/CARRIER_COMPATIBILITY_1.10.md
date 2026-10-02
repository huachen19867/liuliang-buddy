# 三家运营商查询兼容复核

2026-10-02。老板反馈联通停在 PC 版 mallLogin、电信官网可见余量但首页一直连接、移动流量和话费均不显示。先复核 TECH_LOG.md、此前公开官网源文件及 ChinaMobileMonitor、ChinaUnicomMonitor、FlowLite 参考，新增匿名移动视口浏览记录 references/carrier-compatibility-20261002/。没有输入号码、发验证码、登录真实账号或抓取他人凭证，未把匿名失效当作真实余量修复完成。

## 联通

当前 mallLogin 在 412px 移动视口和 Android UA 下依然为 PC 页面，但保留“密码登录”和“随机密码登录”两个官方入口。hallLogin 是给页面内登录用的入口，本次匿名页面只显示密码登录，不能作为已验证更好用的移动替代。没有擅换 URL 或自动触发短信、拼图验证。UI 应让“查询流量”按钮文字与说明一致，并清楚说明“随机密码登录”是官网短信入口。

旧 E5 初始化修复的同步 XHR 风险已消除：unicom_official_query.dart 在调用原 sendRequest 的同步代码期间，临时包装官网同一 jQuery.ajax，只准精确旧会话 POST 请求，以 async=true 和 12000ms timeout 派发后立即 finally 恢复 ajax。保持原 success 回调先执行，服务端 isLogin、官网对象均严格 true 且网别匹配，才调用原余量方法。没有复制认证算法、读取凭证或自行构造认证请求。其他路径不执行，函数缺失或已有状态不碰。正常官网匿名实测 evaluate 在 62ms 返回，连续两次执行仅产生一次 HTTP200 的脱敏未登录事件；这是非阻塞及去重验证，不是登录后余额验证。

ChinaUnicomMonitor 明确依赖官方 APP token_online 或抓取的 Cookie，流量 API 属于 m.client.10010.com；FlowLite 公开代码依赖抓包，部分抓包实现已注释且 README 说明商业模块未公开。它们不能证明当前网页登录拥有相同认证态，也不能直接移植地址就能查询。未增加抓包/VPN/短信权限。系统短信流量校准属于独立运营商短信交互和系统权限能力，不能以手机系统已有功能宣称本项目已支持。

## 电信

当前公开 Account 模板仍以 #balanceModal .bill-list > .list、.bill-balance[data-id] 展示套餐，用量和总量直接取官网已解密渲染数据；通用路由为 /，没有已验证的 /home 别名。探针严格区分 login，未放宽为任意页面文本。官方账号页面使用跨域 open.e.189.cn 登录 iframe；这是官网认证，不能把父页面可加载当成登录已完成。

找到并修复两条本地可证丢数路径。原 MutationObserver 每次变化重置 300ms 定时器，持续无关 DOM 更新可令扫描无限推迟，现改固定扫描窗口。原脚本重复注入直接返回，而且 body 发送后 previous 去重，即使 native 尚未处于查询状态而丢弃该事件也不再发送；现重复注入会执行显式 rescan，清发送去重并重新读取当前 DOM，绝不重放缓存正文。main/background 应在电信用户查询及 onLoadStop 需要时 evaluate 同一脚本；已有桥接延迟队列仍有效。无明细/不支持 DOM 的情况必须由 native 超时退出连接中，不能伪造空余额成功。

## 移动

当前 wx.10086.cn/website/bind/bindAccount/new 的正常匿名移动页面存在号码、获取验证码、协议和登录控件，没有找到应换入口的证据。parseMobile 至少要求可确认的流量或有效通话/短信数据，纯空响应不会成功。此前仅通话/短信有效时 status=success 却 message=null，容易被解读为流量已连接；现明确“官网仅返回通话或短信余量，尚未返回可确认的流量额度”。有效结果仍写 queriedAt，失败保持无新查询时间，由主页面保留历史记录。

话费缺失还存在明确功能边界：当前只捕获 getNewMarginInfo，余额通常属于另一个 accountFeeBalanceQuery/fareBalance 请求，未接入。参考监控脚本对 curFeeTotal/realFee 的处理也不同，不能把实时费用、欠费或套餐余量当余额，更不能猜单位。现有匿名官方资料未证明当前成功话费响应的完整字段与金额单位，故没有编造 balanceYuan 或放宽来源。需要正常登录页面的明确金额标签或真实已脱敏响应才能增加该字段。

## 验证与接线

联通 Node 合成 10 组通过，覆盖严格页面、旧状态、原回调、异步派发、12 秒限时、恢复 ajax、异常与重复调用。电信真实 Chrome 全本地合成回归新增持续变化和显式重扫，不访问账号。Dart parser 新增移动仅通话测试，交根代理统一 SDK 验收。本代理不修改 main/background，不运行 Flutter/Gradle。仍无三家真实登录后的新增成功验收，不能发布“全部运营商已修复”的结论。
