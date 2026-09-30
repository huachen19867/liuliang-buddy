# 流量小伙伴应用源码

Flutter 安卓双卡流量查询测试应用，当前版本 1.1.1+3。运行、构建、真实账号验证范围与完整目录索引见 [根 README](../README.md)。

lib/data 保存套餐模型与解析器，lib/services 保存官网响应探针和桌面数据桥接，lib/ui 保存双卡首页与添加卡片入口。android/app 使用 Kotlin 实现通知和标准 Android 桌面小组件；test 与 android/app/src/test 分别保存 Flutter/Node 与原生展示规则测试。vendor 保留 WebView 安卓依赖的许可证和 AGP 9 兼容补丁。

正常安卓构建不设置 DEMO；Web 预览必须显式设置 DEMO=true，并一直显示非真实流量标记。卡片显示运营商最近查询结果，点击打开 APP 更新，APP 关闭后不会持续联网查询。
