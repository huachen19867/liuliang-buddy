# 温泉旅梦风格桌面卡片

2026-10-01。先读取 `docs/TECH_LOG.md` 与 `docs/WIDGET_RESEARCH.md`，复用已下载的 Google AppWidget 官方 RemoteViews/缩放样例，不引入 Glance、Compose 或额外常驻进程。用户草图的每卡横向信息结构落实为原生 `traffic_widget.xml`：左侧运营商单字徽章、备注、脱敏号码、话费、原套餐摘要与查询时间，右侧通用、定向、其他/未分类、通话四格。卡片整宽纵向排列，奶油白底、青瓷绿文字和浅绿细边；原套餐主摘要保留，避免联通套餐总余额被错误分类为其他。徽章为“移/广/联/电”，不仿制官方 Logo。

标题行预留 52×36dp `widget_mascot` ImageView，使用根代理生成的透明原创旅伴素材，只出现一次，不盖账号数字。主体每卡 100dp 加 6dp 间距；默认 280×280dp 可容纳两张卡。最小可缩放尺寸 250×180dp，按 `AppWidgetOptions.OPTION_APPWIDGET_MIN_HEIGHT` 计算一至四张完整可见卡，小时不挤成四个小格：脚注明确“另N张，请打开应用”。三张约需 386dp 高，四张约需 492dp；宿主若未返回有效高度按 280dp 处理。Launcher 大字体、宿主边距与圆角实际观感仍需真机确认。

`WidgetCardData` 与新的纯 `WidgetAccountDetails` helper 消费 Flutter 已约定的显示字段：name、phoneHint、balanceYuan、三类State及RemainingBytes、trafficEstimated、voiceState/voiceRemainingMinutes/voiceEstimated。schema 1 与既有 schema 2 主摘要兼容。旧缓存没有新字段显示未提供；明确不限量显示不限量，状态未知、没有原始查询时间或时间异常不把数值显示成官方余额。失败查询保留原查询时间与上次数据，同时保留原失败/待验证状态。

入口解析与缓存读取均重新使用严格显示白名单。备注/旧账户显示名拒绝控制字符、七位以上完整数字号码（含常见空格/横线/括号分隔）及 cookie/session/token/authorization/bearer/password/URL 样式；phoneHint 只接受一至三位前缀、四星号和四位尾号，可有开头加号。金额和分钟必须有限且在合理范围，整数余量不接受负值、小数、NaN、无穷或溢出后饱和值。缓存没有完整手机号、凭证、原始响应字段。写入原子清空旧显示缓存后只写批准字段；恢复再次过滤显示身份与分类额度。

新增 `WidgetAccountDetailsTest.kt` 覆盖完整号/凭证过滤、双次脱敏验证、零值、不限量、缺失时间、未来时间、未知状态、估算标识、溢出与小尺寸隐藏卡数、旧主摘要兼容。按协作约定未运行共享 Flutter/Dart/Gradle SDK；根代理统一原生测试和构建。XML解析、资源ID引用与 diff 空格检查由本代理执行，最终构建与真机结果并入技术日志。

最终串行验证：Flutter 144 项全部通过，flutter analyze 无问题；安卓原生 JUnit 21 项通过（账号显示与尺寸5、原组件12、调度1、系统入口3），0失败。Release 构建进行中。原生编译通过不等于各 Launcher 的添加和实际尺寸已验收。
