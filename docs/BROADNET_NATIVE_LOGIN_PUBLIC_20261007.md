# 中国广电 192 原生本机登录公开实现检索（2026-10-07）

截至本轮检索，没有找到可核验的公开开源应用实际通过中国广电 192 SIM 网关免短信取号、再取得广电营业厅登录会话的实现。检索把“读取当前数据 SIM 的号码并获得认证 token”作为必要证据；只接受 192 号码输入、做号段/三要素核验、短信登录、恢复已有网页会话，或认证互联网电视设备号码，都不算命中。此前广电官方 App 截图已证明第一方 App 存在本机登录；本轮只核查第三方公开实现，没有改变这一事实或重复推断 SDK 是否存在。

## GitHub 检索与直接候选

使用 GitHub CLI 搜索了仓库关键词 `"中国广电" "一键登录"`、`"192" "号码认证" 广电`，两项均为零仓库结果。代码搜索 `CbnAuthDialog`、`cbn_account_auth_privacy_text` 只命中本项目此前公开的研究文档，没有命中外部认证实现；`"中国广电" "本机登录"` 与 `"192" "SIM" "10099"` 也没有代码命中。`easy-login.10099.com.cn` 的代码搜索命中是代理软件的域名直连、跳过代理或 real-IP 配置，例如 [Repcz/Tool](https://github.com/Repcz/Tool/blob/X/Egern/Egern.yaml) 和 [mieqq/mieqq](https://github.com/mieqq/mieqq/blob/master/skip-proxy-lists.sgmodule)，这些记录只说明该域名被配置为直连，不包含登录 SDK、SIM 取号或账号回调。

直接相关的 10099 应用里，`keiraee/broadnet-panel` 是一个广电个人中心面板。它的 README 描述官网短信登录和 WAF 会话过期后的重新验证；[LoginView.vue](https://github.com/keiraee/broadnet-panel/blob/4ac86e3f7caccda14932c1e99ef703d1b4137b92/web/src/views/LoginView.vue) 明确显示手机号、图形验证码和短信验证码表单（第 82–87、96–134 行），[official-api-map.md](https://github.com/keiraee/broadnet-panel/blob/4ac86e3f7caccda14932c1e99ef703d1b4137b92/docs/official-api-map.md) 列出取图形码、发送短信和 `gwLogin` 步骤（第 6–10 行）。后端 [gateway.js](https://github.com/keiraee/broadnet-panel/blob/4ac86e3f7caccda14932c1e99ef703d1b4137b92/server/browser/gateway.js) 用 Playwright 打开官网登录页并预热 WAF Cookie（第 117–142 行），再调用 `getVerifyCode` 和 `gwLogin`（第 222–259 行）；这不是原生 SIM 网关认证。GitHub API 显示此仓库公开但没有 LICENSE 文件且 `license=null`，所以只归档必要源码供研究，没有把代码带入生产项目。

已有参考 [China-Broadnet-Flow-Keeper](https://github.com/FIONN191/China-Broadnet-Flow-Keeper/blob/main/README.md) 是 Chrome 会话恢复扩展。README 明确要求首次完成短信验证码登录（第 26 行）；扩展仅申请 `storage`、`tabs`、`scripting`，在登录页自动填手机号，并从官网 `sessionStorage` 备份或恢复会话。它没有 SIM 认证入口，也没有外部原生回调。仓库未提供 LICENSE，因此不能据此复制实现。

已有 MIT 项目 [10099-Tracker](https://github.com/BiancoCat/10099-Tracker/blob/main/README.md) 则让用户先登录微信小程序“广电流量查询”，再从抓包记录复制官方 `qryUserRes` 请求为 cURL；[main.py](https://github.com/BiancoCat/10099-Tracker/blob/main/main.py) 保存请求头和数据字段，并在认证失效时要求重新登录小程序（第 11、66、155–157 行）。这是手工复制已有会话查询，不是本机号码认证。

仓库搜索还命中 `ChinaTelecomOperators/ChinaBroadnet`。它有 GPL-3.0 LICENSE，但 Git 树只有 LICENSE 和 README.md，README 指向外部文档，没有可检查的 Android/iOS 登录应用或认证实现。它不构成本机 SIM 认证源码候选。

本轮新增归档只包含 `broadnet-panel` 的 README、登录表单、API 路径说明及前后端接线文件，来源 commit、Git blob SHA-1、本地 SHA-256、字节数、许可证状态和现有参考的本地 hash 都在 本地 `references/broadnet-native-login-20261007/public/index.json`（参考源码未重复上传，公开来源见链接）。没有重复下载已有 BroadnetFlowKeeper 或 10099-Tracker，也没有归档签名、私有配置或凭证。

## 四网号码认证候选筛选

公开 SDK 文档仍把若干常见号码认证产品限定为移动、联通、电信三家。例如[极光 JVerification FAQ](https://docs.jiguang.cn/jverification/FAQ/prod_faq)列出三家运营商；[个推 GeYan 文档](https://docs.getui.com/geyan/)描述整合三大运营商；[七牛 QNVS 产品介绍](https://developer.qiniu.com/qnvs/12483/number-verification-service-introduction)同样明确为三大运营商；[创蓝使用手册](https://doc.chuanglan.com/document/6CXESBI5BTWCITTL)的取号支持网络也只列移动、联通、电信。这里仅记本轮新增核查的文档；腾讯云和阿里云的既有结果仍以 `docs/BROADNET_AUTH_NATIVE_RESEARCH.md`、`docs/BROADNET_AUTH_OPEN_RESEARCH.md` 为准，不重复计为新发现。

华为云市场检索里有“支持广电号码核验”的项目，但其具体产品是运营商“三要素”核验：用户提供姓名、身份证号和手机号，服务方校验三项是否匹配。它没有声明通过当前设备的 192 SIM 取号。页面上另列的“一键登录—闪验”是独立产品；其供应商介绍列出与移动、联通、电信三家的合作关系，也没有广电 SIM 网关证据。[华为云市场候选页](https://marketplace.huaweicloud.com/series/4d2887b434e7427c820890b59b9f00bb-2-S)因此属于关键词近似命中，不是四网本机免密登录。

## 结论边界

公开 GitHub 检索到的广电个人中心应用只覆盖短信验证码登录、已有官网会话恢复，或手工复用微信小程序请求；公开 SDK 文档候选也没有给出可验证的 192 SIM 原生取号接口。没有找到同时具有正式授权的广电 SIM token、第三方 App 接入说明，以及将认证结果兑换为营业厅查询会话的开源实现。本轮结果不证明广电没有商业、合作方、内部或未公开 SDK，也不能把用户可在输入框键入 192、号码归属查询支持广电或互联网电视设备 SDK 当作证据。

验证只针对公开 GitHub 页面/Contents API 与公开产品文档，并对归档文件计算 SHA-256；没有执行上游程序或二进制，没有发起认证请求，没有测试手机号或设备，没有运行 Flutter/Gradle，也没有修改生产实现。当前可以确认的是“公开资料不足以接入”，尚无可声称完成的广电原生一键登录功能。
