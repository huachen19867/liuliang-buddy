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
