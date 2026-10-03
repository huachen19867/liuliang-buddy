package cn.liuliang.liuliang_app

import java.util.Locale

/** Display-only whitelist used both when receiving and restoring native cache. */
object WidgetAccountDetails {
    private val states = setOf("provided", "unlimited", "unavailable")
    private val labels = setOf("通用剩余", "套餐余量", "含不限量套餐", "套餐明细合计", "套餐估算余量", "余额待确认", "套餐余量·用途待确认")

    fun safeName(raw: Any?): String? = (raw as? String)?.trim()?.takeIf {
        it.isNotEmpty() && it.length <= 40 &&
            !Regex("[\\p{Cntrl}]").containsMatchIn(it) &&
            !Regex("[\\p{Nd}][\\p{Nd}\\s+().-]{5,}[\\p{Nd}]").findAll(it).any { match -> match.value.count(Char::isDigit) >= 7 } &&
            !Regex("cookie|session|token|authorization|bearer|password|https?://", RegexOption.IGNORE_CASE).containsMatchIn(it)
    }

    fun safePhoneHint(raw: Any?): String? = (raw as? String)?.takeIf {
        it.matches(Regex("\\+?[0-9]{1,3}\\*{4}[0-9]{4}"))
    }

    fun safeLabel(raw: Any?): String = (raw as? String)?.takeIf { it in labels } ?: "余额待确认"

    fun safeBytes(raw: Any?): Long? {
        if (raw is Long) return raw.takeIf { it >= 0L }
        if (raw is Int) return raw.toLong().takeIf { it >= 0L }
        val value = (raw as? Number)?.toDouble() ?: return null
        return if (value.isFinite() && value >= 0.0 && value < Long.MAX_VALUE.toDouble() && value % 1.0 == 0.0) value.toLong() else null
    }

    private fun safeDecimal(raw: Any?, signed: Boolean): Double? = (raw as? Number)?.toDouble()?.takeIf {
        it.isFinite() && kotlin.math.abs(it) <= 1_000_000_000.0 && (signed || it >= 0.0)
    }

    private fun state(raw: Any?): String = (raw as? String)?.takeIf { it in states } ?: "unavailable"

    private fun otherState(card: WidgetCardData, raw: Map<*, *>): String =
        if (raw["otherState"] == "partial" && card.carrier == "telecom" &&
            safeCount(raw["otherPendingCount"]) in 1..200 && safeBytes(raw["otherRemainingBytes"]) != null) "partial"
        else state(raw["otherState"])

    fun attach(card: WidgetCardData, raw: Map<*, *>): WidgetCardData = card.copy(
        name = safeName(raw["name"]),
        phoneHint = safePhoneHint(raw["phoneHint"]),
        balanceYuan = safeDecimal(raw["balanceYuan"], true),
        generalState = state(raw["generalState"]),
        generalRemainingBytes = if (state(raw["generalState"]) == "provided") safeBytes(raw["generalRemainingBytes"]) else null,
        directedState = state(raw["directedState"]),
        directedRemainingBytes = if (state(raw["directedState"]) == "provided") safeBytes(raw["directedRemainingBytes"]) else null,
        otherState = otherState(card, raw),
        otherRemainingBytes = if (otherState(card, raw) in setOf("provided", "partial")) safeBytes(raw["otherRemainingBytes"]) else null,
        otherPendingCount = if (otherState(card, raw) == "partial") safeCount(raw["otherPendingCount"]) else 0,
        trafficEstimated = raw["trafficEstimated"] == true,
        voiceState = state(raw["voiceState"]),
        voiceRemainingMinutes = if (state(raw["voiceState"]) == "provided") safeDecimal(raw["voiceRemainingMinutes"], false) else null,
        voiceEstimated = raw["voiceEstimated"] == true,
        trafficReadableCount = safeCount(raw["trafficReadableCount"]),
        trafficPendingCount = safeCount(raw["trafficPendingCount"]),
        previewRemainingBytes = safeBytes(raw["previewRemainingBytes"]),
        previewUnlimited = raw["previewUnlimited"] == true,
    )

    private fun safeCount(raw: Any?): Int = safeBytes(raw)?.takeIf { it <= 200L }?.toInt() ?: 0

    fun hasPartialPreview(card: WidgetCardData, now: Long): Boolean =
        card.carrier == "telecom" && validQuery(card, now) && card.remainingBytes == null &&
            card.trafficReadableCount in 1..200 && card.trafficPendingCount in 1..200 &&
            card.trafficReadableCount + card.trafficPendingCount <= 200 &&
            ((card.previewRemainingBytes?.let { it >= 0L } == true) != card.previewUnlimited)

    fun previewAmount(card: WidgetCardData): String = if (card.previewUnlimited) "不限量"
        else "约 ${WidgetPresentation.formatBytes(card.previewRemainingBytes!!)}"

    fun usePartialPanel(card: WidgetCardData, now: Long): Boolean = hasPartialPreview(card, now) &&
        listOf(card.generalState, card.directedState, card.otherState, card.voiceState).all { it == "unavailable" }

    fun partialPanel(card: WidgetCardData): String = "单项${previewAmount(card)}\n${card.trafficPendingCount}项待确认"

    fun validQuery(card: WidgetCardData, now: Long): Boolean =
        card.status in setOf("success", "loading", "authExpired", "error") &&
            card.queriedAt?.let { it > 0L && it <= now + 300_000L } == true

