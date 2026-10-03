package cn.liuliang.liuliang_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class WidgetCardData(
    val status: String = "notConnected",
    val remainingBytes: Long? = null,
    val label: String = "通用剩余",
    val queriedAt: Long? = null,
    val unlimited: Boolean = false,
    val accountId: String? = null,
    val carrier: String? = null,
    val accountLabel: String? = null,
    val name: String? = null,
    val phoneHint: String? = null,
    val balanceYuan: Double? = null,
    val generalState: String = "unavailable",
    val generalRemainingBytes: Long? = null,
    val directedState: String = "unavailable",
    val directedRemainingBytes: Long? = null,
    val otherState: String = "unavailable",
    val otherRemainingBytes: Long? = null,
    val otherPendingCount: Int = 0,
    val trafficEstimated: Boolean = false,
    val voiceState: String = "unavailable",
    val voiceRemainingMinutes: Double? = null,
    val voiceEstimated: Boolean = false,
    val trafficReadableCount: Int = 0,
    val trafficPendingCount: Int = 0,
    val previewRemainingBytes: Long? = null,
    val previewUnlimited: Boolean = false,
)

data class WidgetCardPresentation(
    val amount: String,
    val state: String,
    val label: String,
    val time: String,
    val low: Boolean,
    val stale: Boolean,
    val unlimited: Boolean = false,
)

enum class WidgetPinStatus(val wireValue: String) {
    AlreadyAdded("already_added"),
    RequestPendingConfirmation("request_pending_confirmation"),
    Unsupported("unsupported"),
    NotAdded("not_added"),
}

/** Pure state rules keep a request accepted by a launcher distinct from an installed widget. */
object WidgetPinState {
    const val PENDING_TIMEOUT_MS = 15L * 60L * 1000L

    fun installationStatus(
        installedCount: Int,
        pinSupported: Boolean,
        pendingSince: Long?,
        nowMillis: Long,
        confirmedAt: Long? = null,
    ): WidgetPinStatus {
        if (installedCount > 0 || (confirmedAt != null && confirmedAt > 0L)) {
            return WidgetPinStatus.AlreadyAdded
        }
        val pendingAge = pendingSince?.let { nowMillis - it }
        if (pendingAge != null && pendingAge in 0..PENDING_TIMEOUT_MS) {
            return WidgetPinStatus.RequestPendingConfirmation
        }
        return if (pinSupported) WidgetPinStatus.NotAdded else WidgetPinStatus.Unsupported
    }
}

/** Missing key is an older two-card payload; an invalid present key shows no card. */
object WidgetCarrierSelection {
    val order = listOf("mobile", "broadnet", "unicom", "telecom")

    fun fromPayload(raw: Any?, keyPresent: Boolean): Set<String> {
        if (!keyPresent) return setOf("mobile", "broadnet")
        return (raw as? List<*>)
            ?.filterIsInstance<String>()
            ?.filter { it in order }
            ?.toSet() ?: emptySet()
    }

    fun displayOrder(selected: Set<String>): List<String> = order.filter { it in selected }
}

object WidgetInstances {
    const val MAX = 4

    fun fromPayload(raw: Any?, selected: Set<String>): List<WidgetCardData> {
        val values = raw as? List<*> ?: return emptyList()
        val seen = mutableSetOf<String>()
        return values.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            if (map["enabled"] == false) return@mapNotNull null
            val accountId = (map["accountId"] as? String)?.takeIf {
                it.matches(Regex("[A-Za-z0-9_]{1,48}"))
            } ?: return@mapNotNull null
            val carrier = map["carrier"] as? String ?: return@mapNotNull null
            if (carrier !in WidgetCarrierSelection.order || carrier !in selected || !seen.add(accountId)) {
                return@mapNotNull null
            }
            if (accountId !in listOf(carrier, "${carrier}_2", "${carrier}_3", "${carrier}_4")) return@mapNotNull null
            val status = map["status"] as? String ?: return@mapNotNull null
            if (status !in setOf("notConnected", "loading", "success", "authExpired", "error")) {
                return@mapNotNull null
            }
            val accountLabel = WidgetAccountDetails.safeName(map["accountLabel"]) ?: carrierLabel(carrier)
            val amount = WidgetAccountDetails.safeBytes(map["primaryValue"])
            val primaryLabel = WidgetAccountDetails.safeLabel(map["primaryLabel"])
            val queriedAt = WidgetAccountDetails.safeBytes(map["queriedAt"])?.takeIf { it > 0L }
            WidgetAccountDetails.attach(WidgetCardData(
                status = status,
                remainingBytes = amount,
                label = primaryLabel,
                queriedAt = queriedAt,
                unlimited = map["isUnlimited"] == true,
                accountId = accountId,
                carrier = carrier,
                accountLabel = accountLabel,
            ), map)
        }.take(MAX)
    }

    private fun carrierLabel(carrier: String): String = when (carrier) {
        "mobile" -> "中国移动"
        "broadnet" -> "中国广电"
        "unicom" -> "中国联通"
        else -> "中国电信"
    }
}

