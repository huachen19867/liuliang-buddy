# 运营商标识来源

2026-10-01，从四家官方网站公开资源取得原版标识，仅裁切图形部分、保留原色和比例并导出128px透明PNG。首页、选择页及安卓桌面卡片共用这四张图，不用汉字徽章或通用图标替代。四家名称紧邻Logo，避免长横幅缩小后文字不清。

移动：https://www.10086.cn/cmccclient/cmccclient_new/images/newlogo.png ，出处为中国移动APP官方入口。

联通：https://www.10010.com/wt_service_web/images/new_wt_logo_new.png ，出处为网上营业厅。

广电：https://www.10099.com.cn/images/login/broadnet-logo.png ，出处为官网登录/个人中心。

电信：https://www.chinatelecom.com.cn/ct/image/img/dianxin.png ，企业官网index.html第1433行导航标识资源，不是天翼账号业务标识。部分资源需通过正常官网浏览获得Cookie后下载。

原始资源保存在scripts/carrier-originals/，scripts/generate-carrier-assets.cjs记录来源与裁切区域，导出app/assets/carriers/和安卓drawable-nodpi/carrier_*.png。商标权归各运营商，仅作运营商识别，不表示本项目由运营商开发或授权；项目代码许可证不覆盖这些商标。
