# 双卡流量助手技术日志

## 2026-09-30：需求确认与方案调研

用户目标：在一个简单的安卓 APP 中查看中国移动、中国广电两张卡的剩余流量，减少重复登录官方 APP 的操作。两张卡装在同一部手机，允许首次验证两个号码，登录失效后再次验证。

工作区初始为空，没有已有项目或技术日志。本文件作为技术日志入口；目录与运行方式维护在根 README.md。

实施顺序：检查开源查询和用量监测项目；确认登录与查询协议；实现双卡首页、刷新、状态说明与提醒；完成可执行的验证并记录尚需真机与真实账号确认的部分。

数据原则：运营商查询结果才是套餐剩余量；手机本地计量只可作为估算。显示来源、查询时间与登录状态，不将演示数据当作真实数据。运营商查询和后台任务有延迟，不能承诺秒级账单实时同步。

参考候选：shiranzby/ChinaMobileMonitor（MIT，浏览器登录与多号码查询），BiancoCat/10099-Tracker（MIT，广电自托管查询），itsdrnoob/DataMonitor（GPL-3.0，安卓本地计量，仅技术参考，不直接复制代码）。源码集中放在 references/，主项目与参考源码分开管理。

### 首版实现与用户偏好

用户补充要求 UI 可爱。Flutter 3.44.8 已安装，采用原生安卓 Flutter 应用，首页为奶油背景、蓝色移动卡、蜜桃色广电卡和自绘笑脸水滴；没有申请读取短信或 SIM 卡权限，卡片以运营商标记，不虚构物理卡槽。

依照用户的协作要求，分别由 Astra 轻度核对协议与实现网页探针，GPT6 SOL 高实现数据模型及解析器，GPT6 Luna 极高实现 UI 与布局验证。根代理负责集成、生命周期、会话存储、通知与构建。调研详情在 PROTOCOL_RESEARCH.md，数据限制在 DATA_NOTES.md。

移动官方页面登录与同页请求捕获支持 getNewMarginInfo；AES-CBC 解密参数来自 MIT 参考实现。广电小程序参考代码不能直接证明网页登录可行，新增官网扩展线索后，通过 Chrome 正常执行官网 WAF 获取公开 H5 查询页脚本，证实官网调用 www.10099.com.cn 的 qryUserRes，流量 busiType 为 5，discntName 为名称，balance/highFee 按 KB 转换。官网 jQuery 会先完成数据解密，因此探针观察 ajaxSuccess 的已解码 responseJSON；没有手工调用 dataFilter 或复制官网 RSA 代码。真实未登录响应 status 为 701，须显示重新验证，不能当零流量。

业务成功响应与未确认单位分开处理；未知用途不合并为通用余额。查询时间显式展示，过期/断网可显示上次数据但不会进入当前双卡汇总。独立 DEMO 编译参数仅用于预览，顶部标记“界面演示 · 非真实流量”；正式测试包不启用 DEMO。

WebView 在首页时保持状态以减少重复登录；前台五分钟、进入前台以及手动按钮触发查询，没有实现 APP 关闭后的持续监控。广电必要 sessionStorage 字段备份进入系统安全存储，七天上限不代表官网保证有效期；登录页不恢复或再次备份旧会话，官网拒绝时清除。清除数据时先停止请求、卸载旧视图并提升世代编号，通过回调校验和串行存储阻止旧网页写回凭证。

### 环境与踩坑

工作区原本没有 Android SDK 或 JDK。构建依赖集中在隐藏 .tools/：Microsoft JDK 17、Google Android SDK（API 36，平台工具、构建工具与按需 NDK）、Gradle 9.1.0。官方 Gradle 下载在本机网络超时，镜像下载后核对官方下载地址提供的 SHA-256；Gradle 插件仓库部分 TLS 连接失败，scripts/gradle-mirrors.init.gradle 仅对这次构建增加依赖镜像，不改变系统全局设置。

Flutter 当前模板使用 AGP 9.0.1，稳定版 flutter_inappwebview_android 1.1.3 仍引用已被禁止的 proguard-android.txt，配置阶段会失败。将同版本依赖副本集中放在 app/vendor/，仅把两处默认规则改为 proguard-android-optimize.txt，通过 dependency_overrides 使用并保留 LICENSE；没有改共享 Pub 缓存。维护说明在 app/vendor/README.md。

Widget 预览截图的 toImage 需要在 tester.runAsync 中执行，直接在虚拟时间中等待会挂起。测试时加载系统中文字体与 Flutter MaterialIcons；字体未打包进 APP，避免字体授权与体积问题。预览图存 artifacts/ui-preview.png，使用演示样本。

已完成数据解析、传输解码、网页探针请求保真、初次打开与提醒设置和 UI 小屏/大字布局验证。最终完整测试与 Android 构建结论待交付前记录。真实号码、各省套餐、会话有效期、真机网页兼容和安卓通知尚未验证。

### 广电 H5 接通与完整自动验证

广电采用与小程序独立的 parseBroadnetH5：允许官网 jQuery 解包后的 respCode=000000 或外层 status=000000 搭配内层业务成功门禁；status=701 表示会话过期。只纳入 busiType=5 的流量明细，使用 discntName、balance、高额度 highFee，并按照官网自己的公式确认 KB 单位。语音和短信排除。原小程序解析器保留供参考，但没有用不明单位产生 GB。

原始 XHR load 事件可能晚于 jQuery 的已解密 ajaxSuccess。根代理只用广电原始事件确认认证失败或 HTTP 错误，不让加密原始体覆盖已经取得的成功余额。探针限定接口与官方来源，保留官网请求的 Promise、返回对象和参数，没有重复发送查询。

完整 flutter analyze 通过；flutter test 全部 20 项通过（10 数据/模型，4 解码/会话脚本，5 UI，1 首次打开与提醒设置）。Node VM 的请求保真、广电原始与解码事件、来源/iframe/其他接口隔离验证通过。中文预览图已逐项查看，不是原始字号方框图，也没有遗漏 MaterialIcons 字体。预览的流量明确为演示样本。

安卓原生编译再次遇到 Windows 多盘符问题：Pub 缓存在 C:，项目在 D:，Kotlin 增量缓存的 relativeTo 抛出 different roots 并导致 SharedPreferences 编译失败。项目内 android/gradle.properties 使用 kotlin.incremental=false，关闭这一编译缓存路径转换，不搬动用户缓存或删除任何原文件；只影响构建效率，不改变运行行为。

