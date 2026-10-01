# 1.7.0 通话与短信余量

首页每个账号新增通话与短信面板，复用官方查询页已返回的套餐数据，无需新增短信、通话记录权限。保留官网套餐名称和范围，各项独立展示，不合并共享或重叠额度；未知、零、超额与官网明确不限量分别处理，失败时保留旧结果及原查询时间。

联通保留“短、彩信”合并口径，广电只把有明确短信名称的业务识别为短信。移动字段参考公开 MIT 实现，尚需真实套餐核对。电信通话按官网分钟显示值估算，短信按同单位显示值差估算，官网“次”不硬转“条”；无法确认时显示暂无法获取。协议证据见 [研究记录](VOICE_SMS_RESEARCH.md)。桌面组件本轮仍展示流量。

iOS 沿用公开源码和云端模拟器验证，不提供签名 iPhone IPA；真实四家账号与设备尚需复测。


本地完整Flutter123项、静态分析、Node响应探针与Chrome电信10项本地合成场景通过。实际Flutter组件DEMO截图见 [首页预览](../artifacts/dashboard-voice-sms-demo.png)，无真实号码。

安卓1.7.0/code10为91,439,548字节，SHA-256为9b191abbab3c41abed7c9c188361440289581abcb4dc916bfe33504953a78549。沿用Android Debug证书，apksigner v2通过，API24/36，Flutter引擎仅ARM64；无短信/通话读取权限，未启用DEMO。真实手机、套餐余额和原生桌面行为待复测，未重复宣称历史原生JUnit为本轮新验收。

[iOS云端验收](https://github.com/huachen19867/liuliang-buddy/actions/runs/36826003180)已通过：123项Flutter、analyze、Swift模型检查、未签名Runner/WidgetKit编译、独立冷启动及选择/首页/小组件指引/设置流程。验证源码e697ecb0dc7f9c0c2780e9d223f993b096c482af，其后只补文档；没有真实账号、系统Widget或签名iPhone安装验收。
