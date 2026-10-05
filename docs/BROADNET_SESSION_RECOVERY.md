# 广电会话备份与恢复约定

本次复用已下载的 `references/broadnet-public/6-common-85ed7.js`、`7-index-eba9b.js` 与 `unauthenticated-qryUserRes.json`，未下载重复参考或复制官网加密代码。官网把手机号信息和会话编号分别加密后放入 `broadnetUserPhoneInfo`、`broadnetUserSessionId`；APP 只原样保存这两个不透明字符串，让官网按自己的协议查询。

`app/lib/services/broadnet_session.dart` 的 `normalizeBroadnetSession` 是前台、后台与网页恢复可复用的校验入口：只接受两个非空字符串，每个不超过 20000 字符，不修改密文。`savedAt` 记录本地捕获时间，没有官网证据证明它等于服务端过期时间；因此缺失、很旧、无效或未来时间戳均不能单独作为删除真实凭证的理由。下一次官方响应负责确认能否继续使用，HTTP 200 内的业务状态 701 仍表示登录过期。移除本地年龄门禁不等于续期服务端会话，也不保证凭证长期有效。

`captureBroadnetSession` 保存当前完整的两个字段和传入的本地捕获时间；调用方不能只按 `sessionId` 相同跳过，因为官网可能更新 `phoneInfo`。调用方仅在真实官网套餐查询成功后保存完整字段对，变化的phoneInfo同样保存；普通页面加载、刷新前或关闭网页都不写备份，防游客资料覆盖原登录。捕获仅说明网页存在这对字符串；查询成功才证明本轮读取可用，不能仅凭捕获更新余额的查询时间或制造查询成功状态。

网页恢复只在广电 HTTPS 官网主框架且非登录页执行，现有完整字段优先，不用备份覆盖新登录。官网未登录分支会生成一个游客 `sessionId`，忘记密码入口也可能只留下 `phoneInfo`；只有一个字段时可整对恢复备份，两个字段一起取自同一份保存值。不存在可复用备份、存储不可用或官网真正判失效时，仍需要官方登录。APP 不生成会话编号、重写密文或绕过官网验证。

新增 `app/test/services/broadnet_session_test.dart` 覆盖旧时间戳、缺失字段、长度限制、密文原样保存与同编号字段更新，留给根任务统一运行 Flutter。`app/test/services/broadnet_session_js_test.cjs` 已用 Node 执行实际网页脚本模板，检查空/半会话恢复、新完整登录保护、域名/主框架/登录页门禁与存储异常；这是合成回归，没有真实广电账号长期恢复验证。

根接线：前台仅官方套餐查询成功后才捕获和保存；同时替换broadnetRestore document-start脚本，防下次空会话仍恢复旧资料。后台不依赖onLoadStop晚事件，成功响应处理内捕获并随result返回；前台新pair supersede后台旧result，保存前再检查当前凭证与isTaskCurrent。原生APP可见自动停止后台，非原子读写小窗口不宣称全消除。读取JS限时2秒，备份保存失败保留原资料。

用户补充广电约3日且官网本身重新要求验证码，因此不是7日本地年龄门禁导致的这次真实到期。未找到官网refresh登录接口，客服getToken与此无关。本次不承诺延长三日服务端寿命；真实过期仍需短信验证。移动官网归档能确认checkCtrol控制3天勾选，但不是永久续期开关。
