# 输出索引

ui-preview.png 为应用 UI 实际组件渲染的预览，使用演示数据，不能证明真实手机号流量查询准确性。顶部显示“界面演示 · 非真实流量”。

broadnet-summary-preview.png 为广电套餐明细合计卡片的演示预览，展示用途未分类明细可识别时的余额合计与规则提示。截图中的数值仅用于展示，顶部显示“界面演示 · 非真实流量”，不代表真实账号余额或精度。

历史 1.1.2+4 安卓个人测试包，89,489,653 字节（约 85.3 MiB），Android 7.0/API 24 及以上，目标 ARM64 手机。它使用调试签名，未使用 DEMO 编译参数。首次安装后两个号码需分别在官方网页完成验证，已有版本可覆盖安装。下载见 [GitHub Release](https://github.com/huachen19867/liuliang-app/releases/tag/v1.1.2)，私有仓库需要有权账号登录。

android-build.log 保存成功的本地安卓构建输出；apk-signature.txt 为 apksigner 签名检查（v2 通过，Android Debug），apk-metadata.txt 为 aapt2 元数据检查（名称、版本、SDK 与权限）。应用申请网络与通知权限，没有短信读取权限。本目录不含真实号码、验证码、登录凭证或成功账号的原始响应。

APK SHA-256：711c032453868810d57d5319883b657907d95ac1cc8fe63b86ca0a7151b90954。

此版本修复广电已同步但主数值为空的摘要显示，首页与桌面使用“套餐明细合计”，用途以各套餐规则为准，不参与通用汇总/提醒。完整 Flutter 37 项测试、原生 6 项展示测试、静态分析及 Node 探针检查通过。收到用户真机查询同步反馈，新版摘要和 Launcher 添加/缩放/点击仍待真机核对。卡片显示原查询时间，点击打开 APP 更新；不会在亮屏时自动向运营商联网。

可交互 Web 演示位于 app/build/web/，以 DEMO=true 构建，需通过本地 HTTP 服务访问。源码与运行说明见根 README.md。

## 1.2.0 输出

carrier-selection-demo.png、dashboard-single-demo.png、dashboard-multiple-demo.png、carrier-settings-demo.png 分别为首次选择、移动单卡、移动/广电组合和运营商设置。来自真实Flutter组件渲染，明确标注DEMO，不含用户账号或真机图片。

当前APK更新为1.2.0+5，113,901,232字节，SHA-256：fba83e5088d1fcd6143364a483d605542c5d99e39ccb11544b2f273082e97f8b，v2签名通过，API24/36、ARM64、Android Debug。历史1.1.2记录见上文，已公开发布 https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.2.0 。

## 四运营商 UI 预览

carrier-selection-four-demo.png 展示移动、广电、联通、电信的首次选择页；dashboard-unicom-broadnet-demo.png 展示联通套餐余量与广电套餐明细合计；dashboard-telecom-demo.png 展示电信官网已用/总量显示值估算，并在数值前标“约”、注明舍入误差；carrier-settings-four-demo.png 展示四家运营商设置页。截图由 Flutter 实际 UI 组件和测试样本生成，顶部标有“界面演示 · 非真实流量”，其中号码与余量不代表真实账号或查询准确性。

telecom-rendered-browser.json：scripts/test-telecom-rendered-browser.cjs生成的真实Chrome/全本地合成网页探针验收结果。passed=true，未验证真实账号；覆盖限定DOM、隐藏模态、混合单位、畸形行、登录路由和桥接时序。

## 1.3.0 历史安装包

liuliang-buddy-debug.apk已更新为1.3.0+6，89,530,031字节（约85.4MiB），API24/36、ARM64、Android Debug签名v2通过，未启用DEMO。SHA-256：f0c550a930cc249047479a6539dded713cfa5c90c82146bc7606d2a91d689781。公开下载 https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.3.0 。75项Flutter、9项应用原生JUnit、analyze、Node和Chrome合成DOM验证通过，尚未实测联通/电信账号或Launcher。

## 1.4.0 历史安装包

liuliang-buddy-debug.apk已更新为1.4.0+7，114,399,238字节（约109.1MiB），API24/36、ARM64、Android Debug签名v2通过，未启用DEMO。SHA-256：53a782a6a4c5730f29a53fb8d6df3a6f4da6d2bc1337632498ca4872812b2b4b。公开下载 https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.4.0 。本次analyze与Android构建通过；未运行测试套件，也没有连接真机，后台实际触发和官网登录会话共享仍待设备验证。

## 同运营商双卡演示截图

dashboard-two-mobile-unlimited-demo.png 来自实际 Flutter 首页组件的 390×1220 布局，导出为两倍分辨率 PNG。两张中国移动卡分别显示有限 5 GB 样本与官网明确标记“不限量”的样本，顶部有“界面演示 · 非真实流量”；这些数字与规则文字为测试样本，不能证明两个真实号码已登录或余额准确。生成测试见 `app/test/ui/dashboard_screen_test.dart`，隔离实现与待验证边界见 `docs/MULTI_ACCOUNT_REVIEW.md`。

## 1.5.0 历史安装包

liuliang-buddy-debug.apk已更新为1.5.0+8，90,035,780字节（约85.9MiB），API24/36、ARM64、Android Debug签名v2通过，未启用DEMO。SHA-256：8657856bd3f79380568b6ee786ec03059c877e7225a63ba177a669f6e31a65fa。公开下载 https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.5.0 。95项Flutter、13项应用原生JUnit、analyze、Node及Chrome本地合成DOM8场景通过。最终构建日志为android-build.log，原生回归为native-tests.log；这些日志与APK按仓库规则不提交，APK由GitHub Release发布。详见docs/RELEASE_1.5.0.md，真实账号、S25 Ultra、Profile会话与后台长期运行尚待设备验证。

## 1.6.0 当前安装包

liuliang-buddy-debug.apk为1.6.0+9，115,893,713字节，API24/36，libflutter.so仅ARM64；插件自身还含其他ABI库，不代表应用能在其他架构运行。Android Debug证书沿用，v2验签通过，未启用DEMO。SHA-256：a251e90ac55ffcdd36057f8a057bdee102897d08bc12f5adceeb5d278e45647d。107项Flutter、analyze、Node及Chrome本地合成DOM8场景通过，最终Android构建28秒成功；新版日志为android-build.log，旧native-tests.log仅代表1.5.0原生回归，不能算本轮新测试。公开发布说明见docs/RELEASE_1.6.0.md，真实联通登录与特殊移动卡仍待手机复测。

## iOS 云端模拟器截图与产物

ios-selection-simulator.png、ios-dashboard-simulator.png、ios-widget-guide-simulator.png、ios-settings-simulator.png 为 [run36817117891](https://github.com/huachen19867/liuliang-buddy/actions/runs/36817117891) 在 iOS18.5 ARM64 模拟器生成的1206×2622实际应用画面，未加工。分别显示首次选择、未连接移动首页、手动添加指引和设置；不包含真实号码、会话或流量样本。设置中的5GB是提醒阈值，不是套餐余额；首页中的卡片预览不是系统Widget截图。未验证真实Widget摆放、通知授权或官网登录。

该次CI已通过107项Flutter、analyze、Swift快照检查、Runner及Widget扩展编译、独立冷启动和界面烟雾流程。正常入口模拟器应用在Release以ios-simulator.tar.gz交付，56,893,081字节，SHA-256 b5f39594fc16f463bb5abb896d0708c14a53092ff3105d6798cf92d4aed7d21d；不能安装到iPhone。云端详细日志和诊断保存在忽略的.tools/ios-ci/final，不上传系统日志到应用源码。

## 1.7.0 通话与短信预览

dashboard-voice-sms-demo.png 来自实际Flutter首页组件，显示通话分钟、真实零短信样本、未知短彩信共享包与超额短信样本，各套餐分开展示，顶部标界面演示。数值都是合成样本，不代表真实运营商账户。UI定向21项已通过，截图目视无截断或溢出；其他历史DEMO由同一测试同步更新为新布局。桌面示意仍只显示流量。

1.7.0/code10当前安卓包91,439,548字节，SHA-256：9b191abbab3c41abed7c9c188361440289581abcb4dc916bfe33504953a78549，API24/36、ARM64 Flutter、原Android Debug证书、v2验签通过，未启用DEMO。完整123项Flutter和analyze通过。iOS新产物待云端验收回执，历史模拟器截图仍属于1.6.0。

1.7.0的ios-selection/dashboard/widget-guide/settings-simulator.png已更新为run36826003180真实模拟器截图，未连接账号、通话短信等待连接，无真实套餐数据。Release提供未签名模拟器归档56,902,762字节，SHA-256 8304ec122473e14aa5815fb6b921d26bcac13c3dc0dab960cfd024db448a64e6；由云端发布助手run36828372883上传且GitHubdigest核对一致，本机Actions下载超时后使用Release成功取回四张截图。

## 1.8.0 系统入口与 Release

公开下载页只保留 liuliang-buddy-release.apk 正式安装包。旧版升级包和演示截图已从Release附件撤下；工作区文件保留，截图通过说明链接查看。GitHub自动生成的Source code归档不是手机安装包，APK签名与哈希未改变。

android-system-surfaces-settings-demo.png 为真实Flutter设置组件渲染，DEMO标注明确，演示开启通知栏余额与快捷设置入口；不是系统通知或磁贴实拍。主分发改liuliang-buddy-release.apk，旧证书Release过渡包liuliang-buddy-legacy-upgrade.apk已撤下，不再公开分发；Debug历史文件不作为新版分发。大小与证书的最终ARM64验收回执如下。

1.8.0正式主包18,350,307字节，SHA-256 b8943da4629e17a03c5f74b9e69d9822335c8dea6c9ab99d442d51151f7ee88c，新证书33b11555；旧签名Release过渡包18,376,558字节、SHA-256 5b9785c4edecfbcb14754e21adbb711650637764ce4b386da71edc0cab205c14，旧证书fdf71a4c。两包非debuggable、v2通过、API24/36、仅ARM64、非签名区315项内容相同。130项Flutter/analyze/16项原生通过，系统通知/磁贴和R8后台长期实机行为仍待复测。

1.8.0 此次交付新增两个安卓Release APK与设置组件DEMO截图；现有四张iOS模拟器截图和归档仍属于已验收的1.7.0，不作为1.8.0产物。iOS最终源码云端验证run36838979981进行中，后续以实际回执更新。

## 1.8.1 启动热修

唯一正式APK18,383,087字节，SHA-256 59fe631319748e3ed998ae134cf3a89c6e781856d0fd4a0f1be4adbe66b53caa，证书沿用33b11555。1.8.1/code12、API24/36、ARM64、非debuggable及v2通过。隔离工作树从2afb682仅含Room无参构造保留修复与版本变化，未混入后续UI改版；荣耀Android16原1.8启动崩溃复现、同签名覆盖后冷启动及持续进程通过，老板确认正常。日志/截图保留.tools/android-crash，不作为公开组件预览。详见docs/RELEASE_1.8.1.md。

## 1.9.0 新界面输出

治愈风实际组件演示：ui-preview.png、carrier-selection-four-demo.png、dashboard-two-mobile-unlimited-demo.png、dashboard-unicom-broadnet-demo.png、dashboard-telecom-demo.png、dashboard-voice-sms-demo.png。全部是合成演示数据，不是手机或运营商实测。唯一正式包为 liuliang-buddy-release.apk；版本和摘要见 docs/RELEASE_1.9.0.md。新 Launcher 效果仍待设备验证。

## 1.9.1 桌面布局输出

widget-glass-preview.png由scripts/preview-native-widget.cjs读取实际Android布局及drawable生成，使用合成两卡数据，非真机截图、无模拟背景blur。最终APK版本和摘要见docs/RELEASE_1.9.1.md。

## 1.9.2 运营商Logo输出

首次选择、首页与widget-glass-preview.png均已更新为四家官网原版图形。图仍分别为Flutter实际组件合成数据截图和Android XML浏览器布局预览，不是运营商或手机实测。标识资源及来源在app/assets/carriers/，原图在scripts/carrier-originals/。

1.9.3将宿主透明框和wrap_content玻璃背景分开，widget-glass-preview.png在400dp宿主验证底色仅贴内容，桌面网格需用户手动缩放。移动Shell与联通兼容风险见对应进展记录，不把这些预览当真实验证码/余量验证。

## 1.10.0 三四卡输出

widget-three-preview.png、widget-four-preview.png 读取当前 traffic_widget_compact.xml 和正式素材，以合成数据绑定三/四卡；280dp宿主、背景紧随卡片验证，非手机实拍。carrier-count-four-demo.png 展示同家四张的明确数量选择，dashboard-four-accounts-demo.png 为真实Flutter组件演示，用于四账号滚动布局验证，不代表真实余额。正式包及最终验证摘要见 docs/RELEASE_1.10.0.md。

1.10.0正式APK 27447596 字节/SHA256 46a37628054f377a3e640a3a1b5dc78c715dce249fa9161f3d2750a7c0663606，正式v2证书33b11555不变，版本17、API24/36、ARM64、非debuggable及16KB ZIP对齐通过。Flutter166/analyze无问题/JUnit29/浏览器合成回归通过；非真实账号或新包真机验收。

## 1.10.7 输出

`liuliang-buddy-release.apk` 为最新本机正式签名ARM64主包，1.10.7/code24，28,104,528字节（28.10MB），SHA256 `2cc9868d9ee02b1bacf9c113ac9c98deabe3df08fe0ea0fd320676bd45fe34d4`。正式v2证书33b11555，API24/36、16KB ZIP对齐通过，构建37.8秒。Flutter286项/Android本项目33项/analyze通过。移动余额本地Chrome17类结果在 `mobile-balance-browser.json`，均拦截网络，无实际账号；Node生产JS合成亦通过。本版包含1.10.6未上传的电信名称分类/同名合并，以及移动话费与安卓紧凑卡片。发布回执另补，iOS桌面话费本版未接入。
1.10.7已正式公开，唯一APK uploaded，远端digest与上述hash一致：[正式版](https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.10.7)。

## 1.10.8 输出

最新正式主包版本1.10.8/code25，APK28,104,532字节（28.10MB），SHA256 `81bd97686278c856b4bc25f0b5d7f872f36cbb1fdf586f49f5da75e121f3a171`。Release59.6秒，v2正式证书33b11555/API24-36/16KB ZIP对齐通过。Flutter292项/analyze/Android本项目35项通过。telecom-partial-preview.png为实际Flutter合成已读约276GB与1项待确认；widget-other-partial-{2,4}-preview.png为实际XML合成其他已读約10GB与1项待确认，均非真机或用户数据。最新版包替换本机同名主输出，旧版本hash是历史回执，不用于当前文件。GitHub回执另补。
1.10.8已公开：[正式发布](https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.10.8)，唯一APK远端digest与本机一致。

## 1.10.9 输出

最新正式主包版本1.10.9/code26，APK28,104,532字节（28.10MB），SHA256 `3c635d5d4ac9e7b759b0ee8edb765af025dc96e7355b1ceac43f1e25dfc4ac24`。最终Release66.5秒，v2正式证书33b11555/API24-36/16KB ZIP对齐通过；297项Flutter/analyze与Node会话恢复/XHR合成通过。仅广电有效查询后保存完整会话、移除7日本地弃用、更新恢复脚本与访问拒绝误报修正，不是官网三日续期接口。没有新增native/Swift生产改动，因此不冒称运行新的JUnit/macOS验收。真实移动广电长期会话未验证。GitHub回执另补。
1.10.9唯一APK已正式公开，远端digest一致：[正式发布](https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.10.9)。

## 1.10.10 输出

1.10.10/code27主包28,170,068字节（28.17MB），SHA256 `34bb1a0db48e2758c08b4d4ad37c666389958f70f328f473e6e3e130dd247de2`。Release96.6秒，v2正式证书33b11555/API24-36/16KB ZIP对齐通过，Flutter298项/29秒和analyze通过。使用既有插件Chrome/Safari打开精确官方号码认证协议，完善移动官网本机登录指引，包含会话恢复修复；广电原生一键登录尚未在本应用接通。未新增真实SIM/三日登录/原生协议浏览器真机验收，公开回执另补。

1.10.10公开回执：[正式版](https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.10.10)，target 5620613f22861d1423dd1029139ccd1512f9e9ae，唯一APK uploaded且远端hash与上文一致。

## 1.11.0 输出

`query-health-preview.png`：实际 Flutter 查询检查页渲染，合成四家故障状态，显式“界面演示”，不是实际运营商或真机结果。截图字体加载复用 `app/test/support/preview_fonts.dart`，原始运营商logo预缓存后渲染，完整数值/时间不含真实用户信息。正式APK/哈希回执后补，详见 `docs/RELEASE_1.11.0.md`。

本机正式主包为1.11.0/code28，28,171,100字节，SHA256 `7426c9114802b43bb84ef8fbae3c492227de371fe34cb3e3c348470fe25283a5`。Release62秒、正式v2证书33b11555、非debuggable、ARM64/API24-36、16KB ZIP对齐通过；Flutter328/analyze/原生app35/队列3项通过。公开回执另补；真实账号和长期后台未新增验证。
