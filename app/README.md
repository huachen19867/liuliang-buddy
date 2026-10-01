# 流量小伙伴应用源码

Flutter 安卓可选运营商、多账号流量查询测试应用，当前版本 1.5.0+8。运行、构建、真实账号验证范围与完整目录索引见 [根 README](../README.md)。

lib/data 保存套餐与稳定账号模型、旧键迁移及解析器，lib/services 保存官网响应探针、桌面数据桥接和后台刷新执行器，lib/ui 保存选择、双击添加第二张卡、逐账号首页与桌面添加入口。android/app 使用 Kotlin 实现通知、WorkManager 周期任务和标准桌面组件；test 与 android/app/src/test 保存 Flutter/Node 和原生回归测试。vendor 保留 WebView 依赖的许可证、AGP 9 补丁和 AndroidX WebKit 独立 Profile 接口。

正常安卓构建不设置 DEMO；Web 预览必须显式设置 DEMO=true，并一直显示非真实流量标记。每家最多两个账号、同时最多展示四个；第二账号须 WebView MULTI_PROFILE 可用，绑定失败停止导航。桌面未弹出系统确认时提供长按桌面“小组件”手动入口。设置提供关闭、一小时、两小时或每天后台尝试，以及最近实际尝试状态；电信后台跳过。源码与回归不代表 S25 Ultra 或真实官网余额已验证；iOS 暂无安装版。详细支持范围见根目录 docs/USER_FEEDBACK.md。