flutter_secure_storage 11.2.0 的 JNI 构建需要 CMake 3.22.1，已通过 Google SDK Manager 安装。Ninja 无法可靠处理中文用户名下的原生构建目录，读取 C:/Users/陈化/... 会因路径编码报不存在。将锁定版本中使用的 77 个依赖包复制至 .tools/pub-cache/，不复制缓存中的 .cxx/build 等生成文件，不移动或删除原始缓存；以该 ASCII 路径重新 pub get。构建脚本使用任务范围 PUB_CACHE，避免全局环境变量变更，同时保留当前安全存储版本而没有为编译降级。

### 交付结果

Android 构建成功（assembleDebug），输出 artifacts/liuliang-buddy-debug.apk；未设置 DEMO。应用名“流量小伙伴”，版本 1.0.0，minSdk 24/targetSdk 36，主要供 ARM64 安卓手机个人测试。大小 89,463,314 字节，SHA-256 为 80c9125cd82923f6aee85b0a8a1c992bc37fb38e297bfa6818ba64a9d8c0e7bf。apksigner verify 通过 v2 签名，证书为 Android Debug；aapt2 检查名称、版本与 SDK，权限为网络、通知及 AndroidX 内部接收器权限，没有读取短信或卡槽权限。记录存于 artifacts/apk-signature.txt、apk-metadata.txt 和 android-build.log。

可交互 Web DEMO 构建成功，存 app/build/web/；静态图 artifacts/ui-preview.png 来自实际 UI 组件，用演示样本并显著标注。20 项完整 Flutter 测试、静态分析和 Node 请求保真检查通过。ADB 没有连接设备，未验证真机安装、两个号码登录后的成功余额、后台系统限制或通知投递。交付为可安装测试版，不能把公开脚本证据与模拟响应测试说成真实账号验证。后续须在用户自己的手机上比较官方余额与 APP 查询结果，登录操作无需把凭证发到聊天。

## 2026-09-30：桌面卡片与 GitHub 发布

老板补充了手机桌面天气卡片截图，希望亮屏就能直观看信息，并明确要求完成后上传 GitHub。延续安卓双卡应用目标，新增系统原生桌面小组件，参考其圆角、大数字和轻盈透明层次，保留蓝色移动、蜜桃广电。参考 Google 官方 AppWidget 示例，精选源码与 Apache-2.0 许可放 references/android-widget/，方法核对见 docs/WIDGET_RESEARCH.md。

由 Astra 轻度研究官方 Widget 与固定入口，GPT6 SOL 高实现 AppWidgetProvider、RemoteViews 和状态格式化规则，GPT6 Luna 极高接入 APP 添加卡片入口与预览。根代理负责 MethodChannel 桥接、应用生命周期/缓存同步、manifest、固定请求和 GitHub 交付。

桌面显示最近一次查询数据，更新时间保持原值；查询失败或登录过期保留旧值但显示失败/待验证，不虚构最新余额。专用通道 cn.liuliang/widgets 只传展示字段，在本应用私有存储保存，不传手机号或凭证。成功解析、加载、失败、设置变化与清除时同步，旧世代回调不能恢复已清除的卡片缓存。卡片点击携带 widget_refresh，兼顾应用冷启动与已打开状态，进入首页并按既有官网会话刷新。

Android 7/API24 可手工添加，API26 起按 Launcher 的 isRequestPinAppWidgetSupported 请求桌面确认。requestPin 只表示已申请，不能宣布用户已添加；不支持时给长按桌面手工添加说明。updatePeriodMillis=0，卡片本身不后台联网；这是缓存卡片，不承诺亮屏自动刷新运营商账单。桌面样式和宿主尺寸仍需实际手机验证。

版本更新为 1.1.0+2，构建脚本从 pubspec 读取并同步 local.properties 的版本，避免直接 Gradle 构建留下 1.0.0 版本。完整 Flutter 测试扩展到 24 项，通过；静态分析与 Node 探针验证通过。原生展示测试和最终新 APK 签名待构建结束记录。

GitHub CLI 已登录 huachen19867，原目录没有 Git 仓库，已建立 main 分支本地仓库。可选问题说明默认创建私有 liuliang-app；若无更改按该默认上传。发布包含源码、测试、许可与说明、UI 图；.tools/、原始参考项目、缓存和 APK 排除，安装包放 Release。后续记录实际仓库、commit、Release 与检查结果，不能把准备工作说成已上传。

### 桌面功能最终核对

原生 5 项 JUnit 全部通过，覆盖失败保留原时间、过期状态、无时间隐藏余额、用途未知不触发通用低量警告与本地时区显示。正常缓存状态用“上次记录”，最小缩放为 260×120dp；不依赖背景计时重新绘制，查询时间始终可见。Flutter 24 项及 Node 探针已经通过；Web DEMO 构建成功。最后检查修正了 APP 关于页仍称“桌面组件暂未实现”的旧说明，重新生成安装包。

GitHub CLI 不自动使用 Windows 系统代理；直连超时会让 gh auth status 错误报告 token invalid。按系统已有 127.0.0.1:7897 代理设置此次命令的 HTTP_PROXY/HTTPS_PROXY 后，gh api user 正常返回 huachen19867/185322589，未刷新或更改凭证。后续 Git push 也仅为命令指定代理，不写全局 Git 配置。

最终 1.1.0/code 2 APK 成功生成，89,496,179 字节，SHA-256 为 72a57ebaa68dec4811e212416665cf7c810fb2a37dbe56976759708bb10bd520。apksigner v2 验证通过，aapt2 已确认名称、版本、API24/36、权限与非导出 Widget receiver。插件附带其他 ABI 库，但 libflutter.so 仅为 arm64-v8a，所以交付明确限定 ARM64 手机。没有真机或实际运营商账号验证。

已创建私有仓库 https://github.com/huachen19867/liuliang-app，并用 gh repo view 核对 owner 和 isPrivate=true。暂存范围为 299 个应用、测试、依赖许可、脚本及说明文件，排除工具、APK、缓存和原始参考源码；没有凭证文件。自有文件 git diff --check 通过；vendor 原样保留上游空格风格，未为消除 whitespace 提示改动依赖。源码 push 与 Release 上传结果将在完成后另记。

### GitHub 上传完成

