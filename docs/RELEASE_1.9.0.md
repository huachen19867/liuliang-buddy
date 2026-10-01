# 1.9.0 治愈风与卡片备注

安卓唯一正式下载：[liuliang-buddy-release.apk](https://github.com/huachen19867/liuliang-buddy/releases/download/v1.9.0/liuliang-buddy-release.apk)。适用 Android 7+ ARM64 手机，正式签名可覆盖 1.8/1.8.1 正式版；旧 Debug 测试版证书不同。iPhone 仍无可安装的签名包。

首页、首次选择页、图标和桌面预览换成奶油白、青瓷绿的微缩温泉治愈风。人物采用用户指定参考的棕色盘发、绿眼形象；服装按场景调整，角色在页头和小组件边缘陪衬，余量与状态优先。来源见[素材索引](../app/assets/resort/README.md)。

每张卡可设置备注和手填号码，号码脱敏显示；同运营商双卡保持独立身份和官方会话。新增通用、定向、其他流量分类及通话摘要，未知用途不冒充通用，缺项不显示为零。电信话费只读取官网指定节点的“余额/元”，其他运营商未获得可靠字段时显示未提供。联通官网明确返回会话失效时结束等待并提示重新登录，不代表全部地区账号已实测。

安卓桌面卡片改为整宽纵向账号行，左侧身份及套餐摘要，右侧分类/通话四格，小角色靠边。根据宿主高度显示一至四张完整卡，放不下时提示打开应用。最近查询时间保留；卡片不会在亮屏时自动向运营商实时联网，后台周期仍是关闭/一小时/两小时/一天并受系统调度影响。

[首次选择截图](../artifacts/carrier-selection-four-demo.png) · [双移动卡截图](../artifacts/dashboard-two-mobile-unlimited-demo.png) · [首页截图](../artifacts/ui-preview.png)。截图由实际 Flutter 组件渲染，带演示提示，数据为合成样本。

沿用 1.8.1 的 Room 无参构造 R8 保留规则。1.8.1 已在荣耀 Android 16 真机覆盖安装、冷启动验证，用户确认正常；新版 USB 已断开，没有宣称 1.9 真机启动、各 Launcher 添加/缩放或真实运营商账号验证通过。Flutter 144 项、安卓 JUnit 21 项通过，analyze 无问题；Node 响应探针及真实 Chrome 电信合成页面通过。iOS 共用 Flutter UI 与图标更新，iOS 原生 WidgetKit 未同步此安卓四格布局，也未提供签名 IPA。

最终正式 APK：27,185,049 字节（27.19 MB），versionName=1.9.0/versionCode=13，API24/36，仅 ARM64，非 debuggable，v2 签名与 16 KB ZIP 对齐校验通过。SHA-256：43aa24ea8a1f24804dc410f98dcf6294ad4a5e2274870572cbf16e4a609bfddc。正式证书保持 33b115558027fdfa667a3f14a9351fbdb29901948c085daf739e16a9055a497e。增加插画资源后较 1.8.1 增大约 8.80 MB。
