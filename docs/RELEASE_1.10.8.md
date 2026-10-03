# 1.10.8 电信其他流量显示已读数字

电信其他流量中有一项无法读取时，旧版把整个类别显示为待确认，即使其他项已经读到。本版把可读有限余量相加，显示“已读约 X GB”及未计入项数；原始缺项保留在其他明细，不用零替代，不再遮住已读数字。

名称含“定向”的仍归定向，其余仍归其他，手动分类优先。未知单位、没有余量或不限量不制造数值，类别部分合计不冒充完整套餐总量，同名组仍保留原始子项。共享或重叠额度以官网为准。

APP 类别框和说明、Android 两卡/三四卡布局与缓存同步该部分数字；iOS 源码增加其他已读副行及旧缓存兼容，编译结果由 macOS CI 另核。

Flutter292项/13秒、analyze无问题、Android本项目35项（新XML时间2026-10-03T06:10:14Z）通过。Release59.6秒构建成功，版本1.10.8/code25，APK28,104,532字节（28.10MB），SHA256 `81bd97686278c856b4bc25f0b5d7f872f36cbb1fdf586f49f5da75e121f3a171`，正式v2证书33b11555、API24/36及16KB ZIP对齐通过。GitHub公开回执待补。没有连接电信真实账号或手机；截图是使用实际组件与 XML 的合成预览，不是用户数据。

协议见 [其他部分合计](TELECOM_OTHER_PARTIAL.md)，APP 展示见 [部分明细界面](TELECOM_PARTIAL_UI.md)。

[APP合成预览](../artifacts/telecom-partial-preview.png) · [双卡桌面合成预览](../artifacts/widget-other-partial-2-preview.png) · [四卡桌面合成预览](../artifacts/widget-other-partial-4-preview.png)。