main 源码提交 25f480697abbb11333e3991153d557b3e2cc35af 已推送，GitHub commits API 核对与本地一致。v1.1.0 标签指向同一提交，测试版 Release 已发布（draft=false、prerelease=true）：https://github.com/huachen19867/liuliang-app/releases/tag/v1.1.0 。APK asset 状态 uploaded、大小 89,496,179 字节；GitHub 返回的 SHA-256 digest 与本地 72a57ebaa68dec4811e212416665cf7c810fb2a37dbe56976759708bb10bd520 完全一致。仓库为私有，下载需要有权账号登录。最终 Web DEMO 也已重新构建成功，包含修正后的关于说明。

此次交付没有连接真机：不能宣称验证了运营商实际余额、验证码登录、Launcher 固定/缩放/点击或通知投递。用户可以在 APP 连接两个号码后添加桌面卡片，查询仍由官方网页执行；必要时根据真机反馈继续适配。

## 2026-09-30：广电官网有余额但首页失败

老板反馈中国广电查询失败，补充官网能正常登录并显示余量，首页却查询失败。先定位本日志并复用已经下载的官方与 GitHub 参考；三角色分别复核协议/真实浏览器、解析门禁和 UI 状态，根代理集成桥接与发布。新的公开浏览器复核记录保存在 references/broadnet-public/failure-review/，没有账号或凭证。

确认原因是官网存在两套不同 jQuery：window.jQuery 3.5.1 来自 WAF；真正业务库为 webpack module 0 导出的 3.6.0，noGlobal=true。原探针只监听全局库的 ajaxSuccess，因此业务查询解码成功也没有 officialDecoded 事件；首页又排除了所有 raw HTTP200 成功结果，最终超时。原 Node mock 只有一套 jQuery 且桥接立即可用，未覆盖这个实际差异。

探针现于公开官网 polyfill 注册 webpackJsonp 后观察 vendor 自然注册的模块0 factory，原 this/参数/返回值保留，模块自然执行后才绑定其导出；不主动 require、不重复请求或再次调用官网 dataFilter。全局库兼容入口继续观察，以 WeakSet 为各实例去重。仅限定查询接口的结果在 bridge 尚未就绪时短暂缓存，条数8、每条2MiB上限，flutterInAppWebViewPlatformReady 后发送，页面销毁即释放。

另补 response_policy.dart：只有解析器已验证成功码、流量字段和 KB 的 raw 明文成功才可回退；加密或未知结构不替换状态，已有成功结果不受晚到 raw 覆盖。解析器与 UI 没有改动，保持通用/定向/用途未知区分。

官网公开页面结合 Playwright 本地 route 合成成功响应，复现原探针只有 raw；修复后 officialDecoded 恰好一条，业务 done/responseJSON 与原样本完全一致。正常桥接与请求结束才就绪的两种场景都通过。复用脚本 scripts/test-broadnet-browser.cjs 进入仓库，浏览器环境配置与范围写入根 README。Node 新增私有业务库、JSONP/factory保真、多实例去重、延迟就绪与有界队列验证；Flutter 28项完整测试和 analyze 全部通过。版本升为1.1.1+3，后续记录最终APK和Release核对。

最终1.1.1/code3 APK 构建成功，89,479,493字节，SHA-256 4d59c8672653f4b05597a170423963574f3834f9a34d861239f18c80b5d6770f，v2签名通过，aapt2核对名称、版本与SDK/权限。仓库版浏览器脚本已再次运行普通与--delayed-bridge，均passed=true/decodedEvents=1。安装包不启用DEMO；真实账号仍需老板手机复测。新文件维护到根README/应用README/输出索引，旧v1.1.0说明保留为历史版本。

修复源码4417ebf52fed89cf50cf51598fe8e1cb3443912c已推送并经GitHub API核对。v1.1.1标签指向同提交，私有测试Release https://github.com/huachen19867/liuliang-app/releases/tag/v1.1.1 已发布（draft=false），APK uploaded、89,479,493字节，GitHub digest与本地SHA-256一致。Web DEMO重新构建成功。没有替换或删除旧Release，用户可覆盖安装修复版再以真实号码核对广电结果。

## 2026-09-30：真机已同步但广电主数值为空

老板的新截图显示两家运营商均“已同步”，广电实际套餐明细已有30GB、约113GB和0GB结转，说明在这部手机上1.1.1已取得可显示的查询结果。用户截图不是官网原始响应或官方余额对照，不能据此验证所有额度准确性。当前主位仍显示“通用剩余 --”，原因是套餐名称没有明确通用标记；不是这次查询失败。

读取本日志并复用已有下载的官网/GitHub参考。三角色分别核对字段证据、共享摘要和首页明细交互。官网仅逐项渲染userResList，没有通用汇总字段；移动remainNum/sumNum仍与MIT参考一致，没有证据改动。改为广电主位展示“套餐明细合计”，前提是所有条目均有可确认单位和非负剩余额；明确用途以套餐规则为准，不将其并入通用总览/提醒。首页与桌面共用摘要，原生新标签不触发通用低量色。旧查询时间和失效状态保留，没有数据时仍不虚构零余额。版本计划1.1.2+4，验证和发布结果后续追加。

完整 Flutter37项、原生JUnit6项、Node探针和静态分析通过。H5解析器改为保留缺名称/余额的流量行，防止丢行后误算完整合计；全无可确认余额仍失败，部分可确认只展示明细。新增从parser到摘要的缺余额回归。首页原三项截断改为可展开，点击查看完整名称和剩余/总量，320px/1.4倍字号验证通过。广电没有确认通用总量时，顶部引导改为查看各卡余量而非再次连接；仍不计算两卡通用总览。artifacts/broadnet-summary-preview.png来自实际组件的DEMO样本，非用户手机截图、非余额准确性证据，已视觉查看。构建和发布待最终核对。

1.1.2/code4 APK构建成功并通过v2签名检查，aapt2核对版本、API24/36、名称与权限。89,489,653字节，SHA-256为711c032453868810d57d5319883b657907d95ac1cc8fe63b86ca0a7151b90954；个人调试签名延续，不启用DEMO。所有版本、说明和输出索引已更新，用户手机图片没有进入仓库；新增预览完全来自测试样本。新GitHub发布待上传后核对。

源码1d66460420dcdfbc782926e56e8c90633f52f6ef已推送并经API核对，v1.1.2标签一致。私有测试Release https://github.com/huachen19867/liuliang-app/releases/tag/v1.1.2 已发布（draft=false）；APK uploaded、89,489,653字节，服务端SHA-256 digest与本地711c032453868810d57d5319883b657907d95ac1cc8fe63b86ca0a7151b90954一致。Web DEMO更新构建成功。旧版Release保留，用户可覆盖安装1.1.2，实际摘要与桌面还需手机核对。

