# 账号备注、分类余额与官网金额

2026-10-01。入口技术日志为 `docs/TECH_LOG.md`，本轮复用已下载的 ChinaMobileMonitor MIT 源码、`references/allowances/` 官网证据片段与既有协议研究，不引入第三方业务库，也不读取 SIM、短信或登录输入框。

`CarrierAccount` 新增可选 `note` 与手工输入的 `phoneNumber`，`displayName` 优先使用备注，`phoneHint` 只显示遮盖中间部分的号码。备注最多 20 个 Unicode 码点，不能包含控制字符；号码允许 7–15 位数字及可选的开头加号，短号码也隐藏至少中间两位。编辑只改变显示身份，不改变官网会话、账号 ID、Profile 或快照键。旧 `carrier_accounts_v1`/schema 1 保持兼容；旧记录没有可选字段正常恢复，可选字段损坏不丢弃有效账号。清除本地连接会清除手工备注及号码。

`main.dart` 打开带验证的备注弹窗，串行持久化成功后更新首页与桌面展示。后台发布前重新读取账号显示身份，避免任务执行期间编辑备注后又发布旧备注。没有自动从官网表单或 SIM 获取号码。

`CarrierSnapshot.balanceYuan` 为可空官方金额。电信既有公开 Account 组件中 `#balanceModal #mobileBalance` 邻文“余额/元”，源值 `totalBalanceAvailable` 除以 100，且官网以 `serviceResultCode == 0` 门禁渲染。仅接受当前官网 DOM 采集的 `balanceText`，严格数字（允许负值与最多两位小数）加“元”；未提供或格式未知保持 null。移动/广电/联通现有查询响应没有充分金额字段证据，本轮不猜字段。尤其广电 `balance/highFee` 为套餐额度，不能直接当人民币。官网响应失败时，已有金额随原查询时间保留，状态继续显式显示失败。

新增分类摘要 `summarizeTrafficGroup(snapshot, kind)`。完整且单位明确才相加，任一缺项拒绝部分和，任一明确不限量时输出不限量状态与空数值，空组保持未提供。移动 `流量总览` 不参加“其他”的和；联通唯一官网套餐汇总不可解释为“其他”，既有主值仍可显示“套餐余量”。电信套餐流量按官网已用/总量的舍入值估算，摘要标记估算。语音使用 `summarizeVoice`，优先唯一官网汇总，其余仅在单一语音项目时返回，多套餐不猜测无重叠而相加。字段用途未知始终不会进入通用或定向。

桌面 `schema=2` 保持兼容旧主值字段，`instances` 新增展示白名单 `name`、脱敏 `phoneHint`、`balanceYuan`、`generalRemainingBytes/generalState`、`directedRemainingBytes/directedState`、`otherRemainingBytes/otherState`、`trafficEstimated`、`voiceRemainingMinutes/voiceState/voiceEstimated`。State 为 `provided`、`unlimited`、`unavailable`；完整号码、原始响应和会话凭据不进入 payload。Android/iOS 原生白名单与布局由根代理同步。

Android 原生接入随后由本数据代理完成：`WidgetCardData` 扩展上述字段，`WidgetAccountDetails` 入口与缓存恢复二次过滤完整号码/凭证和金额/分类值，整宽纵向卡左身份右四格、尺寸不足显式显示隐藏卡数。详情与原生回归说明见 `WIDGET_RESORT_PROGRESS.md`。iOS 布局与素材、统一构建仍由根代理处理。

联通新增 `unicomSession` 失效信号来自严格官网 checklogin 场景，main 和后台同时校验固定单键 `isLogin=false` 与 HTTP 成功后结束等待，沿既有 authExpired 分支保留快照并要求重新验证。信号协议与官网探针证据由研究代理记录。

新增 `account_identity_test.dart`、`account_group_summary_test.dart`，扩展电信金额解析回归，覆盖旧记录兼容、独立账号键、备注/号码校验、短号码脱敏、清除、金额缓存原时间、严格人民币格式、分类不重复相加、缺项/不限量与桌面仅脱敏字段。按根代理要求，本代理没有运行共享 Flutter/Dart/Gradle 命令；格式化、静态分析与完整验证由根代理统一进行，结果随后并入技术日志。真实官网登录、余额核对与设备显示仍需真机验证。
