# 电信其他类别的部分已读估算

## 数据与组件协议

2026-10-03，老板明确要求难以区分用途的电信套餐继续归“其他”；金额缺失不能遮住同类别已经读到的数字。本轮复用 TECH_LOG 及 references/README.md 中已下载的 FlowLite 分组研究、dlife-public 官网 Account 明细归档和既有 AppWidget/WidgetKit 参考，不重复下载或复制第三方业务代码。

`summarizeTrafficGroup` 仅对电信 `BucketKind.unknown` 开放部分已读估算。按 `effectiveKind` 收集类别，因此手动选择通用或定向仍优先。原始套餐明细、分类和查询时间均不改写；没有读取时刻或账号未连接仍返回不可用。错误、刷新中、授权过期的缓存保留原快照数值与时间，展示端仍须表明对应状态。

计入估算的行必须有非空名称、已验证流量单位、非负且不超 Int64 的有限余量；如有总量，必须不小于余量且不超 Int64。缺余量、未知单位、负值、数值矛盾和不限量行不转换成数字，不拿套餐名字里的 5G 生成余量，不把 null 当零。至少一个可读有限项与未计入项同时存在时，`remainingBytes` 返回可读项相加，`isComplete=false`、`isPartial=true`、`state='partial'`、`isEstimated=true`，`pendingCount` 表示未计入有限估算的行数。已读零仍是部分结果。所有有限项有效则为 provided；没有可读有限项时 unavailable，明确且无数值矛盾的不限量仍显示 unlimited。Int64 相加溢出时不返回数值。

通用/定向、其他运营商、全量主余额及电信同名合并行维持原完整合计门禁；本次类别部分合计不把主余额或同名组变成完整值。读到的电信金额仍是官网显示值估算，相加不能保证共享或重叠额度是独立余额。

`widget_bridge.dart` 的 schema2 instances 发布 `otherRemainingBytes`、`otherState='partial'`、`otherPendingCount`（上限 200），保留现有第一条可读套餐预览、全局读取计数及主余额字段。其他类别状态不引入 partial，原始套餐名和运营商字符串不跨原生边界。

数据回归新增两条 5GiB 加一条缺项、全部未读、已读零、单位/数值矛盾、不限量不造数、Int64 溢出、手动归类、缓存状态/时间门禁和其他类别/运营商边界；组件回归改为确认部分 other 合计而主余额仍不可用，并覆盖 pending 上限。子任务只完成源码与静态 diff 检查，未运行 SDK；Flutter、原生和发布验证由根任务统一串行执行，真实电信会话与设备仍需另验。

## 系统展示与验收

Android只为电信otherState允许partial，要求有效有限字节与1..200待确认项数，缓存保存恢复otherPendingCount。双卡右侧其他栏显示已读约数，三四卡紧凑摘要保留其他已读和待确认数，主合计/低量提醒不使用这个部分和。Swift新增optional其他部分字段与副行，旧Codable兼容，限定电信、已知状态、正常时间和数值；未将部分other替换主值。Windows未编译Swift，macOS CI另核。

最终Flutter292项/13秒、analyze无问题，Android本项目35项新XML时间2026-10-03T06:10:14Z强制重跑通过。APP合成图目视已读约276GB与1项待确认清楚，双/四卡XML合成图其他已读约10GB清楚，非用户账号。根版本编辑命令误用执行目录的0字节文件已确认自行产生并移除，项目无额外pubspec。正式分发回执见RELEASE_1.10.8.md。
