# 输出索引

ui-preview.png 为应用 UI 实际组件渲染的预览，使用演示数据，不能证明真实手机号流量查询准确性。顶部显示“界面演示 · 非真实流量”。

broadnet-summary-preview.png 为广电套餐明细合计卡片的演示预览，展示用途未分类明细可识别时的余额合计与规则提示。截图中的数值仅用于展示，顶部显示“界面演示 · 非真实流量”，不代表真实账号余额或精度。

liuliang-buddy-debug.apk 为 1.1.2+4 安卓个人测试包，89,489,653 字节（约 85.3 MiB），Android 7.0/API 24 及以上，目标 ARM64 手机。它使用调试签名，未使用 DEMO 编译参数。首次安装后两个号码需分别在官方网页完成验证，已有版本可覆盖安装。下载见 [GitHub Release](https://github.com/huachen19867/liuliang-app/releases/tag/v1.1.2)，私有仓库需要有权账号登录。

android-build.log 保存成功的本地安卓构建输出；apk-signature.txt 为 apksigner 签名检查（v2 通过，Android Debug），apk-metadata.txt 为 aapt2 元数据检查（名称、版本、SDK 与权限）。应用申请网络与通知权限，没有短信读取权限。本目录不含真实号码、验证码、登录凭证或成功账号的原始响应。

APK SHA-256：711c032453868810d57d5319883b657907d95ac1cc8fe63b86ca0a7151b90954。

此版本修复广电已同步但主数值为空的摘要显示，首页与桌面使用“套餐明细合计”，用途以各套餐规则为准，不参与通用汇总/提醒。完整 Flutter 37 项测试、原生 6 项展示测试、静态分析及 Node 探针检查通过。收到用户真机查询同步反馈，新版摘要和 Launcher 添加/缩放/点击仍待真机核对。卡片显示原查询时间，点击打开 APP 更新；不会在亮屏时自动向运营商联网。

可交互 Web 演示位于 app/build/web/，以 DEMO=true 构建，需通过本地 HTTP 服务访问。源码与运行说明见根 README.md。

## 1.2.0 输出

carrier-selection-demo.png、dashboard-single-demo.png、dashboard-multiple-demo.png、carrier-settings-demo.png 分别为首次选择、移动单卡、移动/广电组合和运营商设置。来自真实Flutter组件渲染，明确标注DEMO，不含用户账号或真机图片。

当前APK更新为1.2.0+5，113,901,232字节，SHA-256：fba83e5088d1fcd6143364a483d605542c5d99e39ccb11544b2f273082e97f8b，v2签名通过，API24/36、ARM64、Android Debug。历史1.1.2记录见上文，公开发布目标 https://github.com/huachen19867/liuliang-buddy/releases/tag/v1.2.0 。
