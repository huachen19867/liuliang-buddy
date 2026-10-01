# Android 通知栏余额与快捷设置磁贴

2026-10-01。先复核 `TECH_LOG.md`、已有 Google AppWidget 和 WorkManager 参考，再下载 Android 官方平台说明到忽略目录 `references/system-surfaces/`。该目录 `index.json` 保留 URL、HTTP 状态与 SHA-256；不下载账号数据，不把官方网页复制进应用。Quick Settings 首次请求 TLS 失败，加 `hl=en` 的官方地址重试成功。

## 通知显示边界

这次功能是展示最近成功查询快照的普通通知。复用现有账号选择、流量单位、不限量标记、旧数据时间和脱敏规则，不为维持通知开启前台服务，不增加独立查询定时器。数据更新沿用前台查询与已存在的 WorkManager 尽力调度；打开通知开关不意味着立即获得新余额，也不意味着秒级或准点后台刷新。失败仍显示旧快照及其时间，没有快照时如实显示尚无数据。

Android 8/API 26 起按独立通知渠道管理余额通知，建议低重要性、不发声音；不能与低流量告警共用渠道，以免关闭一种提示连带关闭另一种。用户可关闭整个应用通知或单独渠道。设置回读应分别查询应用级 `areNotificationsEnabled()` 与渠道 `getImportance() == IMPORTANCE_NONE`；应用内保存的开关意图不等于系统实际允许显示，回到前台重新读取并提供系统通知设置入口。创建后的渠道重要性由系统和用户控制，重新创建同 ID 渠道不能覆盖用户的屏蔽选择。

Android 13/API 33 起普通通知需要运行时 `POST_NOTIFICATIONS` 权限。在用户主动打开功能时申请；拒绝、关闭授权弹窗或之后在系统关闭通知，都不能显示“已在通知栏展示”的成功假象。应用级与渠道级状态均需核对。

`setOngoing(true)` 表达持续通知意图，但不能保证永远无法移除。Android 14 官方说明普通 ongoing 通知可被用户单条划走；锁屏和清除全部等情况另有系统规则。余额通知不属于通话、媒体、DPC 等豁免类型。因此“常驻”只能解释为持续展示最近数据的功能，不得宣传为不可清除或持续运行保活。不得通过反复高频重发绕过用户移除。

## 快捷设置磁贴边界

`TileService` 从 API 24 可用，与当前 Android 最低版本一致。Manifest 声明并允许系统绑定服务，只使磁贴成为候选；组件启用和用户已经把磁贴加到快捷面板是两个独立状态。设置中的开关不得把“允许使用磁贴”直接标记为“已添加到系统”。`onTileAdded`、`onTileRemoved` 等是生命周期回调，保存值也不能替代所有设备上的实时系统面板状态。

API 24–32 需要用户展开快捷设置，选择编辑并手动拖入。API 33 起可在前台用户操作时调用 `StatusBarManager.requestAddTileService()`，弹出系统确认。回调有添加成功、已存在、未添加和错误；拒绝不算成功，多次拒绝后系统可能不再处理相同组件请求，因此始终保留手动添加说明。不能宣称应用可静默添加，也不能因用户取消而反复请求。

官方设计建议不把磁贴做成只有文字的只读信息块，也不把单纯打开应用当主要动作。本项目适合让磁贴点击切换通知栏余额显示，并通过状态/副标题体现缓存数据；通知授权不足时引导前台设置，不能在后台绕开授权。关闭组件会影响系统磁贴生命周期，不能据此保证重新开启时旧磁贴会自动恢复到原位置。图标、短标题和可点击动作必须在系统空间限制内可理解。

## 官方来源与复用

[Quick Settings tiles](https://developer.android.com/develop/ui/views/quicksettings-tiles?hl=en) 提供交互原则、清单声明、生命周期、手动添加和 API 33 添加确认；[TileService API](https://developer.android.com/reference/android/service/quicksettings/TileService?hl=en) 确认 API 24 起可用。官方文档指向的可复用示例是 [android/platform-samples quicksettings](https://github.com/android/platform-samples/tree/main/samples/user-interface/quicksettings)，本次以已下载官方文档和现有原生桥接实现为参考，没有复制额外库。

[通知权限](https://developer.android.com/develop/ui/views/notifications/notification-permission)、[通知渠道](https://developer.android.com/develop/ui/views/notifications/channels) 与 [Android 14 ongoing 通知变化](https://developer.android.com/about/versions/14/behavior-changes-all#non-dismissable-notifications) 分别支持权限、用户渠道控制和可清除限制。平台文档按 CC BY 4.0、其中代码示例按 Apache 2.0 的官方页脚说明使用。

已进一步下载官方 `android/platform-samples` 的 Quick Settings 模块全部 8 份源码/资源及根 LICENSE，固定提交 `0445045024fafb3e15104c4f4f7a016e2d0d71ee`，保存在 `references/system-surfaces/platform-samples/`，每文件原路径、blob SHA 与本地 SHA-256 见 `sample-index.json`。示例展示 DataStore 状态、点击切换、监听生命周期和调用 `updateTile()` 的平台方案；不把示例加入应用依赖。网络直连 EOF、匿名 API 限流后，使用已有 gh 授权只读 API 获取原始 blob，无凭证输出。

## Android Release 签名与压缩参考

Flutter 官方 Android 发布原文已下载为 `references/system-surfaces/flutter-android-release.md`，来源 `flutter/website/sites/docs/src/content/deployment/android.md`，固定 blob `451913d810c7b80d4ebae5ad4513caf8c15c9af8`，SHA-256 与官方页面地址记录在 `flutter-release-index.json`。参考重点是 `key.properties` 及密钥保持私有，release build type 配置 release signing config；不能把 APK 文件改名或 GitHub Release 标记变化当作正式构建与签名完成。既有安装包若用 debug 签名，新发布换密钥会改变 Android 升级兼容性，需据实际策略说明。

该版官方原文 R8 章节有内部矛盾：先写 `--no-shrink` 可关闭，随后 note 又写此参数无效、release 始终启用。不可仅依赖这个参数判断最终压缩行为，应检查工作区 SDK/Gradle 插件实现、构建类型与产物结果。本研究不运行 SDK，也不为发布创建或变更密钥。

上述研究核对的是官方 API 行为与文档，不能替代真机验收。尤其 Samsung/One UI 面板编辑路径、通知外观、系统拒绝回执、用户移除通知后的恢复与双卡缓存内容，仍需设备验证；不把静态构建通过等同实际系统弹窗已出现。
