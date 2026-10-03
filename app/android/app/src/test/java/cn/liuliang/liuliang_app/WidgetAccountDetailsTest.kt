package cn.liuliang.liuliang_app

import org.junit.Assert.*
import org.junit.Test

class WidgetAccountDetailsTest {
    @Test fun telecomOtherPartialSumSurvivesNativeAttachAndCompactDisplay() {
        val parsed = partial(mapOf("otherState" to "partial", "otherRemainingBytes" to 10 * gib, "otherPendingCount" to 1))
        assertEquals("partial", parsed.otherState)
        assertEquals(10 * gib, parsed.otherRemainingBytes)
        assertEquals("已读约 10.00 GB", WidgetAccountDetails.traffic(parsed.otherState, parsed.otherRemainingBytes, true, true))
        assertEquals("其他已读约 10.00 GB · 1项待确认", WidgetAccountLayout.compactDetail(parsed, now, false))
        assertFalse(WidgetAccountDetails.usePartialPanel(parsed, now))
        assertEquals("—", WidgetAccountDetails.traffic(parsed.otherState, parsed.otherRemainingBytes, true, false))
    }

    @Test fun otherPartialDoesNotOpenOtherCarriersOrInvalidAmounts() {
        for (extra in listOf(
            mapOf("otherRemainingBytes" to -1L), mapOf("otherRemainingBytes" to Double.NaN),
            mapOf("otherPendingCount" to 0), mapOf("otherPendingCount" to 201))) {
            val parsed = partial(mapOf("otherState" to "partial", "otherRemainingBytes" to gib, "otherPendingCount" to 1) + extra)
            assertEquals("unavailable", parsed.otherState)
            assertNull(parsed.otherRemainingBytes)
        }
        val mobile = WidgetAccountDetails.attach(WidgetCardData(carrier = "mobile", status = "success", remainingBytes = null, queriedAt = now),
            mapOf("otherState" to "partial", "otherRemainingBytes" to gib, "otherPendingCount" to 1,
                "generalState" to "partial", "generalRemainingBytes" to gib))
        assertEquals("unavailable", mobile.otherState)
        assertEquals("unavailable", mobile.generalState)
        val zero = partial(mapOf("otherState" to "partial", "otherRemainingBytes" to 0L, "otherPendingCount" to 1))
        assertEquals("已读约 0 MB", WidgetAccountDetails.traffic(zero.otherState, zero.otherRemainingBytes, true, true))
    }
    private val now = 1_790_744_400_000L
    private val gib = 1024L * 1024L * 1024L
    private fun partial(extra: Map<String, Any?> = emptyMap()): WidgetCardData = WidgetInstances.fromPayload(
        listOf(mapOf("accountId" to "telecom", "carrier" to "telecom", "accountLabel" to "中国电信 1", "status" to "success", "queriedAt" to now,
            "trafficReadableCount" to 9, "trafficPendingCount" to 1, "previewRemainingBytes" to gib) + extra), setOf("telecom"),
    ).single()

    @Test fun partialPreviewIsSingleItemNotTotalAndNeverLow() {
        val card = partial(mapOf("generalState" to "provided", "generalRemainingBytes" to gib))
        assertNull(card.remainingBytes)
        assertEquals("单项约 1.00 GB", WidgetAccountDetails.primarySummary(card, now))
        val display = WidgetPresentation.present(card, 100.0, now)
        assertEquals("约 1.00 GB", display.amount)
        assertEquals("单项套餐余量", display.label)
        assertEquals("9项可读 · 1项待确认", display.state)
        assertFalse(display.low)
        assertFalse(WidgetAccountDetails.usePartialPanel(card, now))
        assertTrue(WidgetAccountDetails.usePartialPanel(partial(), now))
        assertEquals("单项约 1.00 GB\n1项待确认", WidgetAccountDetails.partialPanel(partial()))
        assertEquals("单项约 1.00 GB · 1项待确认", WidgetAccountLayout.compactDetail(card, now, false))
        assertTrue(SystemSurfacePresentation.lines(listOf(card), 100.0, now).single().contains("单项套餐余量"))
    }

