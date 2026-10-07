# 广电原生本机登录入口与外部授权契约补查（2026-10-07）

老板要求真正接通广电本机登录。本项负责公开 APK 的原生接入入口、账号协议 URL、对外 callback/intent、官方 App H5 宿主契约和 SDK 软件授权证据；同轮发现的新 `https://m.10099.com.cn/ssoserver/login.html` 由独立研究核验，不能用旧 App H5 的短信分支否定这个新 SSO 页面。这里的结论仅覆盖原生 SDK/官方 App 外部授权链：目前仍未取得可以接到本应用的正式广电账号 SDK 库、外部授权回传或营业厅查询会话兑换契约。

本轮先读 `TECH_LOG.md`、`BROADNET_AUTH_NATIVE_RESEARCH.md`、`ONE_CLICK_LOGIN_RESEARCH.md`，复用 `references/broadnet-native-auth-20261005/` 的广电官方开发者 2.3.0 商店 APK 及 `references/one-click-login-20261005/` 官方 H5 档案，没有重复下载已有安装包。新脚本、结果、来源索引和检索记录在 `references/broadnet-native-login-20261007/native/`。本项未改生产文件、未运行 Flutter/Gradle、未联系外部。

## 原生 UI 具体归属已经进一步定位

复用 APK 包名为 `com.ai.obc.cbn.app`，SHA-256 为 `f84bb1f003b9c86fb5357261ee08f6818d103cbf7a288196762a60ae667c8369`。新离线脚本读取全部 1415 份未加固 XML 资源的字符串池和有限类标识符，再由 aapt 交叉复核选中的 XML 标签，账号 UI 的四个 ID `cbn_account_brand_view`、`cbn_account_login_btn`、`cbn_account_login_text`、`cbn_account_phone` 出现在 `layout/activity_login`（`res/4y.xml`）、`layout/activity_login_old`（`res/eb.xml`）、`layout/activity_two_real_name_phone_jy`（`res/Za1.xml`）。前两者的标签都是系统布局/文本/编辑框，以及 `com.ai.obc.cbn.app.ui.other.widget.CountdownButton`；第三者是系统布局与文本。未从这些布局读到独立账号 SDK 的公开自定义 View 类路径。

这比单独发现 `style/CbnAuthDialog` 更具体：本机号码 UI 确实与官方登录及号码校验页面资源相连，老板截图中的“由中国广电提供认证服务”并非三网 SDK 推测。但系统控件嵌在官方 Activity 资源里不等于证明全部功能由官方自己实现，也不等于可以提取一个可用 SDK。加固的业务类仍未恢复、未执行。

具体库名目前只能可靠给出既有公开 ZIP/JNI 元数据：`libcipher.so` 有 `com/cbn/libcipher/CipherUtils` 标识符，是加密工具线索；`libblhttp.so` 的 `com.bestv.*` JNI 与 `sdkBestvLiveDetail` 等标识符归于视频模块；`com.cbn.videosdk.*`、`com.cbn.lib_video.*` 也只在视频布局或音频服务出现。以上均不提供本机账号认证 SDK 的初始化、预取号、用户授权和成功回调签名。不能把它们写入本应用的登录适配器，也没有读取或复制加密/签名实现。

## 老板授权手机安装版本补查

老板随后连接并授权根代理验证手机。根只拉取安装的 `base.apk` 到 `references/broadnet-native-login-20261007/device/broadnet-device-2.0.9.apk`，没有拉取用户数据。本项仅在文件完整后读取这个本地安装包，不调用 ADB。安装版本为 2.0.9/code209，81,715,648 字节；本项独立计算 SHA-256 为 `01fe5206378c40a6b159ac821c7a289e7941c617a0e9265bc0a7958e85f2c303`，与根记录一致。根的 apksigner 回执证书与商店 2.3.0 相同，为 `784c31c29f5888975442cfda784a95a5933e9c443807bb351183ff6757829a23`；本项没有将手机当前版本误写为商店 2.3.0。

