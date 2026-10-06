# 中国广电原生本机认证公开资料核验（2026-10-05）

老板提供的中国广电官方 App 截图已经证实存在“本机登录 / 短信登录”和“由中国广电提供认证服务”。本轮取得了官方开发者在腾讯应用宝分发的 2.3.0 Android 安装包，并补查公开元数据和外部回调声明。结论仍是：功能存在，但本轮不能可靠给出其本机认证 SDK 名称，也未取得可授权给本项目的接入库、SDK 回调文档或营业厅会话兑换协议。这不是认定广电没有认证能力。

本轮先读 `docs/TECH_LOG.md`、`docs/ONE_CLICK_LOGIN_RESEARCH.md`，复用 `references/one-click-login-20261005` 的官方网页和版本证据，没有重复下载原有研究。新增资料位于 `references/broadnet-native-auth-20261005/`，来源、文件散列和限制记在同目录 `index.json`。仅修改本研究文档与研究目录，未修改 Flutter、Android、iOS 生产文件，也未运行 Flutter/Gradle。

## 取得的安装包与来源

广电公开移动客户端下载页为 [中国广电客户端下载](https://m.10099.com.cn/cbn_client_download.html)，其脚本通过同站 `GET /contact-web/api/version/selectAppVersionGW` 取得版本和下载 URL。本轮重新取得该匿名版本响应，仍为 Android 2.3.0、versionCode 230、2026-09-18 更新。响应指定的官方 CDN APK URL 本轮返回 HTTP 404；错误响应保存为 `official-apk-not-found.xml`。这说明当前这个分发地址不可用，不说明 App 不存在。另从 `www.10099.com.cn` 重取版本接口收到 HTTP 200 的 WAF HTML，因此另存为 `version-current-waf.html`，没有把它当 JSON 成功。

随后使用 [腾讯应用宝公开详情页](https://sj.qq.com/appdetail/com.ai.obc.cbn.app) 和 [公开移动下载页](https://a.app.qq.com/o/simple.jsp?pkgname=com.ai.obc.cbn.app) 已声明的直链，下载 `broadnet-store-2.3.0.apk`。详情页开发者和运营者均为“中广电移动网络有限公司”，包名 `com.ai.obc.cbn.app`，版本 2.3.0。[魅族官方软件商店](https://app.meizu.com/apps/public/detail?package_name=com.ai.obc.cbn.app) 的公开元信息亦列相同开发者、包名、版本和更新时间，但未从它下载安装包。

APK 为 87,336,250 字节，SHA-256 `f84bb1f003b9c86fb5357261ee08f6818d103cbf7a288196762a60ae667c8369`，MD5 `a96cdf35821fe0408a3a1fc13270933b` 与应用宝公开下载元信息一致。Android 官方构建工具 `aapt dump badging` 读到包名 `com.ai.obc.cbn.app`、versionCode 230、versionName 2.3.0、minSdk 21、targetSdk 33，ABI 为 arm64-v8a 与 armeabi-v7a。`apksigner verify --print-certs` 成功，证书 SHA-256 为 `784c31c29f5888975442cfda784a95a5933e9c443807bb351183ff6757829a23`。有效签名及商店散列一致用于证明本轮读到的确是该分发文件，不把签名有效单独当作开发者身份的独立证明；官网失效 URL 未能提供第二份 APK 作字节比较。

## 原生 SDK 识别的实际边界

这个 APK 的 Manifest Application 类是 `com.ashield.Stub`，安装包内存在 `libashield.so`、`libashieldAdapter.so`、`libvmc.so`。唯一根 DEX `classes.dex` 虽有 13,702,468 字节，但可读 DEX 类型表只有 34 项，内容为 `com.ashield.Stub` 与 Android / Java 系统类型。没有可读的营业厅业务或本机认证 SDK 类型目录。这些共同支持“业务代码受加固保护”的判断；本轮没有执行 APK、加载其 native 库、脱壳或恢复被保护代码。

因此没有查到 `com.cbn`、移动 / 联通 / 电信认证 SDK 的可读 DEX 类名，不能据此反推“不含这些 SDK”，更不能从商店包名的 `com.ai` 推定供应商。APK 内的视频 SDK、旷视、支付宝和 WebView 类名不能充当本机号码认证 SDK 证据。本轮没有从 `libsign.so`、`libcipher.so` 等名称猜测供应商或读取认证签名实现。

`read-dex-metadata.cjs` 只读取 DEX 类型描述符，不输出字符串常量、字节码或认证实现；`read-manifest-metadata.cjs` 只保留白名单内的组件名、exported 和 intent-filter 信息，不保存原始 Manifest 配置或 meta-data 值。结果分别为 `dex-metadata.json` 和 `manifest-metadata.json`。私有 AppID、密钥、营业厅令牌及签名代码均未提取、输出或复制。

## 2026-10-06 继续主动追查的 SDK 线索

老板要求继续自行查找后，本轮继续阅读 APK 的 ZIP 条目名、资源表，以及原生库 ELF 动态导出名；没有在加固包处停止。新增 `read-sdk-candidates.cjs` 在内存中读取压缩包内的原生库，只输出 JNI 类名、受限的类标识符和 URL 域名，不拆出 native 文件，不输出 URL 路径/参数、私有常量或函数实现。安全元数据保存为 `sdk-candidate-metadata.json`。

资源表有 `style/CbnAuthDialog` 和 `string/cbn_account_auth_privacy_text`，后者显示《中国广电账号服务与隐私协议》；关联资源显示《自定义服务协议》《用户隐私政策》《用户服务协议》。`string/cbn_account_brand_text` 的实际显示文本为“由中国广电提供认证服务”，与老板截图一致，另外存在 `cbn_account_logo`、`cbn_account_phone` 等资源名。这给出“广电账号认证”及上述精确协议标题的定向检索线索，不能单独证明一个名叫 CbnAuth 的公共 SDK 已对第三方开放。资源表内的 URL 域名只有 GitHub 与 Zetetic 数据库项目网站，没有认证门户。

动态导出进一步排除了容易误认的 `libblhttp.so`：JNI 类名为 `com.bestv.*`，导出包含 `sdkBestvLiveDetail`、`sdkBestvVideorate` 等视频/播放能力。这里的 UserLogin 名称不能被当作广电 SIM 取号。`libcipher.so` 的受限类标识符为 `com/cbn/libcipher/CipherUtils`，仅能说明广电命名的加密工具库；没有证据把它等同于本机认证 SDK，更没有复制其实现。`libmsec.so`、`libsign.so` 的动态导出及受限标识符扫描未给出可定向搜索的认证 SDK 类名或公开域名。

`libvmc.so` 可见本 App 的一些 Java 类标识符，但没有直接可读的认证 SDK 类路径；其中 `com/ai/obc/cbn/live/CBNLive$CBNLoginCallback` 位于直播模块，不能作为本机认证回调。没有将标识符扫描转为反汇编、脱壳或私有流程复制。对 `CbnAuthDialog`、`cbn_account_auth`、广电账号和协议标题的公开精确检索，本轮未取得正式认证 SDK 文档；可继续与其他公共资料线索交叉核实。

## 外部登录回调是否已找到

Manifest 声明了本 App 自有 `com.ai.obc.cbn.app.ui.other.activity.LoginActivity` 和 `LoginOldActivity`，二者没有 intent-filter 声明。本轮解析出的唯一带 `data` 的 intent-filter 位于支付宝 `AlipayResultActivity`，scheme 为 `__gdalipaysdk__`。它属于支付宝回调，不能作为广电号码认证或营业厅登录回调。

这只说明本 APK 的静态声明中没有取得可供第三方使用的广电登录回调，不能证明所有服务端、动态入口或正式合作接口均不存在。没有尝试显式拉起内部 Activity，也没有把官方 App 的成功登录状态复制到本项目。

2026-10-06 另核对 Android 系统账号共享路径：Manifest 未声明 `android.accounts.AccountAuthenticator` action 或对应 meta-data，亦没有其他账号认证 Service 意图声明。全部 5 个 Provider 均明确 `exported=false`，没有公开账号认证 Provider。8 个 Service 中唯一明确 `exported=true` 的是 `com.asia.sip_ua.src.socket.SocketService`，没有 intent-filter、账号认证 action 或公开 Binder 契约；按 SIP/音视频模块的类路径，它不能作为广电本机号码认证入口。其余 Service 为更新、旷视录屏、Room、音频和投屏等组件，也没有账号授权声明。这里没有尝试绑定任何 Service、调用 Binder、读取 AccountManager 账号或凭证；仅凭一个 Service 可导出不能推定有可合法复用的认证接口。

此前官方 H5 的 `nativeCall({type:'login'})` 是 H5 与官方 App 宿主之间的桥接命令。它没有自动成为外部 App 的 SDK，也没有给本应用提供本机号码 token 或营业厅会话回传契约。本轮静态组件证据与既有 H5 分支相容，但不足以补出受保护原生实现的 SDK 调用流程。

## 公开正式接入与当前缺口

阿里云 [号码认证方案管理](https://help.aliyun.com/zh/pnvs/user-guide/number-certification-program-management/) 公开文档明确其号码认证只支持移动、联通和电信，当前不支持中国广电，包括 192 号段。[H5 客户端接入](https://help.aliyun.com/zh/pnvs/developer-reference/h5-client-access) 的回调运营商列表同样不含广电。[腾讯云号码认证 FAQ](https://cloud.tencent.com/document/faq/1415/53464)（页面标注 2026-02-02 更新）对“是否支持广电号码”给出不支持。因此不能以这两家的现有号码认证 SDK 直接实现老板截图中的广电本机认证，也不能用一般“支持三网”的宣传推定广电已支持。

这些事实来自联网阅读器实际提取的官方文档正文。直接 curl 保存的腾讯页面是脚本验证响应，阿里云 HTML 不完整包含上述正文，资料索引明确这一区别，不能仅凭 HTTP 200 宣称本地 HTML 已完整归档。`official-sdk-support-notes.md` 保存可核查的来源和转述，未把搜索摘要伪装成客户端 SDK 的验证结果。

公开 [open.10099.com.cn 合作商门户](https://open.10099.com.cn/) 的检索结果指向“中国广电增值业务合作平台”，有入驻流程和资质要求；本轮匿名获取只是 SPA 外壳，没有取得号码认证 SDK 文档。这个合作门户的存在不等于其提供本项目需要的营业厅查询授权。本轮没有注册、登录该门户或发送合作申请。

后续能正式落地，需要广电或其明确授权的供应商提供支持广电数据 SIM 的原生 SDK 名称、正式 AAR / Maven 或 iOS 库和版本、公开授权页及成功/失败回调契约，并给本应用签发自己的包名/签名或 Bundle ID 配置。如果认证 token 只证明号码，还需要明确允许本应用兑换营业厅查询授权或调用余额/套餐查询 API 的协议、接口和回调。SDK 服务开通主体资格、支持终端和网络、双卡行为、服务端验号方式、费用及授权周期也须按该真实产品的材料核实，当前资料没有统一答案。

没有这些材料时，新增一个本应用“一键登录”按钮不能宣称已接通，也不能复制官方 App 配置来填补缺口。当前可以保留已获正常官网登录授权的会话保存恢复改造；本机认证本身是否能重新授权和怎样带回营业厅会话，仍是尚待正式接口证明的独立工作。

## 验证与遗留限制

已完成公开版本响应、商店开发者/包名核对、APK 字节散列和签名验证、Manifest 组件/intent-filter 解析以及 DEX 类型元数据读取。研究脚本实际执行成功。APK、DEX 和 native 库均未作为程序执行；没有真实 SIM 取号、认证、验证码、账号凭证或资费请求，没有声称三日会话失效已经解决。

遗留限制是 SDK 身份被加固边界遮挡，且正式第三方 SDK 和营业厅授权文档仍缺。本轮交付的是比先前网页研究更具体的原生公开证据和可实施前置条件，不是已经可运行的广电一键接入。
