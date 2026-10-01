# 移动官网验证码触摸兼容检查

2026-10-01。老板反馈部分用户输入手机号后，能看到移动官网“获取验证码”按钮，但点击没有响应。运营商已明确为移动；没有键盘遮挡根因证据，也没有真实号码或设备日志，不能宣称问题已经复现或修复。

开始前读取 `docs/TECH_LOG.md`，复用 `references/ChinaMobileMonitor/`、`references/allowances/mobile-2.html`、`mobile-8.js`、`mobile-10.js` 以及现有 Flutter/InAppWebView 源码。移动网页已经自带 `width=device-width` viewport。应用启用 JavaScript，没有覆盖 User Agent，不使用桌面模式；Android 插件默认 Hybrid Composition。Flutter 官方页没有覆盖网页的点击层或竞争手势；原生 `dispatchTouchEvent` 和 `onTouchEvent` 继续调用平台实现，余额探针不监听或阻止 touch/click。没有足够依据强加 EagerGestureRecognizer、伪装 UA 或放宽所有导航与第三方 Cookie。

已有官网脚本把完整手机号、发送按钮状态及协议勾选作为前置条件；MIT 浏览器参考同样先处理协议再获取验证码，但其自动勾选与模拟点击不适用于本应用。此次只提示用户自行阅读、勾选和操作。官网前置门禁、弹窗或短信脚本失败是否是老板所遇现象，还需官网研究及用户页面证据确认。

`app/lib/ui/carrier_browser_shell.dart` 将应用工具栏和官网触摸区域分开，限制长号码标题为单行，使用可标识的按钮避免窄屏大字横向溢出。键盘出现时收起冗长说明，为官网表单和官网弹窗保留可用高度；提供明确“收起键盘”操作，调用插件 `clearFocus` 与平台 `TextInput.hide`，没有注入 DOM blur、点击验证码或勾选协议。官网底部避让系统导航栏。移动帮助仍包含官方 App 人脸验证边界，增加协议与官网提示说明。

踩坑：Flutter `Scaffold` 在 `resizeToAvoidBottomInset` 下会从 body 的 MediaQuery 移除 bottom viewInsets；如果在 shell 内检测键盘会一直读到 0。必须在 Scaffold 上方的 State context 读取键盘状态后传给 shell。源码证据为 `D:/AI/tools/flutter/packages/flutter/lib/src/material/scaffold.dart` 的 `_addIfNonNull`/`removeViewInsets`，没有运行或修改 SDK。

新增 `app/test/ui/carrier_browser_shell_test.dart`，覆盖窄屏大字、键盘压缩、短横屏和系统导航区，以及官网替身按钮、帮助、查询和收起键盘的触摸可达性。这些是 Flutter 布局回归测试，不能证明 Android 原生 WebView 真实短信链路成功。SDK 与最终验收由根代理串行执行；此文档后续补充实际结果。

根代理最终Flutter148项全部通过、analyze无问题；本页四项Shell测试实际执行通过。移动验证码真实页面尚未复现，布局改善不代表已确认其点击无响应根因。
