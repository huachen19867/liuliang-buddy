# 电信名称分类的数据实现

2026-10-02，老板确定电信明细的自动分类规则：名称包含“定向”就归入定向流量，其余不能明确用途的名称都归入其他流量。复用本工作区 `references/dlife-public/protocol-excerpts.txt` 的官方 Account 归档和既有 FlowLite 分组研究，不重复下载或引入第三方业务代码。官方模板按两层 `items` 逐条展示 `ratableResourcename`、已用量及总量，没有可用于去重的稳定业务 ID；此次沿用逐行保留的解析方式。

新增 `app/lib/data/telecom_name_classification.dart`，唯一 helper `classifyTelecomTrafficName` 按字面包含“定向”返回 `BucketKind.directed`，否则返回 `BucketKind.unknown`，界面将后者展示为“其他流量”。“国内上网流量”“国内上网含5GB”“专属”“通用”均不会据此推断为通用或定向；名称同时出现“定向”和其他词时仍归定向。名称里的 G、GB 或数字不参与用量计算，也不补齐缺失单位。

`parseTelecomRendered` 在创建每一项时调用该 helper。既有 source 校验、200 项上限、单位换算、已用量和总量校验、不限量保护及失败门禁保持生效；有“定向”的无效用量项可以得到用途分类，但余量仍为 null。同名条目不删除、不合并，每条原始余量和顺序仍保留。其他运营商解析规则没有修改。

`TrafficClassificationOverrides.apply` 对电信快照先用相同 helper 重算 `kind`，因此旧版本已经缓存成 unknown、general 或 directed 的名称会在既有前台恢复、返回前台和后台发布路径上获得新规则。随后去掉缓存中的旧 `manualKind` 并应用最新独立配置；唯一非空名称的已保存手动分类仍优先，恢复自动后回到名称规则。同名名称继续不套用手动覆盖，暂不生效的配置保留。移动、广电和联通的原始 `kind` 不被此规则改变。

类别变化经原有 `effectiveKind` 和摘要逻辑传至首页及系统卡片；分类操作不制造新查询，不改变 `queriedAt`、话费、状态、通话、短信、有限用量或不限量标记。模型、原有整体摘要、类别合计与组件协议没有改变。

回归准备在 `app/test/data/telecom_rendered_test.dart` 新增 3 项，在 `app/test/data/traffic_classification_test.dart` 新增 5 项，覆盖定向优先、国内名称及容量词不影响用途、数值有效性独立、同名保留、旧缓存迁移及重复 apply、重启还原的手动优先与恢复自动、后台最新分类覆盖后的组件字段、其他运营商不变。后台用例复用实际 `restore → apply → buildWidgetPayload` 数据链，未冒称真实后台 FlutterEngine 或真实电信账号验收。本子任务完成 diff 检查，未运行 Flutter/Dart SDK；最终测试与静态分析由根任务串行运行并写技术日志。

老板随后明确同名子项在界面归为一项，并授权用各子项估算余量相加。新增 `traffic_summary.dart` 的 `summarizeTelecomNamedGroup(Iterable<TrafficBucket>)` 作为这一展示行的计算入口，原始 `snapshot.buckets` 不删除或改写，仍可展开核对。输入必须全部具有相同的非空完整 trim 名称与一致的 `effectiveKind`；全部有限项都具有已确认单位和非负余量时，按 64 位边界安全求和，返回完整且 `isEstimated=true` 的 `TrafficGroupSummary`。不同名称、不同用途、缺项、负数、未知单位或溢出均不返回部分合计；零值是有效余量。

同名组全部具有显式不限量标记时，返回不限量且不制造有限数值；有限项与不限量混合时返回 unavailable，避免把有限子项遮成整体不限量。该函数只服务电信同名展示，不改变既有 `summarizeTraffic` 或 `summarizeTrafficGroup` 算法。`app/test/data/telecom_named_group_summary_test.dart` 准备 7 项回归，覆盖不同余量相加、trim、原始数据保留、缺项、不同名称及用途、负数和单位、边界溢出、全不限量和混合项。新增回归同样待根任务串行 SDK 验证。
