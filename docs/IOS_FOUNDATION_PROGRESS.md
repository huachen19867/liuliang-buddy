# iOS 工程接入记录（2026-10-01）

开始前读取 TECH_LOG，复用已有 Flutter 与 Apple 参考；根代理下载并固定 home_widget 官方例子。生成 Flutter3.44.8 官方 iOS 模板到忽略目录后只复制 ios 子树，未覆盖 Android/Dart 文件。该版本默认 SPM 与 UIScene，现项目统一 CocoaPods，移除 SPM references/预处理脚本，保留 implicit-engine 插件注册及 SceneDelegate URL 回调。

新增真正的 TrafficWidget target、Runner target dependency、Embed App Extensions phase；共享 TrafficSnapshot 同时加入两个编译目标。最低系统17与 WKWebsiteDataStore identifier API 对齐。版本经 Widget.xcconfig 读取 Generated.xcconfig，两个目标分别设置 entitlements。

Windows PATH 的 python/python3 是 WindowsApps 空别名，不能假定能执行脚本；改用已有 Node 完成确定性项目写入。没有安装系统 Python，没有改全局缓存。macOS 编译和原生测试交给公开 Actions；本地只做结构/引用检查，不能把它表述为编译成功。

构建说明与可维护文件索引见 IOS_BUILD.md，自动检查入口 scripts/verify-ios.sh，流水线 .github/workflows/ios.yml。最终远程结果由根代理在技术总日志中记录。

本地结构验证通过：npm xcode 解析 OpenStep project，断言 Widget target、Runner 依赖、extension embed destination13 与所有 SOURCE_ROOT 文件存在；PowerShell XML 解析12个plist/entitlements/storyboard/scheme/workspace文件成功；git diff --check通过。原npm registry证书主机名不匹配，使用HTTPS npmmirror下载检查器到忽略的.tools目录，没有关闭TLS校验。AppDelegate messenger按当前SDK头文件使用applicationRegistrar。模拟器产物打tar.gz保持可执行权限和符号链接。
