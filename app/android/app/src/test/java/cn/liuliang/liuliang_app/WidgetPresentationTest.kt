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

    @Test fun packageDetailSumIsLabelledAndDoesNotTriggerGeneralLowTraffic() {
        val display = WidgetPresentation.present(
            WidgetCardData("success", gib, "套餐明细合计", now),
            5.0, now,
        )
        assertEquals("1.00 GB", display.amount)
        assertEquals("套餐明细合计", display.label)
        assertEquals("上次记录", display.state)
        assertFalse(display.low)
    }

    @Test fun telecomEstimateKeepsApproximationAndOriginalTimeWithoutLowWarning() {
        val originalTime = now - 25L * 60L * 60L * 1000L
        val display = WidgetPresentation.present(
            WidgetCardData("success", gib, "套餐估算余量", originalTime),
            5.0, now,
        )
        assertEquals("约 1.00 GB", display.amount)
        assertEquals("套餐估算余量", display.label)
        assertEquals("已过期", display.state)
        assertTrue(display.time.startsWith("上次查询 "))
        assertTrue(display.stale)
        assertFalse(display.low)
    }

    @Test fun carrierWhitelistSupportsLegacySingleAndEmptyLayouts() {
        assertEquals(
            setOf("mobile", "broadnet"),
            WidgetCarrierSelection.fromPayload(null, false),
        )
        assertEquals(
            setOf("broadnet"),
            WidgetCarrierSelection.fromPayload(listOf("broadnet", "broadnet", "future"), true),
        )
        assertEquals(emptySet<String>(), WidgetCarrierSelection.fromPayload(emptyList<String>(), true))
        assertEquals(emptySet<String>(), WidgetCarrierSelection.fromPayload("mobile", true))
        assertEquals(
            setOf("mobile", "broadnet", "unicom", "telecom"),
            WidgetCarrierSelection.fromPayload(listOf("telecom", "unicom", "broadnet", "mobile"), true),
        )
        assertEquals(
            listOf("broadnet", "telecom"),
            WidgetCarrierSelection.displayOrder(setOf("telecom", "broadnet")),
        )
    }

    @Test fun allCarrierCombinationsOccupyConsecutiveSlots() {
        val carriers = WidgetCarrierSelection.order
        for (mask in 1 until (1 shl carriers.size)) {
            val selected = carriers.filterIndexed { index, _ -> mask and (1 shl index) != 0 }.toSet()
            val displayed = WidgetCarrierSelection.displayOrder(selected)
            assertEquals(selected.size, displayed.size)
            assertEquals(selected, displayed.toSet())
            assertEquals(carriers.filter { it in selected }, displayed)
        }
    }
}
