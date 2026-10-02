# 套餐用途手工纠正的数据契约

2026-10-02，复用现有运营商解析与 `traffic_summary.dart`，不引入另一套查询或汇总实现。截图反馈要求在单个套餐明细里允许选择通用、定向，以及恢复自动识别。

`TrafficBucket.kind` 保持运营商解析的原始识别值。新增 nullable `manualKind`，`effectiveKind` 返回手工值或原始值；`copyWith(manualKind: null)` 恢复自动。旧缓存缺少新字段仍可恢复，新缓存只接受 `general` / `directed` 手工值，非法值忽略。手工选择不会改变余量、总量、单位、不限量标记、话费、语音、状态、原始查询时间。

`TrafficClassificationOverrides.restore(String?)` 读取本地配置，`storageKey` 是 `traffic_classification_overrides`，`toJson()` 输出 `schema: 1` 和 `accounts: {稳定账号ID: {精确trim后的套餐名: general|directed}}`。不保存手机号、Cookie、余额或查询时间。只认可四家既有账号 ID 及 `_2` 至 `_4`；同运营商的各账号完全隔离。

`apply(accountId, snapshot)` 先去除全部旧缓存 `manualKind`，然后按当前账号、当前快照唯一的非空套餐名应用配置。乱序或额度变化不影响匹配；同名套餐全部不应用。不能按列表序号或相似额度匹配，不进行模糊搜索。暂时消失或因重名不应用的配置不被删除，后续仍可恢复。解析未知 schema 或错误配置时忽略不合法项，保留仍合法的存量项。竞争的 trim 名称不任意选择其一。

`withOverride(accountId, snapshot, bucket, kind)` 返回不可变新对象，`null` 删除该套餐纠正，`unknown` 不作为可保存的手工选项。`withoutAccount(accountId)` 用于用户更换账号身份或清除该账号。调用者应在改号码、清理数据时同步调用，暂时隐藏卡片无需删除设置。

`canOverride` / `unavailableReason` 仅允许当前快照中唯一非空名称。中国移动“流量总览”和联通“官网套餐余量”/“官网不限量套餐”是跨用途汇总，不能手工归类，也不能混入分类合计。无效额度和未知单位可以纠正用途标签，但手工分类不会使它们变成确认的流量。不限量继续显示不限量，不生成有限数值。

`CarrierSnapshot` 通用余额 getter、应用首页摘要、各用途汇总统一使用 `effectiveKind`，组件继续复用同一摘要。摘要名称保留原有“通用剩余”等原生协议白名单。未知单位的手工通用行会阻断已确认通用合计，负数、缺数、不限量、64位溢出保护继续生效；没有改变查询时间或冒称新查询。

回归测试位于 `app/test/data/traffic_classification_test.dart`，覆盖原始分类保留、查询事实不变、账号隔离、乱序刷新、恢复自动、重复名称、汇总拒绝、配置恢复、非法输入、未知单位、不限量、零值与组件一致性。本子任务不运行 Flutter/Dart SDK，最终静态分析与测试由集成任务串行运行并记录回执。
