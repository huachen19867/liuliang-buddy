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
        assertEquals("0 分钟", WidgetAccountDetails.voice(parsed.copy(voiceRemainingMinutes = 0.0), now))
        assertEquals("不限量", WidgetAccountDetails.voice(parsed.copy(voiceState = "unlimited", voiceRemainingMinutes = null), now))
        assertEquals("—", WidgetAccountDetails.voice(parsed.copy(voiceRemainingMinutes = null), now))
        assertEquals("", WidgetAccountDetails.balance(parsed.copy(queriedAt = null), now))
        assertEquals("—", WidgetAccountDetails.voice(parsed.copy(status = "unsupported"), now))
        assertEquals("—", WidgetAccountDetails.traffic("provided", 0L, false, false))
        assertEquals("—", WidgetAccountDetails.traffic("unknown", gib, false, true))
        assertEquals("—", WidgetAccountDetails.traffic("provided", null, false, true))
        assertEquals("", WidgetAccountDetails.balance(parsed.copy(queriedAt = now + 300_001L), now))
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

    @Test fun defaultWidgetFitsThreeAndFourCompactAccounts() {
        assertEquals(0, WidgetAccountLayout.visibleCount(0, 180))
        assertEquals(2, WidgetAccountLayout.visibleCount(4, 180))
        assertEquals(4, WidgetAccountLayout.visibleCount(4, 280))
        assertEquals(3, WidgetAccountLayout.visibleCount(3, 280))
        assertEquals(4, WidgetAccountLayout.visibleCount(4, 0))
        assertEquals(1, WidgetAccountLayout.visibleCount(1, 180))
        assertEquals(2, WidgetAccountLayout.visibleCount(2, 280))
        assertTrue(WidgetAccountLayout.isCompact(3))
        assertFalse(WidgetAccountLayout.isCompact(2))
        assertEquals(1, WidgetAccountLayout.visibleCount(4, 90))
    }

    @Test fun compactDetailKeepsStatusAndUniqueAggregateAheadOfOptionalIdentity() {
        val parsed = card(mapOf("primaryValue" to gib, "primaryLabel" to "套餐余量", "phoneHint" to "138****5678", "balanceYuan" to 0.0))
        assertEquals("套餐余量 1.00 GB", WidgetAccountLayout.compactDetail(parsed, now, false))
        assertEquals("查询失败 · 套餐余量 1.00 GB", WidgetAccountLayout.compactDetail(parsed.copy(status = "error"), now, false))
        val detailed = parsed.copy(generalState = "provided", generalRemainingBytes = gib)
        assertEquals("话费 0.00 元", WidgetAccountLayout.compactDetail(detailed, now, false))
        assertEquals("138****5678", WidgetAccountLayout.compactDetail(detailed.copy(balanceYuan = null), now, false))
        assertEquals("余量偏低", WidgetAccountLayout.compactDetail(detailed, now, true))
    }

    @Test fun legacySnapshotKeepsPrimarySummaryWithUnavailableNewDetails() {
        val parsed = card(mapOf("name" to null, "primaryValue" to gib, "primaryLabel" to "套餐明细合计"))
        assertEquals("1.00 GB", WidgetPresentation.present(parsed, 5.0, now).amount)
        assertNull(parsed.phoneHint)
        assertNull(parsed.balanceYuan)
        assertEquals("unavailable", parsed.generalState)
        assertEquals("—", WidgetAccountDetails.traffic(parsed.otherState, parsed.otherRemainingBytes, false, true))
        assertEquals("套餐明细合计 1.00 GB", WidgetAccountDetails.primarySummary(parsed, now))
    }

    @Test fun missingBalanceIsOmittedWhileOfficialZeroAndNegativeBalancesRemain() {
        assertEquals("", WidgetAccountDetails.balance(card(), now))
        assertEquals("", WidgetAccountDetails.balance(card(mapOf("balanceYuan" to Double.NaN)), now))
        assertEquals("话费 0.00 元", WidgetAccountDetails.balance(card(mapOf("balanceYuan" to 0.0)), now))
        assertEquals("话费 -3.25 元", WidgetAccountDetails.balance(card(mapOf("balanceYuan" to -3.25)), now))
        val cached = card(mapOf("balanceYuan" to 12.5, "queriedAt" to now - 25L * 60L * 60L * 1000L))
        assertEquals("话费 12.50 元", WidgetAccountDetails.balance(cached.copy(status = "error"), now))
        assertEquals("", WidgetAccountDetails.balance(cached.copy(status = "notConnected"), now))
    }

    @Test fun normalSuccessOmitsSecondaryStatusWhileActionableStatesRemainVisible() {
        val parsed = card(mapOf("primaryValue" to gib, "primaryLabel" to "通用剩余"))
        assertNull(WidgetAccountDetails.secondaryStatus(parsed, now))
        assertNull(WidgetAccountDetails.secondaryStatus(parsed.copy(queriedAt = now - 24L * 60L * 60L * 1000L), now))
        assertEquals("记录较早", WidgetAccountDetails.secondaryStatus(parsed.copy(queriedAt = now - 24L * 60L * 60L * 1000L - 1), now))
        assertEquals("待确认", WidgetAccountDetails.secondaryStatus(parsed.copy(queriedAt = null), now))
        assertEquals("查询失败", WidgetAccountDetails.secondaryStatus(parsed.copy(status = "error"), now))
        assertEquals("登录已过期", WidgetAccountDetails.secondaryStatus(parsed.copy(status = "authExpired"), now))
        assertEquals("查询中", WidgetAccountDetails.secondaryStatus(parsed.copy(status = "loading"), now))
        assertEquals("未连接", WidgetAccountDetails.secondaryStatus(parsed.copy(status = "notConnected", queriedAt = null), now))
    }

    @Test fun confirmedTrafficCategoriesSuppressDuplicatePrimarySummary() {
        val parsed = card(mapOf("primaryValue" to gib, "primaryLabel" to "套餐明细合计"))
        for (category in listOf("general", "directed", "other")) {
            val provided = card(mapOf("primaryValue" to gib, "primaryLabel" to "套餐明细合计", "${category}State" to "provided", "${category}RemainingBytes" to 0L))
            val unlimited = card(mapOf("primaryValue" to gib, "primaryLabel" to "套餐明细合计", "${category}State" to "unlimited"))
            assertNull("$category provided", WidgetAccountDetails.primarySummary(provided, now))
            assertNull("$category unlimited", WidgetAccountDetails.primarySummary(unlimited, now))
        }
        assertNull(WidgetAccountDetails.primarySummary(parsed.copy(generalState = "provided", generalRemainingBytes = gib), now))
    }

    @Test fun absentPrimaryAmountAndInvalidQueryDoNotCreatePlaceholderSummary() {
        assertNull(WidgetAccountDetails.primarySummary(card(), now))
        assertNull(WidgetAccountDetails.primarySummary(card(mapOf("primaryValue" to -1L)), now))
        val parsed = card(mapOf("primaryValue" to gib, "primaryLabel" to "套餐明细合计"))
        assertNull(WidgetAccountDetails.primarySummary(parsed.copy(queriedAt = null), now))
        assertNull(WidgetAccountDetails.primarySummary(parsed.copy(queriedAt = 0L), now))
        assertNull(WidgetAccountDetails.primarySummary(parsed.copy(queriedAt = now + 300_001L), now))
        assertNull(WidgetAccountDetails.primarySummary(parsed.copy(status = "notConnected"), now))
        assertNull(WidgetAccountDetails.primarySummary(parsed.copy(status = "unsupported"), now))
    }

    @Test fun legacyUnicomAggregateAndCachedAmountsRemainWithoutInventedCategories() {
        val parsed = WidgetInstances.fromPayload(
            listOf(mapOf("accountId" to "unicom", "carrier" to "unicom", "status" to "success", "queriedAt" to now, "primaryValue" to 3L * gib, "primaryLabel" to "套餐余量")),
            setOf("unicom"),
        ).single()
        assertEquals("套餐余量 3.00 GB", WidgetAccountDetails.primarySummary(parsed, now))
        assertEquals("unavailable", parsed.generalState)
        assertEquals("unavailable", parsed.directedState)
        assertEquals("unavailable", parsed.otherState)
        for (status in listOf("loading", "error", "authExpired")) {
            val cached = parsed.copy(status = status, queriedAt = now - 25L * 60L * 60L * 1000L)
            assertEquals("套餐余量 3.00 GB", WidgetAccountDetails.primarySummary(cached, now))
            assertEquals(now - 25L * 60L * 60L * 1000L, cached.queriedAt)
        }
        assertEquals("套餐余量 0 MB", WidgetAccountDetails.primarySummary(parsed.copy(remainingBytes = 0L), now))
        assertEquals("含不限量套餐 不限量", WidgetAccountDetails.primarySummary(parsed.copy(remainingBytes = null, label = "含不限量套餐", unlimited = true), now))
        assertEquals("套餐估算余量 约 3.00 GB", WidgetAccountDetails.primarySummary(parsed.copy(label = "套餐估算余量"), now))
        val invalidCategory = parsed.copy(generalState = "provided", generalRemainingBytes = null)
        assertEquals("套餐余量 3.00 GB", WidgetAccountDetails.primarySummary(invalidCategory, now))
    }
}