    @Test fun partialZeroUnlimitedAndCachedFailureKeepMeaning() {
        assertEquals("单项约 0 MB", WidgetAccountDetails.primarySummary(partial(mapOf("previewRemainingBytes" to 0L)), now))
        val unlimited = partial(mapOf("previewRemainingBytes" to null, "previewUnlimited" to true, "isUnlimited" to true))
        assertEquals("单项不限量", WidgetAccountDetails.primarySummary(unlimited, now))
        for (status in listOf("loading", "authExpired", "error")) {
            val cached = partial(mapOf("status" to status, "queriedAt" to now - 90_000L))
            assertEquals("单项约 1.00 GB", WidgetAccountDetails.primarySummary(cached, now))
            assertEquals(now - 90_000L, cached.queriedAt)
            assertFalse(WidgetPresentation.present(cached, 100.0, now).low)
        }
        assertFalse(WidgetAccountDetails.hasPartialPreview(partial(mapOf("status" to "notConnected")), now))
        assertFalse(WidgetAccountDetails.hasPartialPreview(partial(mapOf("queriedAt" to now + 600_000L)), now))
    }

    @Test fun partialMalformedCountsAndCanonicalAmountSuppressPreview() {
        for (value in listOf(-1, 201, 1.5, Double.NaN, "9")) {
            assertFalse(WidgetAccountDetails.hasPartialPreview(partial(mapOf("trafficReadableCount" to value)), now))
        }
        assertFalse(WidgetAccountDetails.hasPartialPreview(partial(mapOf("trafficReadableCount" to 200, "trafficPendingCount" to 1)), now))
        assertFalse(WidgetAccountDetails.hasPartialPreview(partial(mapOf("previewUnlimited" to true)), now))
        assertFalse(WidgetAccountDetails.hasPartialPreview(partial(mapOf("primaryValue" to 3L * gib)), now))
    }
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
        assertEquals("138****5678", WidgetAccountLayout.compactDetail(detailed, now, false))
        assertEquals("138****5678", WidgetAccountLayout.compactDetail(detailed.copy(balanceYuan = null), now, false))
        assertEquals("余量偏低", WidgetAccountLayout.compactDetail(detailed, now, true))
    }

    @Test fun compactThreeAndFourAccountRowsKeepBalanceSeparateFromTrafficAndStatus() {
        val parsed = card(mapOf(
            "primaryValue" to gib,
            "primaryLabel" to "套餐余量",
            "balanceYuan" to 26.5,
        ))
        assertTrue(WidgetAccountLayout.isCompact(3))
        assertTrue(WidgetAccountLayout.isCompact(4))
        assertEquals("套餐余量 1.00 GB", WidgetAccountLayout.compactDetail(parsed, now, false))
        assertTrue(WidgetAccountDetails.compactBalance(parsed, now).startsWith("¥26.50 · "))

        val failed = parsed.copy(status = "error")
        assertEquals("查询失败 · 套餐余量 1.00 GB", WidgetAccountLayout.compactDetail(failed, now, false))
        assertTrue(WidgetAccountDetails.compactBalance(failed, now).startsWith("¥26.50 · "))
        assertTrue(WidgetAccountDetails.compactBalance(parsed.copy(balanceYuan = 0.0), now).startsWith("¥0.00 · "))
        assertTrue(WidgetAccountDetails.compactBalance(parsed.copy(balanceYuan = -3.25), now).startsWith("¥-3.25 · "))
        assertEquals("", WidgetAccountDetails.compactBalance(parsed.copy(balanceYuan = null), now))
        assertEquals("", WidgetAccountDetails.compactBalance(parsed.copy(queriedAt = null), now))
        assertEquals("", WidgetAccountDetails.compactBalance(parsed.copy(status = "notConnected"), now))
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