### 通用运营商版本：联通、电信独立初查

已复用技术日志与既有移动/广电参考，新增ChinaUnicomMonitor、FlowLite、ChinaTelecomMonitor精选文件并记录许可来源。前两者未提供LICENSE，电信项目为AGPL-3.0，均仅协议研究不复制代码。三者依赖APP抓包Cookie/token或APP账号服务，不作为官方网页登录已接通的证据。

本机Chrome无账号打开联通iservice后正常跳uac网页登录，电信login.189.cn也显示密码/短信登录；未输入账号、发送短信或保存Cookie。尚未确认两家官网流量响应、单位和成功码，因此只能确认官方入口候选，不能宣称四家真实查询都已支持。工具与公开结果在references/carrier-web-research.cjs和carrier-web-entries.json；详细结论见docs/UNICOM_TELECOM_RESEARCH.md。本阶段未改应用文件，公开GitHub与功能范围由根代理继续跟进。

## 2026-09-30：通用选择版本 1.2.0

老板要求首次选择运营商、适配单卡与不同组合，公开GitHub并交付几张应用内截图。先读取日志，复用已有参考，并下载联通/电信候选项目；按用户指定三角色分别负责公开协议证据、选择模型与桌面、可爱UI。联通/电信仅确认登录入口，缺少真实余量字段和单位证据，当前实现范围仍为移动/广电单选或组合，不提供不可查询的假入口。发布准备新建liuliang-buddy公开仓库，保留旧私有仓库。

main集成首次配置、启动恢复加载、旧connected标记迁移、设置改选、首页过滤。未完成选择不创建WebView或查询，改选提升generation、取消计时器、卸载WebView，旧回调失效。隐藏卡保留本地凭证/记录但停止查询与展示，桌面缓存先清空再发布选中数据，取消旧通知；清除账号数据保留选择。新增集成验证关注首次无默认选、单卡保存/重启、旧连接迁移及损坏配置不重启隐藏卡。实际组件DEMO截图与最终构建/发布结果待核对。

完整Flutter54项、analyze、Node探针通过，原生JUnit7项通过。四张应用内DEMO实际组件截图已重生并逐张检查；选择/管理页390×844、单卡390×1100、多卡390×1360，输出为2倍PNG。首次图CTA中文缺字来自测试Host未覆盖ButtonStyle字体，已为截图host显式使用已加载中文字体，不影响正式APP系统字体。保存流程按先清空桌面再持久化选择，失败回到旧选择；异常类型配置回到首次页。最后源码改动后重建APK，最终哈希及GitHub核对待记录。

最终APK在最后主流程修改后重建，113,901,232字节，SHA-256 fba83e5088d1fcd6143364a483d605542c5d99e39ccb11544b2f273082e97f8b。apksigner v2通过，aapt2确认1.2.0/code5、API24/36；Zip核对libflutter.so仅arm64-v8a。普通debug包，未传DEMO；源码与截图准备公开，工具、缓存、参考下载、APK和用户截图排除，APK放Release。新公开仓库huachen19867/liuliang-buddy已创建并核对isPrivate=false，旧私有仓库未改变。

公开上传完成：源码914b7b87fc45e9c92f20162bf8f736cb55250223推送到 https://github.com/huachen19867/liuliang-buddy ，GitHub commits API与本地一致，v1.2.0标签指向同一源码提交。Release https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.2.0 已发布，draft=false/prerelease=true；安装包state=uploaded、size=113901232，GitHub SHA-256 digest与本地fba83e5088d1fcd6143364a483d605542c5d99e39ccb11544b2f273082e97f8b完全一致。Web DEMO构建成功，截图与技术索引已随源码上传。54项Flutter、7项原生、Node、analyze通过；未进行新版真实账号/Launcher验证。联通、电信余额读取仍待取得官网协议证据，不宣称已支持此组合。

### 四运营商深入官网协议：联通取得可实施证据

本次复用已有参考并通过Chrome正常浏览公开页面。联通e5/index.html与query.html暴露真实业务模板：自然POST /e3/static/query/userinfoE5query，resource.remainFlow为MB，成功受successFlow/flowFlag及有限流量条件约束；登录判断来自checklogin.isLogin。没有借用APP token接口。原文、来源与严格DOM候选写入docs/UNICOM_TELECOM_RESEARCH.md及references/carrier-public-deep。

电信全国/省分多入口正常执行防护后返回400空白或连接关闭，未取得真实余额DOM/API，不能泛扫营销页面文字并称接通。额外ahBot是安徽小程序openid方案而非网页登录。公开抓取索引保存HTTP状态，没有账号、Cookie或短信操作。本代理未更改应用文件。

### 四运营商桌面卡片扩展

桌面桥接沿用 schema 1，以 `selectedCarriers` 名单和四个 `Carrier.name` 展示键传值。Native 白名单为 mobile/broadnet/unicom/telecom；旧数据没有名单时仍默认移动与广电。只缓存选中运营商的状态、主数值、标签与查询时间，四个连续 slot 按固定次序填充：1 张独占首行、2 张并排、3/4 张为 2×2。联通、电信没有得到可确认数值时显示未连接或待确认，不合成余额。最小桌面高度调到 210dp；旧桌面若维持旧 120dp 尺寸，需用户在 Launcher 调整尺寸或重加，实际宿主视觉尚待真机核对。

电信官方页面 DOM 的已用/总量估算若产生 `套餐估算余量` 标签，Native 在可显示数值前加“约”，不会触发通用低流量颜色，过期状态和原查询时间仍保留。Flutter 选择/桌面定向 14 项通过，覆盖四家持久化、旧标记迁移、非相邻组合过滤、四家 payload 与隐藏缓存；应用原生 JUnit 9 项通过，覆盖全部 1..4 组合映射与估算展示。Android 资源和 Kotlin 编译通过。全模块 Gradle testDebugUnitTest 因依赖包 shared_preferences_android 的 Robolectric SDK36 要求 Java21，而本项目固定 JDK17，失败于依赖包自己的测试；单独 `:app:testDebugUnitTest` 成功。

