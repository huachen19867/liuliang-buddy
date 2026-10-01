# 1.8.0 通知栏、快捷设置与安卓 Release 分发

**安卓下载：**[下载正式版（18.35 MB）](https://github.com/huachen19867/liuliang-buddy/releases/download/v1.8.0/liuliang-buddy-release.apk)。公开分发仅保留这一份安装包。旧测试版需自行卸载后安装并重新登录，卸载会清除应用本地记录。

适用 Android 7.0 及以上 ARM64 手机。iPhone 暂无可安装的签名包。GitHub 自动生成的 Source code ZIP / TAR.GZ 是源码，手机安装不需要下载。

安卓“提醒设置”新增通知栏余额与快捷设置入口两个开关，默认关闭、即时保存。通知展示各账号最近查询的流量、状态和原时间；点击打开应用。通知权限或渠道被关时说明原因，不假报开启成功。Android14允许划掉普通持续通知，后续查询更新时可以再次显示。

快捷设置入口启用后还要添加到系统面板。Android13起请求系统确认，取消不算添加成功，可重试；旧版通过下拉菜单编辑手动拖入。磁贴显示缓存摘要，点击打开应用并触发前台查询，不增加新的后台周期。两项仅安卓提供，iOS设置隐藏。

唯一安装包 `liuliang-buddy-release.apk` 使用独立发布证书、Release AOT、代码/资源裁剪、ARM64。旧证书过渡包已撤下，不再维护双分发渠道。详细构建与密钥管理见 [安卓分发说明](ANDROID_RELEASE.md)。

实际界面组件截图标注演示，不代表系统原生通知或磁贴实拍。真实各省套餐、实体手机通知授权/渠道、下拉面板和 Release 长期后台行为仍需复测；iOS没有签名iPhone安装包。

完整Flutter130项、analyze、应用原生JUnit16项（系统入口3、Widget12、调度1）通过。正式包18,350,307字节，约18.35MB，比旧91.44MB减少79.93%；SHA-256 b8943da4629e17a03c5f74b9e69d9822335c8dea6c9ab99d442d51151f7ee88c，证书33b115558027fdfa667a3f14a9351fbdb29901948c085daf739e16a9055a497e。非debuggable、v2验签通过，API24/36，只有arm64-v8a，未启用DEMO。iOS共用界面的最终源码云端验证[run36838979981](https://github.com/huachen19867/liuliang-buddy/actions/runs/36838979981)进行中，本次1.8.0仅分发安卓包与设置组件截图，不沿用旧版模拟器产物。
