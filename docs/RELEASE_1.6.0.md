# 1.6.0 联通刷新修复与 iOS 源码预览

安卓和 iOS 共用的查询状态修复登录返回被上一轮 30 秒刷新限制挡住、恢复历史加载记录后一直转圈的问题。登录页和页面加载失败解除该账号节流，查询 35 秒未取得结果时结束加载；前台恢复不会覆盖正在查询的账号，也不会把后台新成功记录标成失败。联通允许确切 E5 查询页之间的合法地址变化，仍拒绝登录页和其他来源。实际反馈者的官网套餐查询仍需手机复测，详情见 [UNICOM_REFRESH_PROGRESS.md](UNICOM_REFRESH_PROGRESS.md)。

移动连接页新增登录帮助。需要官方 App 人脸验证的号码应由用户在中国移动 App 完成；该验证不会自动同步本应用网页登录，网页版仍无法登录时明确说明暂不支持自动查询。参考来源与限制见 [MOBILE_FACE_LOGIN_RESEARCH.md](MOBILE_FACE_LOGIN_RESEARCH.md)。

本版新增 iOS 17 及以上工程，公开源码供编译和测试。保留现有奶油色界面、四家选择与前台官网查询，支持两个同运营商账号使用独立持久化 WKWebView 仓库。首次号码验证仍由用户在官网完成，查询仍沿用原有来源门禁、不限量处理和超时保护。不是签名的 iPhone 安装包，也未发布 TestFlight 或 App Store。

新增 WidgetKit 小、中、大号桌面组件与 App Group 展示快照，显示最近查询的余量、状态和时间。桌面需要用户手动添加，轻点卡片打开应用查询。iOS 设置不提供尚未实现的定时后台官网查询，timeline 更新只是重绘旧快照。低流量提醒支持本机通知授权及前台横幅，仍只使用有限通用额度。

Windows 本地完整 Flutter 107 项测试和静态分析通过，Node 页面探针与 Chrome 全本地合成电信 DOM 验证通过。Xcode 工程静态解析、扩展嵌入/依赖接线与 plist 检查通过。公开仓库的 [iOS 验证工作流](https://github.com/huachen19867/liuliang-buddy/actions/workflows/ios.yml)使用 GitHub macOS 环境，运行 Flutter/Swift 回归、编译模拟器应用和扩展、安装启动及界面烟雾测试，不需要老板自备 Mac。对应原生构建结果以该工作流的提交记录为准，最终回执追加到技术日志。

最终 [macOS 云端验证](https://github.com/huachen19867/liuliang-buddy/actions/runs/36817117891)为 success，验证源码 `387c8a3329bd9316101515444d2533ca473ea172`。Xcode 16.4 / iOS 18.5 ARM64 模拟器通过 107 项 Flutter、analyze、Swift 快照检查、主应用及嵌入 Widget 扩展编译、独立冷启动和完整界面流程。首次启动的系统截图确认显示真实选择页，四张 Flutter 模拟器截图逐张目视检查并保存到 `artifacts/ios-*-simulator.png`，分别为选择、未连接首页、桌面添加指引和设置。设置截图中的 5 GB 是提醒阈值，不是号码余量；没有提供任何真实账号或示例余额。

安卓 [1.6.0 测试包](https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.6.0)为 `liuliang-buddy-debug.apk`，115,893,713 字节，versionCode 9、API 24 起、target API 36，Flutter 引擎仅 ARM64。使用与上一版相同的 Android Debug 证书，APK v2 验签通过，未启用 DEMO。SHA-256：`a251e90ac55ffcdd36057f8a057bdee102897d08bc12f5adceeb5d278e45647d`。构建、元数据及架构检查通过；历史版本保留。

模拟器产物是未签名的 Runner.app 压缩归档，不适用于 iPhone。真实 iPhone 安装需要 Apple 团队签名与 App Group provisioning；具体方法见 [IOS_BUILD.md](IOS_BUILD.md)。项目未上传证书、私钥或个人团队配置。

Release 的 `ios-simulator.tar.gz` 为正常应用入口的未签名模拟器构建，56,893,081 字节，SHA-256：`b5f39594fc16f463bb5abb896d0708c14a53092ff3105d6798cf92d4aed7d21d`。它在 smoke 测试重新编译测试入口之前归档，保留应用与扩展的执行权限和符号链接，仅供 macOS 的兼容模拟器使用。

尚未核对真实 iPhone 的四家官网登录、两号码隔离、重启会话与清理、通知权限和桌面小组件布局。模拟器界面测试使用空的测试偏好，没有真实账号或余额，原生通道不做 mock；这些测试不能代替真实运营商套餐验收。原理与范围见 [IOS_SESSIONS.md](IOS_SESSIONS.md)和 [IOS_WIDGET.md](IOS_WIDGET.md)。
