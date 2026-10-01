# 流量小伙伴应用源码

Flutter 安卓可选运营商流量查询测试应用，当前版本 1.4.0+7。运行、构建、真实账号验证范围与完整目录索引见 [根 README](../README.md)。

lib/data 保存套餐模型与解析器，lib/services 保存官网响应探针、桌面数据桥接和后台刷新执行器，lib/ui 保存首次选择、按所选运营商变化的首页与添加卡片入口。android/app 使用 Kotlin 实现通知、WorkManager 周期任务和标准 Android 桌面小组件；test 与 android/app/src/test 分别保存 Flutter/Node 与原生展示规则测试。vendor 保留 WebView 安卓依赖的许可证和 AGP 9 兼容补丁。

正常安卓构建不设置 DEMO；Web 预览必须显式设置 DEMO=true，并一直显示非真实流量标记。卡片显示运营商最近查询结果，点击打开 APP 更新。设置可选关闭、每小时、每两小时或每天后台查询；系统可能延迟。电信仍使用前台已渲染官网明细，后台会跳过，详见根目录 docs/WIDGET_BACKGROUND_REFRESH.md。