/** Pure display rules. A cached amount always carries its original query time. */
object WidgetPresentation {
    private const val MIB = 1024L * 1024L
    private const val GIB = MIB * 1024L
    private const val STALE_AFTER_MS = 24L * 60L * 60L * 1000L

    fun formatBytes(bytes: Long?): String {
        if (bytes == null || bytes < 0L) return "—"
        if (bytes == 0L) return "0 MB"
        if (bytes < MIB) return "<1 MB"
        if (bytes < GIB / 10L) return String.format(Locale.CHINA, "%.1f MB", bytes.toDouble() / MIB)
        return String.format(Locale.CHINA, "%.2f GB", bytes.toDouble() / GIB)
    }

    fun present(card: WidgetCardData, thresholdGb: Double, nowMillis: Long): WidgetCardPresentation {
        val validTime = card.queriedAt?.takeIf { it > 0L && it <= nowMillis + 5L * 60L * 1000L }
        // A byte count without its original query time cannot be presented as an official result.
        val validAmount = card.remainingBytes?.takeIf { it >= 0L && validTime != null }
        val stale = validTime != null && nowMillis - validTime > STALE_AFTER_MS
        val low = card.label == "通用剩余" && validAmount != null &&
            thresholdGb.isFinite() && thresholdGb >= 0.0 &&
            validAmount.toDouble() <= thresholdGb * GIB
        val knownStatus = card.status in setOf("notConnected", "loading", "success", "authExpired", "error")
        val unlimited = card.unlimited && knownStatus && validTime != null
        val partial = WidgetAccountDetails.hasPartialPreview(card, nowMillis)
        val rawAmount = when {
            partial -> WidgetAccountDetails.previewAmount(card)
            unlimited -> "不限量"
            knownStatus && validAmount != null -> formatBytes(validAmount)
            else -> "—"
        }
        val amount = if (!partial && card.label == "套餐估算余量" && rawAmount != "—") "约 $rawAmount" else rawAmount
        val state = when (card.status) {
            "success" -> when {
                validTime == null -> "待确认"
                stale -> "已过期"
                partial -> "${card.trafficReadableCount}项可读 · ${card.trafficPendingCount}项待确认"
                unlimited -> "上次记录"
                validAmount == null -> "待确认"
                low -> "余量偏低"
                else -> "上次记录"
            }
            "loading" -> "查询中"
            "authExpired" -> "待验证"
            "error" -> "查询失败"
            else -> "未连接"
        }
        val label = if (partial) "单项套餐余量" else if (card.label == "通用剩余" || card.label == "套餐余量" || card.label == "含不限量套餐" ||
            card.label == "套餐明细合计" || card.label == "套餐估算余量" || card.label == "余额待确认" ||
            card.label == "套餐余量·用途待确认") card.label else "套餐余量·用途待确认"
        val time = validTime?.let {
            "上次查询 " + SimpleDateFormat("MM/dd HH:mm", Locale.CHINA).format(Date(it))
        } ?: "尚无查询时间"
        return WidgetCardPresentation(amount, state, label, time, low && amount != "—" && !unlimited, stale, unlimited)
    }
}

class TrafficWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, createViews(context, manager.getAppWidgetOptions(it))) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: android.os.Bundle) {
        manager.updateAppWidget(appWidgetId, createViews(context, newOptions))
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        context.getSharedPreferences(PIN_PREFS, Context.MODE_PRIVATE).edit()
            .remove(PIN_CONFIRMED_AT)
            .apply()
    }

    companion object {
        private const val PREFS = "traffic_widget_display"
        private const val PIN_PREFS = "traffic_widget_pin_state"
        private const val PIN_PENDING_AT = "pending_at"
        private const val PIN_REQUEST_TOKEN = "request_token"
        private const val PIN_CONFIRMED_AT = "confirmed_at"
        internal const val PIN_ACTION = "cn.liuliang.liuliang_app.WIDGET_PIN_CONFIRMED"
        private const val DEFAULT_THRESHOLD_GB = 5.0

        /** Stores only whitelisted display fields, including strictly masked phone hints. */
        fun saveData(context: Context, root: Map<*, *>) {
            val schema = (root["schema"] as? Number)?.toInt()
            if (schema !in setOf(1, 2)) {
                clearData(context)
                return
            }
            val threshold = (root["thresholdGb"] as? Number)?.toDouble()
                ?.takeIf { it.isFinite() && it >= 0.0 } ?: DEFAULT_THRESHOLD_GB
            val selected = WidgetCarrierSelection.fromPayload(
                root["selectedCarriers"], root.containsKey("selectedCarriers"))
            val instances = if (schema == 2) WidgetInstances.fromPayload(root["instances"], selected) else emptyList()
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                clear()
                putInt("schema", schema!!)
                putFloat("thresholdGb", threshold.toFloat())
                putBoolean("selectionPresent", true)
                WidgetCarrierSelection.order.forEach { carrier ->
                    putBoolean("${carrier}Selected", carrier in selected)
                    if (carrier in selected) writeCard(carrier, parseCard(root[carrier], carrier))
                }
                putInt("instanceCount", instances.size)
                instances.forEachIndexed { index, card -> writeInstance(index, card) }
                apply()
            }
        }

        fun clearData(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .clear()
                .putBoolean("selectionPresent", true)
                .apply()
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TrafficWidgetProvider::class.java))
            ids.forEach { manager.updateAppWidget(it, createViews(context, manager.getAppWidgetOptions(it))) }
            SystemSurfaces.refresh(context)
        }

        /** The widget and system surfaces read exactly the same validated display cache. */
        internal fun displayCards(context: Context): Pair<List<WidgetCardData>, Double> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val threshold = prefs.getFloat("thresholdGb", DEFAULT_THRESHOLD_GB.toFloat()).toDouble()
            val hasSelection = prefs.getBoolean("selectionPresent", false)
            val legacySelected = if (hasSelection) WidgetCarrierSelection.displayOrder(
                WidgetCarrierSelection.order.filter { prefs.getBoolean("${it}Selected", false) }.toSet()
            ) else listOf("mobile", "broadnet")
            val cards = if (prefs.getInt("schema", 1) == 2) {
                (0 until prefs.getInt("instanceCount", 0).coerceIn(0, WidgetInstances.MAX))
                    .map { readInstance(context, it) }
            } else {
                legacySelected.map { readCard(context, it) }
            }
            return cards to threshold
        }

        fun installationStatus(context: Context, nowMillis: Long = System.currentTimeMillis()): Map<String, String> {
            val manager = AppWidgetManager.getInstance(context)
            val installedCount = manager.getAppWidgetIds(
                ComponentName(context, TrafficWidgetProvider::class.java),
            ).size
            val prefs = context.getSharedPreferences(PIN_PREFS, Context.MODE_PRIVATE)
            val pinSupported = Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported
            val status = WidgetPinState.installationStatus(
                installedCount = installedCount,
                pinSupported = pinSupported,
                pendingSince = if (prefs.contains(PIN_PENDING_AT)) prefs.getLong(PIN_PENDING_AT, 0L) else null,
                confirmedAt = if (prefs.contains(PIN_CONFIRMED_AT)) prefs.getLong(PIN_CONFIRMED_AT, 0L) else null,
                nowMillis = nowMillis,
            )
            if (status != WidgetPinStatus.RequestPendingConfirmation) {
                prefs.edit().remove(PIN_PENDING_AT).remove(PIN_REQUEST_TOKEN).apply()
            }
            return if (status == WidgetPinStatus.Unsupported) {
                mapOf(
                    "status" to status.wireValue,
                    "reason" to if (Build.VERSION.SDK_INT < 26) "pin_api_unavailable" else "launcher_unsupported",
                )
            } else {
                mapOf("status" to status.wireValue)
            }
        }

        /** A true return from requestPinAppWidget only means the Launcher accepted the request. */
        fun requestPin(context: Context, nowMillis: Long = System.currentTimeMillis()): Map<String, String> {
            val initialStatus = installationStatus(context, nowMillis)
            val current = initialStatus["status"]
            when (current) {
                WidgetPinStatus.AlreadyAdded.wireValue,
                WidgetPinStatus.RequestPendingConfirmation.wireValue,
                WidgetPinStatus.Unsupported.wireValue -> return initialStatus
            }

            val manager = AppWidgetManager.getInstance(context)
            if (Build.VERSION.SDK_INT < 26 || !manager.isRequestPinAppWidgetSupported) {
                return mapOf("status" to WidgetPinStatus.Unsupported.wireValue)
            }
            val token = java.util.UUID.randomUUID().toString()
            val callbackIntent = Intent(context, WidgetPinResultReceiver::class.java).apply {
                action = PIN_ACTION
                data = Uri.parse("liuliang-widget://pin/$token")
                putExtra("request_token", token)
            }
            val callback = PendingIntent.getBroadcast(
                context,
                token.hashCode(),
                callbackIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            context.getSharedPreferences(PIN_PREFS, Context.MODE_PRIVATE).edit()
                .putLong(PIN_PENDING_AT, nowMillis)
                .putString(PIN_REQUEST_TOKEN, token)
                .remove(PIN_CONFIRMED_AT)
                .apply()
            val accepted = try {
                manager.requestPinAppWidget(
                    ComponentName(context, TrafficWidgetProvider::class.java),
                    null,
                    callback,
                )
            } catch (_: RuntimeException) {
                false
            }
            if (accepted) return mapOf("status" to WidgetPinStatus.RequestPendingConfirmation.wireValue)

            context.getSharedPreferences(PIN_PREFS, Context.MODE_PRIVATE).edit()
                .remove(PIN_PENDING_AT)
                .remove(PIN_REQUEST_TOKEN)
                .apply()
            return mapOf(
                "status" to WidgetPinStatus.Unsupported.wireValue,
                "reason" to "launcher_rejected_request",
            )
        }

        internal fun confirmPinRequest(context: Context, token: String?) {
            if (token.isNullOrBlank()) return
            val prefs = context.getSharedPreferences(PIN_PREFS, Context.MODE_PRIVATE)
            if (prefs.getString(PIN_REQUEST_TOKEN, null) != token) return
            prefs.edit()
                .remove(PIN_PENDING_AT)
                .remove(PIN_REQUEST_TOKEN)
                .putLong(PIN_CONFIRMED_AT, System.currentTimeMillis())
                .apply()
            updateAll(context)
        }

        private fun parseCard(raw: Any?, carrier: String): WidgetCardData {
            val map = raw as? Map<*, *> ?: return WidgetCardData()
            val status = (map["status"] as? String)?.takeIf {
                it in setOf("notConnected", "loading", "success", "authExpired", "error")
            } ?: return WidgetCardData()
            val amount = WidgetAccountDetails.safeBytes(map["remainingBytes"])
            val queriedAt = WidgetAccountDetails.safeBytes(map["queriedAt"])?.takeIf { it > 0L }
            val label = WidgetAccountDetails.safeLabel(map["label"])
            return WidgetAccountDetails.attach(WidgetCardData(carrier = carrier, status = status, remainingBytes = amount, label = label, queriedAt = queriedAt,
                unlimited = map["unlimited"] == true || map["isUnlimited"] == true), map)
        }

        private fun android.content.SharedPreferences.Editor.writeInstance(index: Int, card: WidgetCardData) {
            writePartial("instance_${index}", card)
            putString("instance_${index}_id", card.accountId)
            putString("instance_${index}_carrier", card.carrier)
            putString("instance_${index}_accountLabel", card.accountLabel)
            putString("instance_${index}_status", card.status)
            putString("instance_${index}_label", card.label)
            putBoolean("instance_${index}_unlimited", card.unlimited)
            card.remainingBytes?.let { putLong("instance_${index}_remainingBytes", it) }
            card.queriedAt?.let { putLong("instance_${index}_queriedAt", it) }
            putString("instance_${index}_name", WidgetAccountDetails.safeName(card.name))
            putString("instance_${index}_phoneHint", WidgetAccountDetails.safePhoneHint(card.phoneHint))
            card.balanceYuan?.let { putString("instance_${index}_balanceYuan", it.toString()) }
            putString("instance_${index}_generalState", card.generalState)
            card.generalRemainingBytes?.let { putLong("instance_${index}_generalRemainingBytes", it) }
            putString("instance_${index}_directedState", card.directedState)
            card.directedRemainingBytes?.let { putLong("instance_${index}_directedRemainingBytes", it) }
            putString("instance_${index}_otherState", card.otherState)
            putInt("instance_${index}_otherPendingCount", card.otherPendingCount)
            card.otherRemainingBytes?.let { putLong("instance_${index}_otherRemainingBytes", it) }
            putBoolean("instance_${index}_trafficEstimated", card.trafficEstimated)
            putString("instance_${index}_voiceState", card.voiceState)
            card.voiceRemainingMinutes?.let { putString("instance_${index}_voiceRemainingMinutes", it.toString()) }
            putBoolean("instance_${index}_voiceEstimated", card.voiceEstimated)
        }

        private fun android.content.SharedPreferences.Editor.writeCard(prefix: String, card: WidgetCardData) {
            writePartial(prefix, card)
            putString("${prefix}_status", card.status)
            putString("${prefix}_label", card.label)
            putBoolean("${prefix}_unlimited", card.unlimited)
            card.remainingBytes?.let { putLong("${prefix}_remainingBytes", it) }
            card.queriedAt?.let { putLong("${prefix}_queriedAt", it) }
        }

        private fun android.content.SharedPreferences.Editor.writePartial(prefix: String, card: WidgetCardData) {
            putInt("${prefix}_trafficReadableCount", card.trafficReadableCount)
            putInt("${prefix}_trafficPendingCount", card.trafficPendingCount)
            card.previewRemainingBytes?.let { putLong("${prefix}_previewRemainingBytes", it) }
            putBoolean("${prefix}_previewUnlimited", card.previewUnlimited)
        }

        private fun readPartial(prefs: android.content.SharedPreferences, prefix: String): Map<String, Any?> = mapOf(
            "trafficReadableCount" to prefs.getInt("${prefix}_trafficReadableCount", 0),
            "trafficPendingCount" to prefs.getInt("${prefix}_trafficPendingCount", 0),
            "previewRemainingBytes" to if (prefs.contains("${prefix}_previewRemainingBytes")) prefs.getLong("${prefix}_previewRemainingBytes", -1L) else null,
            "previewUnlimited" to prefs.getBoolean("${prefix}_previewUnlimited", false),
        )

        private fun readCard(context: Context, prefix: String): WidgetCardData {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return WidgetAccountDetails.attach(WidgetCardData(
                carrier = prefix,
                status = prefs.getString("${prefix}_status", "notConnected") ?: "notConnected",
                remainingBytes = if (prefs.contains("${prefix}_remainingBytes")) prefs.getLong("${prefix}_remainingBytes", -1L) else null,
                label = WidgetAccountDetails.safeLabel(prefs.getString("${prefix}_label", "通用剩余")),
                queriedAt = if (prefs.contains("${prefix}_queriedAt")) prefs.getLong("${prefix}_queriedAt", 0L) else null,
                unlimited = prefs.getBoolean("${prefix}_unlimited", false),
            ), readPartial(prefs, prefix))
        }

        private fun readInstance(context: Context, index: Int): WidgetCardData {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val card = WidgetCardData(
                accountId = prefs.getString("instance_${index}_id", null),
                carrier = prefs.getString("instance_${index}_carrier", null),
                accountLabel = WidgetAccountDetails.safeName(prefs.getString("instance_${index}_accountLabel", null)),
                status = prefs.getString("instance_${index}_status", "notConnected") ?: "notConnected",
                remainingBytes = if (prefs.contains("instance_${index}_remainingBytes")) prefs.getLong("instance_${index}_remainingBytes", -1L) else null,
                label = WidgetAccountDetails.safeLabel(prefs.getString("instance_${index}_label", "余额待确认")),
                queriedAt = if (prefs.contains("instance_${index}_queriedAt")) prefs.getLong("instance_${index}_queriedAt", 0L) else null,
                unlimited = prefs.getBoolean("instance_${index}_unlimited", false),
            )
            return WidgetAccountDetails.attach(card, readPartial(prefs, "instance_${index}") + mapOf(
                "name" to prefs.getString("instance_${index}_name", null),
                "phoneHint" to prefs.getString("instance_${index}_phoneHint", null),
                "balanceYuan" to prefs.getString("instance_${index}_balanceYuan", null)?.toDoubleOrNull(),
                "generalState" to prefs.getString("instance_${index}_generalState", null),
                "generalRemainingBytes" to if (prefs.contains("instance_${index}_generalRemainingBytes")) prefs.getLong("instance_${index}_generalRemainingBytes", -1L) else null,
                "directedState" to prefs.getString("instance_${index}_directedState", null),
                "directedRemainingBytes" to if (prefs.contains("instance_${index}_directedRemainingBytes")) prefs.getLong("instance_${index}_directedRemainingBytes", -1L) else null,
                "otherState" to prefs.getString("instance_${index}_otherState", null),
                "otherPendingCount" to prefs.getInt("instance_${index}_otherPendingCount", 0),
                "otherRemainingBytes" to if (prefs.contains("instance_${index}_otherRemainingBytes")) prefs.getLong("instance_${index}_otherRemainingBytes", -1L) else null,
                "trafficEstimated" to prefs.getBoolean("instance_${index}_trafficEstimated", false),
                "voiceState" to prefs.getString("instance_${index}_voiceState", null),
                "voiceRemainingMinutes" to prefs.getString("instance_${index}_voiceRemainingMinutes", null)?.toDoubleOrNull(),
                "voiceEstimated" to prefs.getBoolean("instance_${index}_voiceEstimated", false),
            ))
        }

        private fun createViews(context: Context, options: android.os.Bundle): RemoteViews {
            val (cards, threshold) = displayCards(context)
            val compact = WidgetAccountLayout.isCompact(cards.size)
            val views = RemoteViews(context.packageName, if (compact) R.layout.traffic_widget_compact else R.layout.traffic_widget)
            val now = System.currentTimeMillis()
            val visible = WidgetAccountLayout.visibleCount(cards.size, options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 280))
            val slots = listOf(
                intArrayOf(R.id.slot_1, R.id.slot_1_badge, R.id.slot_1_name, R.id.slot_1_state, R.id.slot_1_phone, R.id.slot_1_balance, R.id.slot_1_summary, R.id.slot_1_time, R.id.slot_1_general, R.id.slot_1_directed, R.id.slot_1_other, R.id.slot_1_voice, R.id.slot_1_partial, R.id.slot_1_details),
                intArrayOf(R.id.slot_2, R.id.slot_2_badge, R.id.slot_2_name, R.id.slot_2_state, R.id.slot_2_phone, R.id.slot_2_balance, R.id.slot_2_summary, R.id.slot_2_time, R.id.slot_2_general, R.id.slot_2_directed, R.id.slot_2_other, R.id.slot_2_voice, R.id.slot_2_partial, R.id.slot_2_details),
                intArrayOf(R.id.slot_3, R.id.slot_3_badge, R.id.slot_3_name, R.id.slot_3_state, R.id.slot_3_phone, R.id.slot_3_balance, R.id.slot_3_summary, R.id.slot_3_time, R.id.slot_3_general, R.id.slot_3_directed, R.id.slot_3_other, R.id.slot_3_voice, R.id.slot_3_partial, R.id.slot_3_details),
                intArrayOf(R.id.slot_4, R.id.slot_4_badge, R.id.slot_4_name, R.id.slot_4_state, R.id.slot_4_phone, R.id.slot_4_balance, R.id.slot_4_summary, R.id.slot_4_time, R.id.slot_4_general, R.id.slot_4_directed, R.id.slot_4_other, R.id.slot_4_voice, R.id.slot_4_partial, R.id.slot_4_details),
            )
            slots.forEachIndexed { index, ids ->
                val card = cards.getOrNull(index)
                val carrier = card?.carrier
                views.setViewVisibility(ids[0], if (card == null || index >= visible) View.GONE else View.VISIBLE)
                if (card != null && carrier != null && index < visible) bindCard(views, ids, carrier, card, threshold, now, compact)
            }
            views.setTextViewText(R.id.widget_more, if (cards.size > visible) "另${cards.size - visible}张，请打开应用" else "")
            views.setViewVisibility(R.id.widget_more, if (cards.size > visible) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_empty, if (cards.isEmpty()) View.VISIBLE else View.GONE)
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "cn.liuliang.liuliang_app.OPEN_WIDGET"
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("widget_refresh", true)
            }
            val pending = PendingIntent.getActivity(
                context, 4102, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            views.setOnClickPendingIntent(R.id.widget_refresh_action, pending)
            return views
        }

        private fun bindCard(views: RemoteViews, ids: IntArray, carrier: String, card: WidgetCardData, threshold: Double, now: Long, compact: Boolean) {
            val display = WidgetPresentation.present(card, threshold, now)
            val (defaultName, logo) = when (carrier) {
                "mobile" -> "中国移动" to R.drawable.carrier_mobile
                "broadnet" -> "中国广电" to R.drawable.carrier_broadnet
                "unicom" -> "中国联通" to R.drawable.carrier_unicom
                else -> "中国电信" to R.drawable.carrier_telecom
            }
            val valid = WidgetAccountDetails.validQuery(card, now)
            val partialPanel = WidgetAccountDetails.usePartialPanel(card, now)
            val compactBalance = WidgetAccountDetails.compactBalance(card, now)
            views.setViewVisibility(ids[13], if (partialPanel) View.GONE else View.VISIBLE)
            views.setViewVisibility(ids[12], if (partialPanel) View.VISIBLE else View.GONE)
            views.setTextViewText(ids[12], if (partialPanel) WidgetAccountDetails.partialPanel(card) else "")
            views.setImageViewResource(ids[1], logo)
            views.setContentDescription(ids[1], "${defaultName}标识")
            views.setTextViewText(ids[2], WidgetAccountDetails.safeName(card.name) ?: card.accountLabel ?: defaultName)
            fun optionalText(id: Int, value: String?) {
                views.setTextViewText(id, value ?: "")
                views.setViewVisibility(id, if (value.isNullOrEmpty()) View.GONE else View.VISIBLE)
            }
            if (compact) {
                optionalText(ids[3], null)
                optionalText(ids[4], null)
                optionalText(ids[5], compactBalance)
                optionalText(ids[6], if (partialPanel) WidgetAccountDetails.secondaryStatus(card, now) else WidgetAccountLayout.compactDetail(card, now, display.low))
            } else {
                optionalText(ids[3], WidgetAccountDetails.secondaryStatus(card, now) ?: if (display.low) "余量偏低" else null)
                optionalText(ids[4], WidgetAccountDetails.safePhoneHint(card.phoneHint))
                optionalText(ids[5], WidgetAccountDetails.balance(card, now))
                optionalText(ids[6], if (partialPanel) null else WidgetAccountDetails.primarySummary(card, now))
            }
            optionalText(ids[7], if (valid && (!compact || compactBalance.isEmpty())) display.time.removePrefix("上次查询 ") else null)
            views.setTextViewText(ids[8], WidgetAccountDetails.traffic(card.generalState, card.generalRemainingBytes, card.trafficEstimated, valid))
            views.setTextViewText(ids[9], WidgetAccountDetails.traffic(card.directedState, card.directedRemainingBytes, card.trafficEstimated, valid))
            views.setTextViewText(ids[10], WidgetAccountDetails.traffic(card.otherState, card.otherRemainingBytes, card.trafficEstimated, valid))
            views.setTextViewText(ids[11], WidgetAccountDetails.voice(card, now))
            val warning = Color.rgb(184, 86, 74)
            views.setTextColor(if (compact) ids[6] else ids[3], if (display.low || display.stale || card.status == "error" || card.status == "authExpired") warning else Color.rgb(87, 98, 116))
        }
    }
}

class WidgetPinResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TrafficWidgetProvider.PIN_ACTION) return
        TrafficWidgetProvider.confirmPinRequest(context, intent.getStringExtra("request_token"))
    }
}
