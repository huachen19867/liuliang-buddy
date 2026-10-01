# 1.8.1 启动闪退修复

安卓正式版唯一下载：[liuliang-buddy-release.apk](https://github.com/huachen19867/liuliang-buddy/releases/download/v1.8.1/liuliang-buddy-release.apk)，18.38 MB。已安装 1.8 正式版可直接覆盖升级，不需要卸载或清除数据。旧 Debug 测试版签名不同，不能覆盖。

荣耀 Android 16 真机复现 1.8 冷启动退出：`InitializationProvider → WorkManagerInitializer → Room` 反射创建数据库时报 `NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init>[]`。原 Room 消费者规则保留了类名，却没有保留无参构造函数。新增精确的构造函数保留规则，继续使用 Release AOT、R8、资源裁剪和原正式证书，不关闭优化或删除数据库。

本修复在隔离工作树构建，产品变化仅为保留规则及版本号；正在进行的角色、备注与界面改版没有混入此包。1.8 原包在同机复现崩溃，1.8.1 同签名覆盖安装成功，ADB 冷启动进入首次选择页、进程持续运行，之后崩溃缓冲区没有新增本应用异常，老板也确认安装后正常。尚未对 iQOO 13 或所有其他手机实测，不把一台真机通过等同全部机型验收。

APK versionName=1.8.1、versionCode=12，API24/36，仅 ARM64，非 debuggable，v2 签名通过。SHA-256：`59fe631319748e3ed998ae134cf3a89c6e781856d0fd4a0f1be4adbe66b53caa`。正式证书 SHA-256：`33b115558027fdfa667a3f14a9351fbdb29901948c085daf739e16a9055a497e`。大小 18,383,087 字节。

原始设备日志和系统截图只保存在忽略目录 `.tools/android-crash/`，不上传个人设备数据。后续发布必须核对最终 Release 的 Room 构造函数保留和实际冷启动，不能仅凭 Debug 单元测试通过认定正式包启动正常。