复用既有三个可信离线元数据读器，按虚拟文件映射在内存读取 APK DEX、组件声明与 JNI/资源标识符，输出另存 `device-2.0.9-dex-metadata.json`、`device-2.0.9-manifest-metadata.json`、`device-2.0.9-sdk-candidate-metadata.json`，保留旧版结果。设备包仍为 `com.ashield.Stub` 加固壳，唯一 DEX 类型表仍只有 34 类型，没有公开账号 SDK 类型可恢复。1303 份 XML 资源仍有同名同路径的三个账号 UI 布局，账号标题与品牌文字一致；`libcipher.so` 仍只有 CipherUtils 候选，`libblhttp.so` 仍是视频 SDK。两登录 Activity 的外部暴露和唯一支付宝 URI callback 声明也相同。

较旧的实际安装版本因此没有补出 SDK、协议 URL、外部返回号码/会话的契约。首次读取时 pull 尚未完成，ZIP 尾目录不存在，脚本明确失败且没有生成元数据；待完整 ZIP 后全部离线读器成功。这是文件拉取时序问题，不把截断读取失败当成更强加固或官方格式问题。没有尝试解开壳、读取 app 私有配置、运行 DLL/native 库或使用任何真实用户会话。

## 账号协议 URL 与许可证仍有明确缺口

资源保留了精确标题《中国广电账号服务与隐私协议》及“由中国广电提供认证服务”。本轮全部公开 XML、资源表以及文件名指明为版权/协议的 assets 中，未读到与该标题对应的完整协议 URL；不能自行把标题拼成 easy-login 或 SSO 路径。公开 App H5 已有自有电子渠道隐私政策页 `https://app.10099.com.cn/h5-app/#/pages/detail/serviceAgreement/index?xyId=xy20220613000017`，但该标题和 SDK 授权页所示账号协议不同，不能用它冒充精确账号认证协议。

安装包中没有 AAR/JAR/POM 接入物，没有读到广电账号 SDK 原作者的发行许可证或第三方应用接入授权说明。`META-INF/com/android/build/gradle/app-metadata.properties`、Servlet/Jetty properties 文件只是通用构建/依赖元数据，不能充当广电账号 SDK 名称或授权证明。公开商店分发 APK 可以证明研究文件来源，不能替本应用签发 SDK appId、包名/签名配置或 SDK 使用权。这里的“未取得”并不是声称官方系统没有内部许可证。

精确互联网/GitHub 搜索 `CbnAuthDialog`、`cbn_account_auth`、`cbn_account_auth_privacy_text`、`com.cbn.libcipher` 与账号协议标题，仍未得到原作者公开 SDK 库、SDK 回调文档或许可证。`easy-login.10099.com.cn` 的第三方路由/DNS 配置命中只能提示域名被人用于联网排障，不能提供合法 SDK 契约；本轮没有请求其 `/http` 或任何取号接口。

## 外部原生授权入口不能由 Activity 名称补出来

