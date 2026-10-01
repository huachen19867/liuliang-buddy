# 安卓正式分发构建

1.8.0 开始，GitHub 主下载提供 Release 模式的 ARM64 APK，Dart AOT、R8 和资源裁剪启用；不带 Debug 调试运行时、不启用 DEMO。Release 使用独立 RSA 发布证书，不回退到 Android Debug 签名。正式构建不表示已经取得应用商店上架审核或验证了所有运营商套餐。

本工作区使用 `scripts/build-android.ps1 -Mode Release`。签名配置由 `LIULIANG_KEYSTORE_FILE`、`LIULIANG_KEYSTORE_PASSWORD`、`LIULIANG_KEY_ALIAS`、`LIULIANG_KEY_PASSWORD` 四个进程环境变量注入，Gradle 没有签名时会拒绝 Release 任务。外部开发者须使用自己的私有证书，不能从公开仓库获得项目的发布密钥。

当前私钥仅保存在被 Git 忽略的 `.tools/signing/`，目录权限限当前 Windows 用户和 SYSTEM。凭证通过 Windows DPAPI 存为 `release-credentials.xml`，只有相同用户与机器可直接读取；同目录有一份密钥文件备份，不能替代用户另外保管的离线备份。不能把密钥、密码、凭证 XML 或 key.properties 上传 GitHub。丢失证书会影响后续升级；版本证书摘要在发布回执中记录。

公开下载只提供 liuliang-buddy-release.apk，统一使用独立发布证书，后续升级继续沿用该证书。旧公开测试包采用 Android Debug 证书，不能直接覆盖；旧测试版用户需自行卸载后安装正式版并重新连接号码，卸载会清除应用本地记录。旧证书过渡包已撤下，不再作为公开分发渠道。

构建脚本只生成正式签名包，已移除旧证书过渡包的构建分支。历史 Debug 下载留在历史版本，最新下载不提供 Debug 包。应用最低 API24、目标 API36、仅 ARM64；32位和x86手机不适用。

构建后必须核对 versionName/versionCode、签名摘要、非 debuggable、CPU 架构、权限、字节大小和 SHA-256；检查原生测试、Flutter 测试与静态分析。R8 对 WebView JavascriptInterface 的保留来自插件 consumer rules 和应用规则，Flutter 后台入口仍保留 `@pragma('vm:entry-point')`。未连接实体设备时，系统通知/磁贴添加和 Release 后台查询必须注明尚待真机复测。
