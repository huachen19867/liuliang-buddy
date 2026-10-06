# 查询轮次与旧回包隔离

2026-10-06。复用 `docs/TECH_LOG.md` 中前后台查询竞态记录、现有 `responseCaptureScript` 私有 webpack jQuery 捕获、移动余额 DOM 和电信 Account DOM 方案，没有另引入查询框架或重新下载参考工程。

`app/lib/services/query_round.dart` 新增 `QueryRoundRegistry`。`begin(accountId)` 为单卡开始新轮并返回短字符串 epoch；`current(accountId)` 读取当前轮，`isCurrent(accountId, epoch)` 只接受当前非空轮标识。`finish(accountId, epoch)` 只结束仍匹配的轮，旧响应不能清除同卡新轮；`cancel(accountId)` 取消一张卡，`clear()` 取消全部卡但不重置序号。内部随机实例 nonce 和单调序号不含账号、手机号码、令牌或运营商凭证。

`page_probe.dart` 的网络桥接事件增加可选 `queryEpoch`。XHR 在 `send`、fetch 在实际调用前捕获 `window.__liuliangQueryEpoch`，响应到达和读取 body 时仍使用原值。广电全局与私有 jQuery 的 `ajaxSend` 用 WeakMap 保存原 settings 对象对应的开始 epoch，`ajaxSuccess` 解包结果只携带它，既不修改官网 settings，也不把成功时的最新轮次赋给未观察到开始的旧请求。桥接未准备好的有界队列保存完整原 payload，ready 后不能升级其 epoch。

移动余额 DOM 在本次 scan 开始取得文档 epoch，电信 Account scan 同样记录采集时 epoch。电信延迟桥接保留 `body + queryEpoch`；bridge ready 先重新核对 Home 路由和完整组件，组件消失或登录时清除旧队列，同 body 待发送记录仍保留最初 epoch。明确的 `__liuliangTelecomRescan` 会清掉旧 pending 并重新读取当前 DOM，供电信 SPA 查询使用。没有 epoch 的旧脚本环境完全省略这个字段，不增加 `queryEpoch: undefined`。

这里仅实现查询身份原语和采集端标记；前台、后台如何开始轮次、在 document start 优先安装 epoch、拒绝旧事件和结束轮次由根任务接线。正常全页面刷新应在新 document 注入新 epoch，不通过在旧 document 修改变量来令旧网络请求变成新轮。电信 SPA 显式重读当前组件属于调用方处理的例外。

新增 `query_round_test.dart` 四组回归，覆盖双同运营商账号独立、旧 finish 不清新轮、取消与 clear 不复用身份及短非敏感 token，Flutter/Dart SDK 尚待根任务统一串行验证。扩展已有 page/mobile Node 脚本及新增 `telecom_epoch_probe_js_test.cjs`，验证请求开始后换轮、请求早于 epoch 安装、私有 jQuery、延迟队列、DOM重新采集、登录和组件清空边界；三份 Node 回归已经执行通过。

实际 Chrome 的旧移动余额 17 类本地合成场景通过，广电真实公开业务 jQuery 双实例加本地拦截响应通过，没有登录、发送短信或读取真实账号。电信旧 Chrome 回归首次发现 ready 先 flush 会越过组件清空门禁，保留原断言并恢复先 scan 校验；修复后完整 13 类 Chrome 场景通过，15 次导航全部本地拦截、没有官网请求。广电浏览器脚本另增加 `--query-epoch`，可以与 `--delayed-bridge` 一起验证真实私有 jQuery 与 XHR 在迟到响应及桥接恢复时仍保留开始 epoch。没有真实长期账号或设备验收，epoch 也不替代当前账号和当前会话检查。

根已接入真实 FlowHome：每轮先替换 document-start epoch 脚本，再加载新文档；所有异步恢复、提交、持久化和广电备份都检查当前轮。移动已收到流量后另保留9秒收尾期限，两次getUrl各2秒。原生无epoch错误不结算轮次；广电登录页先读取当前URL/核对观察轮再同步结束loading。超时清除节流和余额收集器，失败快照持久化同样由提交epoch门禁保护。真实FlowHome集成七项覆盖旧URL/加载、二次校验失败、无身份错误与deadline、广电脚本/删除故障、清理停止网页超时；并非只测试独立原语。最终完整回执见TECH_LOG。