选择页默认开放四家运营商；联通单条带已确认单位的套餐余量只显示在对应卡片，电信按官网已用/总量显示值生成的余量在首页主位加“约”，并注明舍入和共享额度限制，不进入通用总览或提醒。Flutter 首页及选择页两组定向测试共19项通过，覆盖四家窄屏布局和这些显示边界。四张实际组件截图输出为 carrier-selection-four-demo.png、dashboard-unicom-broadnet-demo.png、dashboard-telecom-demo.png、carrier-settings-four-demo.png；均为测试样本并带 DEMO 标记，已逐张检查。截图测试切换页面时先卸载旧 widget，再挂载选择页，避免前一页残留在输出顶部；文件名与说明已登记到 artifacts/README.md。

### 电信定向DOM探针浏览器验收

新增 scripts/test-telecom-rendered-browser.cjs，使用真实Chrome，但全部导航/请求在本地route拦截为合成官网Account结构，不访问真实账号或接口。七项场景通过：v-show隐藏账务明细、混合MB/GB与NBSP、语音短信排除、登录路由拒绝、营销类似文本拒绝、延迟bridge、畸形行保留null不伪造合计，以及SPA返回登录不发送旧/待发明细（部分条件组合在同一场景）。结果 artifacts/telecom-rendered-browser.json 为passed=true、syntheticOnly=true、actualAccountVerified=false。此测试只验证JS探针，在真实手机账号上仍需核对官方套餐与估算数据。

## 2026-09-30：1.3.0四运营商接入

老板指出此前只开放移动/广电不符合通用版本，并明确要求继续改。复用技术日志和已下载参考，三角色继续深挖官网协议、四家UI与四槽桌面，根集成。联通公开E5页给出真实userinfoE5query请求、resource.remainFlow为MB、flowFlag/successFlow/overFlow/hasNolimitedFlow语义。电信旧189网厅被防护阻断，经历史网页登录参考找到当前e.dlife.cn天翼账号Home账务组件。新接口自然调用、result10000，传输加密；本版不复制其签名/密钥，改读取指定#balanceModal账务DOM的流量条目，含v-show隐藏但已渲染数据。

四家枚举按旧mobile/broadnet后追加unicom/telecom，保持旧存储与提醒ID不变。四家URL/SSO与来源门禁集中到carrier_web.dart，联通仅E5页面的确切userinfoE5query响应，电信只Home路由且telecomRendered阶段。电信每条已用/总量分别MB/GB换算，合法差值标估算，缺项保留未知并拒绝合计，超用/零总量/无限哨兵拒绝。联通主位套餐余量，电信主位约+套餐估算余量，全部unknown不进入通用总览/通知。登录SPA路由切换会变待验证，清除数据涵盖四家网站。

Flutter完整74项通过，Node加入联通精确端点/登录与敏感接口排除；应用原生9项通过，Chrome本地合成账务结构7场景通过。四张新DEMO组件截图与技术索引已生成；静态分析发现4处样式lint，已按等价写法修正，后续记录analyze与最终构建上传核对。新版未做真实号码/Launcher验证，不宣称官网DOM舍入估算等于精确余额。

最终完整Flutter75项通过、analyze无问题、Node探针通过；电信明细列表与详情弹窗也标约/估算，即使一条未知导致无合计，有效条目仍保留估算语义。新运营商接收时额外核对当前WebView URL，避免Home旧队列回调在SPA已回登录页后恢复成功态。最终1.3.0/code6 APK构建成功，89,530,031字节，SHA-256 f0c550a930cc249047479a6539dded713cfa5c90c82146bc7606d2a91d689781。v2签名与aapt2版本/API24/36检查通过。GitHub与Web DEMO完成后另记。

公开1.3.0发布完成：源码4a0e0e4677fcba05bef847bd989e36de4aae345e已推送到huachen19867/liuliang-buddy，GitHub main及v1.3.0标签API均与本地一致。Release https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.3.0 draft=false/prerelease=true；APK state=uploaded、size=89530031、GitHub digest sha256:f0c550a930cc249047479a6539dded713cfa5c90c82146bc7606d2a91d689781与本地完全一致。Web DEMO已构建成功，四家选择/联通广电/电信估算/运营商管理截图均上传。旧版本与私有仓库保留，未访问真实账号、未发送验证码；真实登录、金额与Launcher仍待设备核对。

## 2026-10-01：1.4.0 后台自动刷新

按老板要求增加后台刷新关闭、每小时、每两小时、每天四档。Android 使用 WorkManager 在有网络时尽力调度，通过后台 Flutter 引擎和无界面 WebView 访问已登录官网，沿用响应来源门禁与 Dart 解析；成功查询写回本地快照并更新桌面卡片。移动、联通、广电可尝试后台查询；电信依赖前台官网渲染的账务 DOM，明确跳过。后台不代替用户登录、不读取短信；失效会话停止该运营商的重复尝试，失败沿用旧值及其时间。首次默认关闭，前台五分钟刷新不变。Google WorkManager 官方样例已下载至本地参考目录并登记来源，未把参考源码纳入发布。

版本升至1.4.0+7。`flutter analyze`、Android ARM64 `assembleDebug`、APK v2 签名和 aapt 元数据检查通过；APK 为114,399,238字节，SHA-256 `53a782a6a4c5730f29a53fb8d6df3a6f4da6d2bc1337632498ca4872812b2b4b`。本版未运行测试套件；没有连接安卓设备，WorkManager 实际触发、WebView 会话共享、真实余额和不同 Launcher 更新尚未验证。

源码提交`7e6d9f4f54a5cf9946325de618a46d72527342fd`已推送到公开仓库`huachen19867/liuliang-buddy`，GitHub main、v1.4.0标签均核对为该提交。Release https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.4.0 已发布，draft=false、prerelease=true；APK asset状态uploaded、114399238字节，GitHub digest `sha256:53a782a6a4c5730f29a53fb8d6df3a6f4da6d2bc1337632498ca4872812b2b4b`与本地一致。真实运营商及桌面卡片刷新仍待安卓设备验证。

## 2026-10-01：集中处理公开用户反馈

老板要求分任务处理自动刷新不好用、两个移动号码、不限量一直查询、桌面添加无弹窗、S25 Ultra体验反馈与iOS支持。按工作区要求复用已有Google WorkManager/AppWidget参考，分配Astra轻度处理后台可靠性、GPT6 SOL高处理多账号与前台状态、GPT6 Luna极高处理原生桌面；根负责不限量解析、iOS范围、验收与公开发布。老板进一步确认桌面点击后没有系统弹窗，未知不限量来自哪家，因此四家均排查。

