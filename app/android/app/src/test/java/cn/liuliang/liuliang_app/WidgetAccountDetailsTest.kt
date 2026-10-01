package cn.liuliang.liuliang_app

import org.junit.Assert.*
import org.junit.Test

class WidgetAccountDetailsTest {
    private val now = 1_790_744_400_000L
    private val gib = 1024L * 1024L * 1024L
    private fun card(extra: Map<String, Any?> = emptyMap()): WidgetCardData = WidgetInstances.fromPayload(
        listOf(mapOf("accountId" to "mobile", "carrier" to "mobile", "accountLabel" to "中国移动 1", "name" to "主卡", "status" to "success", "queriedAt" to now) + extra),
        setOf("mobile"),
    ).single()

    @Test fun maskedIdentityIsWhitelistedAndCompleteNumbersAreRejectedTwice() {
        val parsed = card(mapOf("phoneHint" to "138****5678", "cookie" to "secret", "phoneNumber" to "13812345678"))
        assertEquals("主卡", parsed.name)
        assertEquals("138****5678", parsed.phoneHint)
        assertEquals("138****5678", WidgetAccountDetails.safePhoneHint(parsed.phoneHint))
        for (raw in listOf("13812345678", "138 1234 5678", "Bearer secret", "https://login/token", "主卡\n工作")) {
            assertNull(WidgetAccountDetails.safeName(raw))
        }
        for (raw in listOf("13812345678", "138*5678", "138****5678 cookie=secret", "138****12345678")) {
            assertNull(card(mapOf("phoneHint" to raw)).phoneHint)
            assertNull(WidgetAccountDetails.safePhoneHint(raw))
        }
    }

    @Test fun detailAmountsRespectMissingTimeUnknownAndUnlimitedStates() {
        val parsed = card(mapOf("balanceYuan" to -3.25, "generalState" to "provided", "generalRemainingBytes" to 0L, "directedState" to "unlimited", "directedRemainingBytes" to gib, "voiceState" to "provided", "voiceRemainingMinutes" to 28.5))
        assertEquals("话费 -3.25 元", WidgetAccountDetails.balance(parsed, now))
        assertEquals("0 MB", WidgetAccountDetails.traffic(parsed.generalState, parsed.generalRemainingBytes, false, true))
        assertNull(parsed.directedRemainingBytes)
        assertEquals("不限量", WidgetAccountDetails.traffic(parsed.directedState, parsed.directedRemainingBytes, false, true))
        assertEquals("28.5 分钟", WidgetAccountDetails.voice(parsed, now))
        assertEquals("话费 未提供", WidgetAccountDetails.balance(parsed.copy(queriedAt = null), now))
        assertEquals("未提供", WidgetAccountDetails.voice(parsed.copy(status = "unsupported"), now))
        assertEquals("未提供", WidgetAccountDetails.traffic("provided", 0L, false, false))
        assertEquals("未提供", WidgetAccountDetails.traffic("unknown", gib, false, true))
        assertEquals("话费 未提供", WidgetAccountDetails.balance(parsed.copy(queriedAt = now + 300_001L), now))
    }

    @Test fun invalidNumericsDoNotSaturateIntoAnOfficialBalance() {
        for (value in listOf(Double.NaN, Double.POSITIVE_INFINITY, -1.0, 1.5, 1e30)) {
            assertNull(WidgetAccountDetails.safeBytes(value))
        }
        assertEquals(Long.MAX_VALUE, WidgetAccountDetails.safeBytes(Long.MAX_VALUE))
        val parsed = card(mapOf("balanceYuan" to Double.NaN, "voiceState" to "provided", "voiceRemainingMinutes" to -1, "otherState" to "provided", "otherRemainingBytes" to Double.POSITIVE_INFINITY))
        assertNull(parsed.balanceYuan)
        assertNull(parsed.voiceRemainingMinutes)
        assertNull(parsed.otherRemainingBytes)
        assertEquals("约 1.00 GB", WidgetAccountDetails.traffic("provided", gib, true, true))
    }

    @Test fun shortWidgetsExplainHiddenCardsAndTallWidgetsKeepAllFour() {
        assertEquals(0, WidgetAccountLayout.visibleCount(0, 180))
        assertEquals(1, WidgetAccountLayout.visibleCount(4, 180))
        assertEquals(2, WidgetAccountLayout.visibleCount(4, 280))
        assertEquals(3, WidgetAccountLayout.visibleCount(4, 386))
        assertEquals(4, WidgetAccountLayout.visibleCount(4, 492))
        assertEquals(1, WidgetAccountLayout.visibleCount(1, 600))
        assertEquals(2, WidgetAccountLayout.visibleCount(4, 0))
    }

    @Test fun legacySnapshotKeepsPrimarySummaryWithUnavailableNewDetails() {
        val parsed = card(mapOf("name" to null, "primaryValue" to gib, "primaryLabel" to "套餐明细合计"))
        assertEquals("1.00 GB", WidgetPresentation.present(parsed, 5.0, now).amount)
        assertNull(parsed.phoneHint)
        assertNull(parsed.balanceYuan)
        assertEquals("unavailable", parsed.generalState)
        assertEquals("未提供", WidgetAccountDetails.traffic(parsed.otherState, parsed.otherRemainingBytes, false, true))
    }
}
