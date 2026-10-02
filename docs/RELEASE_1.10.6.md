# 1.10.6 电信套餐分类与同名合并

根据用户明确指定的产品规则，电信套餐名称包含“定向”时自动归入定向流量；其余名称，包括“国内上网流量”“国内上网含5GB”“专属”“通用”等，自动归入其他流量。该规则是应用分类，不是运营商已确认的适用范围；不从名称里的容量制造剩余额。

解析新结果、恢复旧缓存和后台发布均使用相同规则。用户手动分类优先；原查询时间和余额保持不变。首页将电信默认的“用途未知”改为“其他流量”，桌面同一类别同步展示。其他运营商已有官方字段分类保持原规则。

根据用户追加决定，电信完整名称相同的子项在首页合并成一项，全部余量有效时相加并标记“合并约”。原始子项保留在详情内，合并是应用的估算展示，不证明各项独立可用。有缺项、单位不明确或异常数值时该合并项待确认；混合有限与不限量也不生成有限合计。其他运营商的折叠规则保持原状。

[正式安卓版](https://github.com/huachen19867/liuliang-buddy/releases/download/v1.10.6/liuliang-buddy-release.apk) · [对应源码](https://github.com/huachen19867/liuliang-buddy/tree/v1.10.6)

完整Flutter278项/28秒通过，analyze无问题；Android本项目32项原生JUnit强制重跑通过，XML时间2026-10-02T12:16:49Z。实际FlowHome缓存恢复到组件MethodChannel用例通过，单位、缺项、溢出、手动优先、旧缓存重算、同名合并和小屏大字均有回归。

[APP分类与同名合并预览](../artifacts/telecom-directed-other-partial-preview.png) · [同名多项合并预览](../artifacts/telecom-partial-preview.png) · [四卡桌面分类预览](../artifacts/widget-classified-4-preview.png)。APP为实际Flutter合成渲染，桌面为实际XML合成预览，均非真号/手机实拍。

Release构建36.1秒成功，1.10.6/code23，APK28,038,996字节（28.04MB），SHA256 `88f93678dad92b84b468259abdd08e7082788a43233f5a11d6039a070e6a6fff`。正式v2证书 `33b115558027fdfa667a3f14a9351fbdb29901948c085daf739e16a9055a497e`，非debuggable、ARM64/API24-36、16KB ZIP对齐通过。仅发布一个APK，不含任何实际账号或签名凭证。
