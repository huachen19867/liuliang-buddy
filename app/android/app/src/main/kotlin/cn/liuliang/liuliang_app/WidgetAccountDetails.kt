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

    fun attach(card: WidgetCardData, raw: Map<*, *>): WidgetCardData = card.copy(
        name = safeName(raw["name"]),
        phoneHint = safePhoneHint(raw["phoneHint"]),
        balanceYuan = safeDecimal(raw["balanceYuan"], true),
        generalState = state(raw["generalState"]),
        generalRemainingBytes = if (state(raw["generalState"]) == "provided") safeBytes(raw["generalRemainingBytes"]) else null,
        directedState = state(raw["directedState"]),
        directedRemainingBytes = if (state(raw["directedState"]) == "provided") safeBytes(raw["directedRemainingBytes"]) else null,
        otherState = state(raw["otherState"]),
        otherRemainingBytes = if (state(raw["otherState"]) == "provided") safeBytes(raw["otherRemainingBytes"]) else null,
        trafficEstimated = raw["trafficEstimated"] == true,
        voiceState = state(raw["voiceState"]),
        voiceRemainingMinutes = if (state(raw["voiceState"]) == "provided") safeDecimal(raw["voiceRemainingMinutes"], false) else null,
        voiceEstimated = raw["voiceEstimated"] == true,
    )

    fun validQuery(card: WidgetCardData, now: Long): Boolean =
        card.status in setOf("success", "loading", "authExpired", "error") &&
            card.queriedAt?.let { it > 0L && it <= now + 300_000L } == true

    fun balance(card: WidgetCardData, now: Long): String = if (validQuery(card, now) && card.balanceYuan?.isFinite() == true) {
        String.format(Locale.CHINA, "话费 %.2f 元", card.balanceYuan)
    } else "话费 未提供"

    fun traffic(state: String, bytes: Long?, estimated: Boolean, validQuery: Boolean): String = when {
        !validQuery -> "未提供"
        state == "unlimited" -> "不限量"
        state == "provided" && bytes != null && bytes >= 0L -> (if (estimated) "约 " else "") + WidgetPresentation.formatBytes(bytes)
        else -> "未提供"
    }

    fun voice(card: WidgetCardData, now: Long): String = when {
        !validQuery(card, now) -> "未提供"
        card.voiceState == "unlimited" -> "不限量"
        card.voiceState == "provided" && card.voiceRemainingMinutes != null -> {
            val value = card.voiceRemainingMinutes
            val amount = if (value % 1.0 == 0.0) String.format(Locale.CHINA, "%.0f", value) else String.format(Locale.CHINA, "%.1f", value)
            (if (card.voiceEstimated) "约 " else "") + amount + " 分钟"
        }
        else -> "未提供"
    }
}

/** A short widget omits complete cards and explains the omission. */
object WidgetAccountLayout {
    const val CARD_HEIGHT_DP = 100
    fun visibleCount(total: Int, minHeightDp: Int): Int {
        if (total <= 0) return 0
        val available = (minHeightDp.takeIf { it > 0 } ?: 280) - 68
        return (available / (CARD_HEIGHT_DP + 6)).coerceIn(1, 4).coerceAtMost(total)
    }
}