四家明确不限量标记已作为成功查询保存时间，不生成无限GB、零余额或低流量提醒；数值溢出拒绝而非饱和为大余额。不限量与原解析回归共23项通过。iOS没有Runner/WidgetKit工程，Windows没有Xcode或签名，不能宣称有可安装版；官方Flutter环境文档已从GitHub源下载，Apple WidgetKit说明已归档到忽略的参考目录。反馈任务和平台边界见docs/USER_FEEDBACK.md，新增GitHub安卓反馈模板以收集可复现信息。本轮集成、构建与发布结果继续追加。

集成复核修复登录返回页被inFlight丢弃、第二卡无快照借用主卡、Widget仅有第二卡结果回填主卡、移除第二卡后clear-all遗漏历史键等问题。清理开始先持久化pending，失败或崩溃不恢复查询，完整清理四家主副八组记录才解锁；默认会话单卡在不支持MULTI_PROFILE时仍可清除，使用过独立Profile则保守阻止复用残留会话。后台永久失效修复已在MainActivity接入，增加实际执行状态；移除新FlutterEngine根isolate对仅适用于派生isolate的DartPluginRegistrant.ensureInitialized误调用。

最终Flutter95项及analyze通过，Node探针与Chrome全本地合成账务8场景通过。Flutter多命令并发启动曾报无法确定engine revision，改串行启动后正常；以后共享一个SDK的Flutter命令串行。首轮APK失败于jni CMake/Ninja读取中文用户目录：协作期间pub get重写了插件路径为全局cache，仅给Gradle设置PUB_CACHE不会改旧元数据。构建脚本现从local.properties的Flutter SDK调用pub get，使用同一个工作区ASCII缓存重生依赖元数据后再构建；不更改或删除全局Pub缓存。最终APK与原生回归待构建后记录。

最终1.5.0/code8 ARM64 APK重建成功，90,035,780字节，SHA-256 8657856bd3f79380568b6ee786ec03059c877e7225a63ba177a669f6e31a65fa。apksigner v2通过、Android Debug签名，aapt2确认API24/36，Zip确认libflutter.so仅arm64-v8a；未传DEMO。随后串行执行应用模块:app:testDebugUnitTest，最终JUnit XML为12项WidgetPresentationTest与1项BackgroundRefreshScheduleTest，均0失败/错误。不把依赖插件历史XML计入本次验收。两张移动/不限量与四家选择的组件DEMO截图已目视检查，公开发布说明和输出索引更新为1.5.0。adb devices为空，真实不限量、双账号隔离、S25/One UI弹窗、后台调度仍待设备验证。

公开1.5.0发布完成：源码26b080392df0ffe543ff6ce45a9b4d2f96ed0c9f已推送至public远端huachen19867/liuliang-buddy，GitHub main与v1.5.0标签API核对为同一源码提交。Release https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.5.0 为draft=false、prerelease=true；APK state=uploaded、size=90035780、GitHub digest sha256:8657856bd3f79380568b6ee786ec03059c877e7225a63ba177a669f6e31a65fa与本地一致。GitHub仓库private=false，旧私有origin未推送。应用内DEMO截图和问题反馈模板随源码公开；本段发布回执另以文档提交同步main，不改变安装包或版本标签。

## 2026-10-01：iOS 源码适配与云端构建

老板要求增加 iOS 版本，先公开源码，随后明确没有 Mac。交付改为公开源码与 GitHub macOS runner 的未签名模拟器编译验证；没有 Apple 签名配置时不宣称能安装到 iPhone。先复用已有 Flutter/Apple 平台日志，下载固定版本 home_widget 的 BSD-3-Clause 精选源码作为 App Group/WidgetKit 参考，用本地 Flutter 3.44.8 官方模板生成独立 iOS scaffold，不覆盖已有安卓文件。

轻量分工：Astra 轻度处理 Runner/Xcode/云端构建，GPT6 SOL 高处理跨平台查询与持久化 WKWebView 账号隔离。第三个新代理因会话线程上限未能创建，复用上一阶段已完成的原生可靠性代理处理 Swift 展示桥接、通知与 WidgetKit。iOS 采用 17 起的持久化独立 WKWebsiteDataStore，官网前台查询与现有四家严格解析复用；后台初版只展示最近成功快照，不沿用安卓周期刷新承诺。阶段验收继续追加。

iOS17 Runner/UIScene、真实WidgetKit扩展target与Embed接线、App Group快照和本机通知已加入。插件副本在WKWebView创建前绑定四个固定UUID持久仓库，非法参数不创建网页；添加和恢复第二号码前持久化所属标记，清理包括默认和全部四个历史仓库。小组件只含展示白名单，低量通知补前台banner delegate，iOS设置不提供安卓后台周期。官网导航继续仅HTTPS，未扩大ATS例外。iOS图标从已有安卓矢量图自动渲染，不用Flutter默认标识。

本地Flutter完整98项通过，新增iOS创建参数/清理回执及平台设置验证，analyze无问题。首次平台测试缺通知通道mock导致保存等待，补齐后又发现同名按钮/弹窗标题应按AlertDialog定位，已修复并完整重跑；平台覆盖在teardown恢复以免污染其他测试。截图测试此前写死Windows字体与SDK路径，现可发现Flutter根目录并选择macOS中文字体，允许LIULIANG_PREVIEW_CHINESE_FONT覆盖。Xcode项目通过OpenStep解析、源引用/扩展依赖/嵌入断言和12个XML检查；原生编译、Swift快照测试与iOS模拟器smoke仍由公开GitHub macOS CI验证，尚未把静态接线等同编译成功。

安卓1.6.0/code9回归assembleDebug通过（2m41s），只产出app/build下的检查包，没有覆盖artifacts中的1.5.0公开APK。首轮GitHub macOS run36809553290（源码244d651835c6493a82085f2b0616debf089e9442）在Xcode16.4/ARM64上通过Flutter检查、Swift快照检查、主应用和嵌入TrafficWidget编译；但模拟器启动后进程退出，terminate返回3，截图实际为SpringBoard，不能算应用内截图或启动通过。新增stdout/stderr、崩溃报告和系统日志收集，将构建与smoke分步骤、清理幂等，同时保留启动失败结果，再由run36813400866（f074c23494237d6a15ee7f1a11cb86f96d19ab34）查证，不掩盖错误。GitHub大产物直连下载停滞，进程级7897代理下载同一产物8秒完成，无全局设置改动。

