package cn.liuliang.liuliang_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.TimeZone

class WidgetPresentationTest {
    private val gib = 1024L * 1024L * 1024L
    private val now = 1_790_744_400_000L

    @Test fun cachedFailureKeepsLastQueryTimeAndFailureState() {
        val oldTime = now - 2L * 60L * 60L * 1000L
        val display = WidgetPresentation.present(
            WidgetCardData("error", 3L * gib, "通用剩余", oldTime),
            5.0, now,
        )
        assertEquals("3.00 GB", display.amount)
        assertEquals("查询失败", display.state)
        assertTrue(display.time.startsWith("上次查询 "))
        assertTrue(display.low)
    }

    @Test fun staleSuccessIsMarkedExpiredAndNeverLooksFresh() {
        val display = WidgetPresentation.present(
            WidgetCardData("success", 8L * gib, "通用剩余", now - 25L * 60L * 60L * 1000L),
            5.0, now,
        )
        assertEquals("已过期", display.state)
        assertTrue(display.stale)
        assertFalse(display.low)
        assertTrue(display.time.startsWith("上次查询 "))
    }

    @Test fun unknownOrMissingValuesAreNotRenderedAsZero() {
        val unknown = WidgetPresentation.present(
            WidgetCardData("unsupported", 0L, "任意用途", now),
            5.0, now,
        )
        assertEquals("—", unknown.amount)
        assertEquals("未连接", unknown.state)
        assertEquals("套餐余量·用途待确认", unknown.label)

        val missing = WidgetPresentation.present(WidgetCardData("success"), 5.0, now)
        assertEquals("—", missing.amount)
        assertEquals("待确认", missing.state)
        assertEquals("尚无查询时间", missing.time)
        assertEquals("0 MB", WidgetPresentation.formatBytes(0L))

        val untimed = WidgetPresentation.present(WidgetCardData("success", gib), 5.0, now)
        assertEquals("—", untimed.amount)
        assertEquals("待确认", untimed.state)
    }

    @Test fun unknownPurposeIsNotTreatedAsGeneralLowTraffic() {
        val display = WidgetPresentation.present(
            WidgetCardData("success", gib, "套餐余量·用途待确认", now),
            5.0, now,
        )
        assertEquals("1.00 GB", display.amount)
        assertEquals("上次记录", display.state)
        assertFalse(display.low)
    }

    @Test fun queryEpochIsRenderedInDeviceLocalTimeWithDateAndClock() {
        val previousZone = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"))
            val display = WidgetPresentation.present(
                WidgetCardData("success", gib, "通用剩余", 1_790_744_400_000L),
                5.0, 1_790_744_400_000L,
            )
            assertTrue(display.time.matches(Regex("上次查询 \\d{2}/\\d{2} \\d{2}:\\d{2}")))
            assertEquals("余量偏低", display.state)
        } finally {
            TimeZone.setDefault(previousZone)
        }
    }
}
