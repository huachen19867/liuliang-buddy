# 联通 App 套餐解析进展

2026-10-02。任务开始已定位并阅读 `docs/TECH_LOG.md`，复用根任务下载的 `references/ChinaUnicomMonitor` 与 `references/unicom-solutions-20261002`，不重新下载重复项目。参考项目仅研究字段协议和响应处理，不复制无许可证实现。

独立源码位于 `app/lib/data/unicom_app_parser.dart`，合成回归位于 `app/test/data/unicom_app_parser_test.dart`，未修改共享 models、原官网解析器或查询服务。新增文件索引为本进展文档，并通知根任务接入总说明。

`parseUnicomAppPackage(Map<String, dynamic>, {DateTime? queriedAt, String? phoneMasked, int? httpStatus})` 返回 `CarrierSnapshot`。只能用于 `queryOcsPackageFlowLeftContentRevisedInJune` 的原始业务响应，成功码严格为字符串 `0000`。解析 `resources` 内 `flow` 与 `MlFlowdetailsList` 的 `details`，保留 `total` 与 `remain`；原模型没有独立已用字段，`use` 仅在 `remain` 真正缺失、总量和已用都可靠时计算剩余。接口明确返回零剩余时保持零，绝不改成总量减已用量。

ChinaUnicomMonitor 的 Cookie/Token 两份客户端将该精确端点流量字段按 MB 显示，因此没有单位字段时采用协议 MB；显式单位不存在有效值时保持未知，不沿用其他运营商的 03/04 单位码。计算使用十进制整数分数与 BigInt，避免浮点乘法溢出，超出 1 TiB 的异常套餐值拒绝。官方文字不限量标记可识别；套餐名、零总量、负数、超大数以及未证实的 limited 标志都不被推断为不限量。

分类仅依据两项名称中的明确“通用”“定向/专属/免流”字样，定向优先；不根据模糊“国内”或未经官方证实的 flowType 数字，把全表流量归入通用。资源层汇总不参与明细相加，跨列表相同套餐行去重；同名但值冲突保留不完整占位并停止对应分类合计，其他已确认分类仍可使用。共享关系缺乏可核验标识，界面提示以运营商套餐规则为准。voice/sms 单位证据不够，本变更不猜测其字段。

`parseUnicomAppBalance(Map<String, dynamic>, {int? httpStatus})` 仅接受 `accountBalancenew.htm` 成功响应的 `curntbalancecust` 元值，允许零和负余额，拒绝空值、泛化 balance、本月消费字段、非数及超限数字。套餐快照不自动读取话费；查询服务取得独立话费响应后才可 `snapshot.copyWith(balanceYuan: parseUnicomAppBalance(fee))`，话费失败不破坏已确认流量。

已编写 15 项有意义合成回归，覆盖协议 MB/明确单位、总用剩余、零余量、不限量拒绝猜测、多分类、总明细不重叠、跨列表去重、同名冲突、部分缺单位、认证/HTTP 错误、格式/数量边界以及话费缺失和负数。按根任务约束没有运行 Flutter/Dart SDK，最终格式化、analyze 与测试由根任务串行完成。没有真实联通账号响应，不将合成场景报告为真机或真实套餐验证。

根任务完成会话客户端初稿后，补充 `app/test/services/unicom_app_client_test.dart` 共 20 项纯 fake transport 测试：Cookie 查询的套餐/话费顺序、业务失败与非认证错误不续期、token-only 先续期、完整号码校验、拒绝续期失败及跨号码 Set-Cookie、凭证轮换和最多一次续期、话费失败保留流量、导入所有者确认/手机号冲突/控制字符、会话恢复、四个账号 secure storage key 隔离以及 debug 文本脱敏。审查发现旧 Cookie 不能证明新续期成功，新增“已有 Cookie 过期但续期无新 Set-Cookie 拒绝”和负 Max-Age 删除不能续期两项回归。测试只注入虚构响应，不访问网络，仍由根任务统一运行 SDK。