第二轮原生stderr明确缺少 `/usr/lib/swift/libswiftWebKit.dylib`。复用插件上游线索并下载WebKit官方问题293831，确认是iOS18.4/18.5模拟器打包缺陷，不能误修为删除账号API或弱链接。脚本动态解析所选runtime，只在普通库缺失而Cryptex同名库存在时设置模拟器子进程fallback，记录条件与路径；Flutter drive增加300秒超时。提交a3c7a4a35cc6f01b7999eb2a9cc19ee9584268ce已推送公开main，run36815488725进行远程复核，产品代码与iOS17下限未改。

老板追加截图：联通连接号码登录后一直转圈，以及移动特殊“哑巴卡”只能官方App刷脸。保持iOS任务并行推进，复用现有代理分别处理联通查询状态、官方登录证据与模拟器问题。移动官方入口从10086北京官网确认，未获得第三方人脸授权协议；连接页应如实说明App验证不自动同步网页。联通找到登录返回30秒节流、恢复旧loading无计时器及合法页面变化拒收等路径，具体实施与回归记录见UNICOM_REFRESH_PROGRESS.md。无真实账号，不将代码路径修复等同于反馈者套餐查询已成功。

反馈修复集成后完整Flutter104项通过，analyze无问题，Node探针与Chrome全本地合成电信DOM8场景通过。安卓1.6.0/code9构建45秒成功，115,893,050字节；SHA-256 cffde603402c2ceb5877c9bc9ce49fec9d7de0e2236e57b594deee954d218ecd。APK v2通过且证书沿用，aapt2确认API24/36；插件包含其他ABI，Zip单独确认Flutter引擎仅arm64-v8a，实际支持仍为ARM64。本轮没有原生安卓代码变化，未重复跑旧JUnit；保留native-tests.log历史边界。新增iOS桌面指引和设置页截图点，最终CI尚待回执。

run36815488725确认官方fallback生效（ordinaryExists=false/cryptexExists=true），不再dyld退出，Flutter驱动连接成功并取得真正首次选择页截图。但选择保存后的即时首页断言失败；原生通道回调不一定继续调度帧，pumpAndSettle不能代替等待业务结果。integration smoke改为等待目标页面最多30秒，失败时截图及dump树，不做原生mock或跳过断言。冷启动15秒截图仍是白屏，日志显示其后仍在首次Metal shader编译，云端冷启动观察窗口延至60秒；只是CI观察窗口，不改产品渲染器或启动逻辑。修改后analyze再次通过，准备最终源码云端复核。

进一步复核发现选择卡的InkWell带onDoubleTap，单击需等待双击识别窗口；集成测试先等“1家已选择”再点击继续，避免仍禁用时误点。配置切换/收起第二账号取消所有查询时，把遗留loading归一化成可重试错误；隐藏账号重新加入亦处理旧loading，保留余额时间、不改成功态。新增定向12项和analyze通过，完整回归及APK因产品有新修改需重新生成。

最终源码387c8a3329bd9316101515444d2533ca473ea172推送public/main，GitHub API一致，仓库private=false。完整Flutter107项通过，最终APK重建28秒成功，115,893,713字节，SHA-256 a251e90ac55ffcdd36057f8a057bdee102897d08bc12f5adceeb5d278e45647d；v2与同一证书、版本1.6.0/code9、API24/36核对通过。上段cffde603为尚未发布的中间包，公开交付仅使用最终a251e90a包。新push自动取消37c704e的中间CI，最终run36817117891验证完整源码及四张模拟器截图，不计取消的运行作通过。

最终macOS run36817117891完成且conclusion=success。Xcode16.4/iOS18.5 ARM64上107项Flutter、analyze、Swift快照、Runner/嵌入TrafficWidget编译、独立冷启动及完整界面smoke全部通过。冷启动60秒原始系统截图已显示选择页，四张原始1206×2622 Flutter截图目视核对后复制到artifacts/ios-*-simulator.png，索引记录空账号及5GB阈值语义；不把页面内卡片示意当系统Widget。正常入口模拟器归档在smoke改编测试入口前生成，56,893,081字节，SHA-256 b5f39594fc16f463bb5abb896d0708c14a53092ff3105d6798cf92d4aed7d21d。验证后只有说明/截图变化，不重复无关测试。Release草稿APK已上传，GitHub digest与最终本地a251e90a一致，待补模拟器产物/截图并公开发布。

公开1.6.0发布完成：https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.6.0 ，draft=false/prerelease=true。源码标签核对为4ae8f14c65452fe82ab883ca30346d58023e7fa1，发布树的app/、验证脚本和workflow与已成功验收的387c8a3完全相同，之后只补文档与截图。APK、未签名模拟器归档和四张PNG均state=uploaded；GitHub各asset SHA-256分别与本地一致，APK a251e90a/115893713字节、模拟器b5f39594/56893081字节。源码仓库private=false，只推送public远端；发布说明内文档链接转换为完整GitHub地址。真机签名/官方账号/系统Widget尚未验收，本版不提供iPhone IPA或TestFlight；联通真实套餐与移动特殊卡需要用户手机复测。该回执作为发布后文档提交同步main，不修改已发布标签或安装包。

## 2026-10-01：通话与短信套餐余量

老板的新反馈要求增加通话和短信余量。先定位本日志与已有四家协议资料，补下载移动MIT参考与官方公开页面，证据索引存references/allowances，结论见VOICE_SMS_RESEARCH.md。按老板分工复用Astra研究、SOL解析模型、Luna首页角色；不新增短信或通话权限，不抓取登录凭证。

首页每账号独立服务明细，JSON缓存兼容旧记录，错误/刷新保留原快照时间。联通保留短彩信和整组件successFlow失败门禁；移动汇总与明细不重复；广电未知次数资源不按短信；电信按同单位官网总-已用估算，短信次保留次不强转条。桌面流量协议不扩展。复核发现电信延迟桥接前明细清空会重放旧pending，修为空/过量/结构缺失同步清pending，Chrome增加真实浏览器全本地合成回归10场景通过；不等于真实账号验证。Flutter、构建和公开发布回执随后补充。

集成完整Flutter123项通过，analyze首轮指出电信分支3处多余非空断言，去除后无问题；不是修改解析逻辑。Node原页面探针通过，Chrome电信10场景通过，UI21项及新DEMO截图目视完成。APK与iOS云端验证进行中，未宣称真机值已确认。

