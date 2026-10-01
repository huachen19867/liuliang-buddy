# 第三方参考与声明

移动响应解密参数、字段与单位处理参考 ChinaMobileMonitor；广电小程序参考字段来自 10099-Tracker。两者采用 MIT，以下保留完整声明。官网 H5 查询协议来自运营商公开业务脚本的静态检查，没有复制其 JS 业务代码。BroadnetFlowKeeper 无许可证，仅作为官方页面与会话字段的调研线索；没有复制其实现。DataMonitor 的 GPL 源码仅供权限限制研究，没有纳入应用。Flutter 与各依赖的授权信息可通过框架的 LicenseRegistry 查看。

桌面小组件机制参考 Google android/user-interface-samples 的 AppWidget 示例（Apache-2.0）。精选源码及原许可保存在本地 references/android-widget/，没有复制样例业务源码到应用；项目自己实现 RemoteViews 双卡布局与状态展示。引用版本和方法记录在 WIDGET_RESEARCH.md。

后台周期调度依赖 AndroidX WorkManager（Apache-2.0）。调度结构参考 Google android/architecture-components-samples/WorkManagerSample（Apache-2.0）；精选参考项目与许可证保存在本地 references/android-workmanager-sample/，未复制其业务 Worker 到应用。

## ChinaMobileMonitor

MIT License

Copyright (c) 2026 shiranzby

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 10099-Tracker

MIT License

Copyright (c) 2026 BiancoCat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

联通/电信研究新增 ChinaUnicomMonitor 与 FlowLite（未发现许可证）、ChinaTelecomMonitor（AGPL-3.0）。均只作为本地协议线索，没有复制代码或参考下载文件到发布范围；网页登录接入边界见 UNICOM_TELECOM_RESEARCH.md。

1.3.0联通协议来自iservice公开查询页与commonBase脚本的字段/单位事实，电信DOM结构及单位来自当前天翼账号公开业务组件。不复制运营商JS、签名或加解密实现。dompling/Scriptable历史网页登录方案无LICENSE，仅为本地调研线索；更多历史参考及当前替代证据见UNICOM_TELECOM_RESEARCH.md，参考下载文件不进入发布范围。