    fun balance(card: WidgetCardData, now: Long): String = if (validQuery(card, now) && card.balanceYuan?.isFinite() == true) {
        String.format(Locale.CHINA, "话费 %.2f 元", card.balanceYuan)
    } else ""

    /** Compact rows keep the amount first, with its original query time trailing. */
    fun compactBalance(card: WidgetCardData, now: Long): String {
        if (!validQuery(card, now) || card.balanceYuan?.isFinite() != true) return ""
        val amount = String.format(Locale.CHINA, "¥%.2f", card.balanceYuan)
        val time = WidgetPresentation.present(card, 0.0, now).time.removePrefix("上次查询 ")
        return if (time.isBlank() || time == "尚无查询时间") amount else "$amount · $time"
    }

    fun secondaryStatus(card: WidgetCardData, now: Long): String? = when (card.status) {
        "loading" -> "查询中"
        "authExpired" -> "登录已过期"
        "error" -> "查询失败"
        "success" -> when {
            !validQuery(card, now) -> "待确认"
            now - card.queriedAt!! > 24L * 60L * 60L * 1000L -> "记录较早"
            hasPartialPreview(card, now) -> "${card.trafficReadableCount}项可读 · ${card.trafficPendingCount}项待确认"
            else -> null
        }
        else -> "未连接"
    }

    fun primarySummary(card: WidgetCardData, now: Long): String? {
        if (!validQuery(card, now)) return null
        if (card.otherState == "partial" && card.otherRemainingBytes != null) {
            return "其他已读约 ${WidgetPresentation.formatBytes(card.otherRemainingBytes)} · ${card.otherPendingCount}项待确认"
        }
        if (hasPartialPreview(card, now)) return "单项${previewAmount(card)}"
        val hasCategory = listOf(
            card.generalState to card.generalRemainingBytes,
            card.directedState to card.directedRemainingBytes,
            card.otherState to card.otherRemainingBytes,
        ).any { (state, bytes) -> state == "unlimited" || (state in setOf("provided", "partial") && bytes != null && bytes >= 0L) }
        if (hasCategory) return null
        val display = WidgetPresentation.present(card, 0.0, now)
        return if (display.amount != "—") "${display.label} ${display.amount}" else null
    }

    fun traffic(state: String, bytes: Long?, estimated: Boolean, validQuery: Boolean): String = when {
        !validQuery -> "—"
        state == "unlimited" -> "不限量"
        state == "partial" && bytes != null && bytes >= 0L -> "已读约 " + WidgetPresentation.formatBytes(bytes)
        state == "provided" && bytes != null && bytes >= 0L -> (if (estimated) "约 " else "") + WidgetPresentation.formatBytes(bytes)
        else -> "—"
    }

    fun voice(card: WidgetCardData, now: Long): String = when {
        !validQuery(card, now) -> "—"
        card.voiceState == "unlimited" -> "不限量"
        card.voiceState == "provided" && card.voiceRemainingMinutes != null -> {
            val value = card.voiceRemainingMinutes
            val amount = if (value % 1.0 == 0.0) String.format(Locale.CHINA, "%.0f", value) else String.format(Locale.CHINA, "%.1f", value)
            (if (card.voiceEstimated) "约 " else "") + amount + " 分钟"
        }
        else -> "—"
    }
}

/** Three/four accounts use compact rows; a short host explains omitted accounts. */
object WidgetAccountLayout {
    const val CARD_HEIGHT_DP = 100
    const val COMPACT_CARD_HEIGHT_DP = 50
    fun isCompact(total: Int): Boolean = total >= 3

    fun visibleCount(total: Int, minHeightDp: Int): Int {
        if (total <= 0) return 0
        val height = minHeightDp.takeIf { it > 0 } ?: 280
        val stride = if (isCompact(total)) COMPACT_CARD_HEIGHT_DP + 4 else CARD_HEIGHT_DP + 6
        // 52dp shell/header; reserve the 16dp omission footer only when needed.
        val allFit = 52 + stride * total.coerceAtMost(4) <= height
        val available = height - 52 - if (allFit) 0 else 16
        return (available / stride).coerceIn(1, 4).coerceAtMost(total)
    }

    fun compactDetail(card: WidgetCardData, now: Long, low: Boolean): String? {
        if (card.otherState == "partial" && WidgetAccountDetails.validQuery(card, now)) {
            val summary = WidgetAccountDetails.primarySummary(card, now)
            val status = if (card.status == "success" && now - card.queriedAt!! <= 24L * 60L * 60L * 1000L) null
                else WidgetAccountDetails.secondaryStatus(card, now)
            return listOfNotNull(status, summary).joinToString(" · ")
        }
        if (WidgetAccountDetails.hasPartialPreview(card, now)) {
            val status = if (card.status == "success" && now - card.queriedAt!! <= 24L * 60L * 60L * 1000L) "${card.trafficPendingCount}项待确认"
                else WidgetAccountDetails.secondaryStatus(card, now)
            return "单项${WidgetAccountDetails.previewAmount(card)} · $status"
        }
        val status = WidgetAccountDetails.secondaryStatus(card, now) ?: if (low) "余量偏低" else null
        val summary = WidgetAccountDetails.primarySummary(card, now)
        if (summary != null) return listOfNotNull(status, summary).joinToString(" · ")
        return status ?: WidgetAccountDetails.safePhoneHint(card.phoneHint)
    }
}