安卓1.7.0/code10构建成功，91,439,548字节，SHA-256 9b191abbab3c41abed7c9c188361440289581abcb4dc916bfe33504953a78549。apksigner v2通过，沿用Android Debug证书fdf71a4c15215bf6ffc0a1f62e53a3abdfc21ed9fc0457697e33082e8a320fa8，API24/36，Flutter引擎仅arm64-v8a；aapt2无短信/通话权限，未用DEMO编译参数。实际组件截图已公开，源码e697ecb0dc7f9c0c2780e9d223f993b096c482af只推送public/main。iOS run36826003180进行中，尚未记为通过；真实账号、实体手机和系统组件没有新增实测。

iOS run36826003180已success：Xcode编译、完整123项Flutter、analyze、Swift模型检查、独立冷启动及选择/首页/桌面指引/设置smoke通过。日志存artifacts/ios-cloud-1.7.0.log（忽略，不含真实账号）；新截图与归档下载中。Release target需使用完整40位SHA，短SHA曾被API422拒绝，改完整后草稿成功；APK上传摘要与本地一致。

本机取回Actions归档两次受代理超时（gh等待及HttpClient90秒），直连60秒亦失败，不记为产物通过或空文件成功。改用GitHub runner取已验收归档并上传现有Release；新增手动publish-ios-artifact workflow，严格校验成功main分支iOS工作流与tag格式，只发布模拟器和四张截图，使用仓库临时token，不在本机保存凭证。构建结果不受下载路径故障影响。

iOS归档改由云端发布助手run36828372883取得run36826003180已验收artifact并上传Release草稿，success；模拟器包56,902,762字节、SHA-256 8304ec122473e14aa5815fb6b921d26bcac13c3dc0dab960cfd024db448a64e6。GitHub digest与云端sha256sum一致；四张原始1206×2622截图改从Release正常下载到本机，逐张目视核对且hash与云端/GitHub一致，复制artifacts索引。首页包含未连接的通话短信面板，设置5GB是阈值，无真实账号或编造余额。截图不是实际系统Widget验收，不交付iPhone签名包。

公开1.7.0发布完成：https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.7.0 ，draft=false/prerelease=true，标签与源码目标fb50e4984095ee9286b07775da2ef7f0a24cca44一致。发布树app/、原iOS验证脚本及工作流与已通过run36826003180的e697ecb相同，后来只有文档/截图和已单独成功验收的产物发布助手。七个资产均uploaded，APK9b191abb/91,439,548字节、模拟器8304ec12/56,902,762字节及五张PNG摘要核对一致。只推public，公开仓库private=false；本段回执另作文档提交，不改已发布tag或安装包。

## 2026-10-01：通知栏、快捷设置与 Release 正式分发

老板要求设置中增加两个系统入口开关，公开GitHub分发必须Release，解决旧Debug APK约91.4MB体积。先读技术日志与原通知/Widget缓存，再按Astra轻度官方参考研究、SOL高原生实现、Luna极高设置UI拆分；第三新代理受线程上限，复用既有Luna角色完成。官方android/platform-samples quicksettings精选源码固定0445045与LICENSE已下载，Flutter官方签名/R8资料亦归档，方法见SYSTEM_SURFACES_RESEARCH.md。

通知沿用展示白名单缓存，每账号状态及原查询时间，不创建前台服务；QS磁贴提供明确查询/刷新操作，不声称实时后台查询。设置即时保存，通知系统/渠道阻断显示原因，组件启用不等于已添加；API33用户确认、旧版手动编辑。UI测试首轮旧widget_test漏mock新原生通道导致pumpAndSettle超时，补mock后完整130项通过，analyze无问题；新settings DEMO截图生成。

Release切换AOT、R8、资源裁剪、ARM64 ABI，拒绝无发布签名的Release任务。创建私有RSA3072 PKCS12发布证书，密码仅DPAPI保存，被忽略的.tools/signing目录限当前用户与SYSTEM，不输出密码/提交密钥。新证书不可覆盖旧Debug，因此另提供相同Release内容旧证书过渡包，用户选安装渠道，不由应用删旧数据。构建与原生检查进行中，体积待实测。

原生应用JUnit16项通过（Widget12、调度1、系统面板3），均0失败/错误。Release初次直接assembleRelease与随后Flutter --no-pub均保留dev integration_test注册，导致Java类缺失；本SDK --no-pub会跳过releaseMode插件注册，必须用正常flutter build apk --release，未手工修改生成文件或全局SDK。复用已校验Gradle zip，通过构建脚本临时wrapper URI并finally恢复公开URL；R8成功。首个Release18,587,863字节，非debuggable，但插件其它ABI仍被Flutter默认过滤重设纳入；明确disable-abi-filtering保留应用ARM64过滤，正在最终重建。旧FOREGROUND_SERVICE权限来自原WorkManager合并清单，历史包亦有，本功能未新增服务。

最终ARM64 Release包18,350,307字节（18.35MB/17.50MiB），SHA-256 8eae226fc13b840ada5623a98d8d1c84bc222d2f80877511bc3efae71b556134；新证书33b115558027fdfa667a3f14a9351fbdb29901948c085daf739e16a9055a497e。旧证书Release过渡包18,376,558字节，SHA-256 8d4ab92783a53208bd164eef44cc0d79775d2acf84ecc3e8c203615412fa4d5e，证书保持fdf71a4c。两包315项非META-INF内容逐一SHA相同，均非debuggable、v2签名通过、code11/1.8.0、API24/36、native-code只arm64-v8a；无短信/通话读取权限。相较1.7.0的91,439,548字节主包减少79.93%。原生16项/Flutter130/analyze已经通过，后面仅ABI/签名构建核对，不虚构真机通知或R8后台成功。wrapper公开URI恢复，私钥目录ignored核对，Android.settings DEMO目视无溢出。准备公开源码与启动iOS共用UI验收。

最终产品文案移除Release关于弹窗“测试版”标题，开发构建仍明确开发版；pubspec描述同步。完整Flutter130项再次通过、analyze无问题，按串行SDK规则正常flutter build apk --release重建24.5秒成功。最终交付主包18,350,307字节/SHA-256 b8943da4629e17a03c5f74b9e69d9822335c8dea6c9ab99d442d51151f7ee88c，过渡包18,376,558字节/5b9785c4edecfbcb14754e21adbb711650637764ce4b386da71edc0cab205c14；上一段8eae/8d4a仅属未发布中间包。证书、v2、非debuggable、API24/36、code11/1.8.0、仅ARM64及315项应用内容相同再次核对。README更新正式分发与签名迁移，未宣称真实账号或系统面板验收通过。
