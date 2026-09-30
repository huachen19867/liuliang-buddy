# 1.2.0+5 运营商选择测试版

首次安装不预选运营商，需要选择至少一家后进入首页。当前可选移动、广电，支持单选和组合；联通、电信余额查询尚未接通，见 UNICOM_TELECOM_RESEARCH.md。暂不支持同一家运营商同时连接两个号码。设置中可随时改选，首页、刷新、通知与桌面按选择调整。

已有旧版连接会自动迁移，隐藏卡保留本地记录与登录会话，但不会查询或展示。要删除数据可使用清除本地数据，运营商选择保留。桌面仅显示上次查询与时间，点击打开APP更新，不在后台实时联网。

可爱奶油色UI、自绘水滴和分运营商卡片保留。四张应用内截图在 artifacts/carrier-selection-demo.png、dashboard-single-demo.png、dashboard-multiple-demo.png、carrier-settings-demo.png；真实组件渲染的DEMO，不是用户真机或真实余额。

APK：Android 7/API24及以上，ARM64，个人调试签名，未启用DEMO。版本1.2.0/code5，113,901,232字节。SHA-256：fba83e5088d1fcd6143364a483d605542c5d99e39ccb11544b2f273082e97f8b。v2签名和aapt2版本/SDK核对通过。

Flutter完整54项、静态分析、原生JUnit7项与网页Node探针通过，四图已逐张视觉检查。本次没有真实手机号登录或Launcher真机测试，官网会话/改版与账单延迟仍会影响查询。
