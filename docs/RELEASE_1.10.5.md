# 1.10.5 桌面部分套餐摘要

上一版压缩了应用内电信明细，桌面组件仍只有严格合计。本版给桌面同步可读单项与缺项数：合计无法确认时明确显示“单项约 X GB”或“单项不限量”，不会把一项当成整卡合计。

没有有效分类和通话时，Android 桌面收起空格子，将单项预览放到更醒目的位置；两张卡和三、四卡布局都适配。缓存保留原时间，错误和登录失效提示优先；通知及快捷设置注明单项。点击组件进 APP 查看全部套餐，不在桌面展开长列表。

iOS 源码接入相同结构字段与单项提示，仍没有可安装的签名包。没有新增真实电信卡或手机桌面验收，不宣称缺项已经识别。

[正式安卓版](https://github.com/huachen19867/liuliang-buddy/releases/download/v1.10.5/liuliang-buddy-release.apk) · [对应源码](https://github.com/huachen19867/liuliang-buddy/tree/v1.10.5)

完整Flutter261项通过、analyze无问题；Android本项目强制重跑32项JUnit通过，新XML时间2026-10-02T11:33:30Z。两卡、三卡、四卡实际XML合成预览通过61个ID与可见性检查，已目视确认。Swift新增模型回归需macOS CI，不能用旧版云端结果代替。

[两卡桌面预览](../artifacts/widget-partial-2-preview.png) · [三卡桌面预览](../artifacts/widget-partial-3-preview.png) · [四卡桌面预览](../artifacts/widget-partial-4-preview.png)，均为合成数据，非手机实拍。

Release构建41.5秒成功，1.10.5/code22、ARM64/API24-36、非debuggable、v2正式证书33b115558027fdfa667a3f14a9351fbdb29901948c085daf739e16a9055a497e、16KB ZIP对齐通过。APK28,039,020字节（28.04MB），SHA256 f88a7eadf0cebbee95645bfc93097d8228d0fb3bafff1263d4a5ca60307fa048，仅发布一个APK。

公开发布回读：draft=false/prerelease=false，target/tag为64dad650dd7097534c6db106aa1add443ade3e42，唯一APK上传完整，远端SHA256与本机一致。iOS本版 [run37002298627](https://github.com/huachen19867/liuliang-buddy/actions/runs/37002298627) 尚在运行。
