package cn.liuliang.liuliang_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemSurfacesTest {
    @Test fun laterAccountNumbersStayDistinctInNotifications() {
        val lines = SystemSurfacePresentation.lines((2..4).map {
            WidgetCardData("notConnected", null, "流量", accountId = "mobile_$it", carrier = "mobile")
        }, 5.0, 1_790_744_400_000L)
        for (index in 2..4) assertTrue(lines[index - 2].startsWith("中国移动 $index ·"))
    }

    private val gib = 1024L * 1024L * 1024L
    private val now = 1_790_744_400_000L

    @Test fun notificationUsesOriginalCachedQueryTimeAndFailedStatusPerAccount() {
        val lines = SystemSurfacePresentation.lines(
            listOf(
                WidgetCardData("success", 8L * gib, "通用剩余", now - 25L * 60L * 60L * 1000L,
                    accountId = "mobile", carrier = "mobile", accountLabel = "13800138000"),
                WidgetCardData("authExpired", 3L * gib, "套餐明细合计", now - 3_600_000L,
                    accountId = "broadnet_2", carrier = "broadnet"),
            ),
            5.0, now,
        )
        assertEquals(2, lines.size)
        assertTrue(lines[0].startsWith("中国移动 · 8.00 GB 通用剩余 · 已过期 · 上次查询 "))
        assertTrue(lines[1].startsWith("中国广电 2 · 3.00 GB 套餐明细合计 · 待验证 · 上次查询 "))
        assertFalse(lines.joinToString().contains("13800138000"))
    }

    @Test fun unconfirmedAmountHasNoInventedBalanceOrTime() {
        val lines = SystemSurfacePresentation.lines(
            listOf(WidgetCardData("loading", 4L * gib, "通用剩余", accountId = "mobile", carrier = "mobile")),
            5.0, now,
        )
        assertEquals("中国移动 · — 通用剩余 · 查询中 · 尚无查询时间", lines.single())
    }

    @Test fun settingsKeepUserIntentDistinctFromOsDeliveryAndTilePinning() {
        val blocked = SystemSurfaceState.status(true, true, true, true, false, true)
        assertTrue(blocked.getValue("notificationEnabled"))
        assertTrue(blocked.getValue("tileEnabled"))
        assertFalse(blocked.getValue("notificationsAllowed"))
        assertTrue(blocked.getValue("tileAddSupported"))

        val denied = SystemSurfaceState.status(true, false, false, true, true, false)
        assertFalse(denied.getValue("notificationsAllowed"))
        assertFalse(denied.getValue("tileEnabled"))
    }
}