既有 Manifest 元数据中的 `com.ai.obc.cbn.app.ui.other.activity.LoginActivity` 和 `LoginOldActivity` 都没有 intent-filter，也没有显式 `exported=true`。[Android 原作者 Activity 文档](https://developer.android.com/guide/topics/manifest/activity-element)明确说明，没有 intent-filter 时 exported 默认 false。因此在本应用这样的普通第三方身份下，连“显式按类名打开官方登录 Activity”都不是该包声明的外部入口，更不能指望从它返回号码或会话。未尝试启动或绑定这些组件。

本 APK 唯一带 URI data 的声明仍是支付宝 `com.alipay.sdk.app.AlipayResultActivity` / `__gdalipaysdk__`，与广电号码授权无关。没有 `android.accounts.AccountAuthenticator` action 或相应公开账号服务声明；全部五个 Provider 为 exported=false；可导出的 `com.asia.sip_ua.src.socket.SocketService` 无账号认证 action 或 Binder 文档，不能因 exported=true 就作为账号认证服务调用。这里只检查公开 Manifest 声明，不否定尚未公开的正式合作能力。

## 官方 App H5 bridge 的已知命令和未知回传

复核官方 `app.10099.com.cn` H5 已归档首页/主脚本，UA 中含 `CBN` 时 Android 使用 `window.android.nativeCall(JSON.stringify({type:"login"}))`，iOS 使用 `window.webkit.messageHandlers.nativeCall.postMessage({type:"login"})`。这条已见登录命令只有 type，没有向普通第三方调用者开放的 appId、returnUrl、state、callback 参数；已归档模块也没有可核实的第三方登录成功回传函数约定。普通浏览器的同一 App H5 分支使用站内网页登录弹窗或首页 `needLogin=1` 路由。此结论只指已归档 App H5，不能推广到新 SSO 页面。

官方页面发出桥接命令与本应用获得合法原生 SDK 是不同事实。伪造 CBN UA 会让网页调用本应用并不存在的官方宿主对象，无法自行补上 SIM 认证或会话兑换。实现一个同名 nativeCall 回调也只是实现命令接收端，不会得到广电服务端认证资格。若以后官方提供宿主接入文件，需要文件说明支持第三方宿主、各端包名/签名校验、用户授权页、成功/取消/失败回调以及营业厅查询授权的具体输出。

## 同轮独立 SSO 契约补充

独立研究 `BROADNET_NATIVE_LOGIN_CONTRACT_20261007.md` 已确认新 SSO 页面与自动回跳页提供“短信登录→ticket→COMMON_H5WAP_TOKEN”的网站交换流程，重定向目标须经服务端检查，并非开放任意回调。公共协议接口 `/ssoserver/api/getAgree` 与 `/ssoserver/api/getConceal` 分别给出第三方电子渠道服务协议与自有电子渠道隐私政策，没有返回截图中的精确账号服务与隐私协议。这补充了真实的网站 SSO 票据链，但没有补上原生 SIM 认证结果如何获准生成 ticket，且 COMMON_H5WAP_TOKEN 与本项目原网页 phoneInfo/sessionId 也没有已验证转换关系。因此不能把新 SSO autoLogin 页写成原生一键登录已接通。本项没有重复请求或下载该研究已经保存的资料。

## 可以实施的接线契约与本轮验收

目前原生侧只有 UI 标识、内部 Activity 名和一个官方宿主登录命令；没有可填写的正式 SDK 坐标/版本、初始化授权配置、成功 token 的定义、外部 callback URI、服务端验号接口、营业厅会话兑换和软件使用授权。本项目不能据这些元数据写出真实可工作的 SDK 接线，更不能虚构一个 SDK API 在生产中等待不存在的库。

后续找到正式入口时，接线必须能从本应用自己的授权配置出发，在广电支持的数据 SIM/终端网络中由用户确认掩码号码与协议，回调给出可验证且限定用途的认证结果，再按官方允许的契约兑换本应用可查询余额/套餐的授权。号码认证成功本身不能被记成营业厅查询会话有效；官方 App 的内部会话也不能由启动 App 自动共享。上述契约的名称、函数签名和字段尚未取得，因此这里只记录所需证据，不写假接口。

新离线脚本已实际成功执行，输出 1415 XML 资源的安全元数据、三个账号 UI 布局、域名和 SDK 发行元数据缺口；复核源 APK 散列与原归档一致。联网阅读器完成 Android 平台正文核验；本机直接 curl 下载该文档连接超时，在参考索引中明确记录，未把失败响应当成功归档。没有取号、登录、验证码、真实用户凭证或三日后再认证的真机测试。新 SSO 官方网页若证实能自身完成本机授权，会是独立的公开网页接线方案，应另据其真实脚本/回调验证，不能把这里的原生 SDK 缺口扩大成“广电没有任何一键入口”。
