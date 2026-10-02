# 1.10.4 电信部分数据与明细压缩

电信官网明细有可计算余量但合计不能确认时，首页明确展示部分同步和可读取项数，不再让巨大空值和“已同步”掩盖缺项。未知项继续保留，不能从部分明细制造完整合计。

套餐按完整名称折叠，同名组显示项数，进入组后保留每项余量和详情；不按截断名称或相同余量去重，不把可能共享的套餐相加。首页限制展开长度，空通话、短信和分类占位在这个场景收起。没有号码时不再显示“号码未备注”。

复用既有官方 Account 模板归档和浏览器回归。模板本身逐项渲染套餐，目前没有重复抓取的证据，也没有该账号原始明细；本次改善展示，不宣称所有电信套餐已能精确查询。桌面仍沿用可确认合计，缺项时保持待确认，不发布局部求和。

[正式安卓版](https://github.com/huachen19867/liuliang-buddy/releases/download/v1.10.4/liuliang-buddy-release.apk) · [对应源码](https://github.com/huachen19867/liuliang-buddy/tree/v1.10.4)

完整 Flutter 251 项通过，静态分析无问题，官网探针13组合成本地浏览器回归通过。包含320像素宽/1.4倍字体、分组逐项查看、后续页分类、嵌套弹窗关闭以及0项流量可确认时不标部分同步。没有改原生代码，不重复原生JUnit；没有新增真实电信账号或真机验收。

[压缩后的首页预览](../artifacts/telecom-partial-preview.png) 为实际 Flutter 渲染，使用24项合成明细并标记非真实数据。

正式 Release 构建163.4秒成功，版本1.10.4/code21，APK28,038,456字节（28.04MB），SHA256 `ca4a847f6fdfedd5e4d986627a2b0586f18b034a65d8a69b83938ea8271bc00f`。v2正式证书 `33b115558027fdfa667a3f14a9351fbdb29901948c085daf739e16a9055a497e`，非debuggable、ARM64、API24/36及16KB ZIP对齐通过。公开Release仅放一个APK。

公开发布回读确认非草稿/非预发布，tag与target为5b306ec2c8378507b2d753034a696c97eaf2fea7，唯一APKuploaded且远端digest与本机一致。iOS本版云端验收 [run36999305137](https://github.com/huachen19867/liuliang-buddy/actions/runs/36999305137) 仍在运行，不标为通过。
