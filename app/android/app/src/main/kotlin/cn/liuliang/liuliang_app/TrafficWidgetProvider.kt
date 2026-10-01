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
            val accountId = (map["accountId"] as? String)?.takeIf {
                it.matches(Regex("[A-Za-z0-9_]{1,48}"))
            } ?: return@mapNotNull null
            val carrier = map["carrier"] as? String ?: return@mapNotNull null
            if (carrier !in WidgetCarrierSelection.order || carrier !in selected || !seen.add(accountId)) {
                return@mapNotNull null
            }
            if (accountId != carrier && accountId != "${carrier}_2") return@mapNotNull null
            val status = map["status"] as? String ?: return@mapNotNull null
            if (status !in setOf("notConnected", "loading", "success", "authExpired", "error")) {
                return@mapNotNull null
            }
            val accountLabel = (map["accountLabel"] as? String)
                ?.takeIf { it.isNotBlank() && it.length <= 40 } ?: carrierLabel(carrier)
            val amount = (map["primaryValue"] as? Number)?.toLong()?.takeIf { it >= 0L }
            val primaryLabel = map["primaryLabel"] as? String ?: "余额待确认"
            val queriedAt = (map["queriedAt"] as? Number)?.toLong()?.takeIf { it > 0L }
            WidgetCardData(
                status = status,
                remainingBytes = amount,
                label = primaryLabel,
                queriedAt = queriedAt,
                unlimited = map["isUnlimited"] == true,
                accountId = accountId,
                carrier = carrier,
                accountLabel = accountLabel,
            )
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
        val rawAmount = when {
            unlimited -> "不限量"
            knownStatus && validAmount != null -> formatBytes(validAmount)
            else -> "—"
        }
        val amount = if (card.label == "套餐估算余量" && rawAmount != "—") "约 $rawAmount" else rawAmount
        val state = when (card.status) {
            "success" -> when {
                validTime == null -> "待确认"
                stale -> "已过期"
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
        val label = if (card.label == "通用剩余" || card.label == "套餐余量" || card.label == "含不限量套餐" ||
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
        ids.forEach { manager.updateAppWidget(it, createViews(context)) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: android.os.Bundle) {
        manager.updateAppWidget(appWidgetId, createViews(context))
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

        /** Stores only the whitelisted display snapshot. No number or session is accepted. */
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
                    if (carrier in selected) writeCard(carrier, parseCard(root[carrier]))
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
            ids.forEach { manager.updateAppWidget(it, createViews(context)) }
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

        private fun parseCard(raw: Any?): WidgetCardData {
            val map = raw as? Map<*, *> ?: return WidgetCardData()
            val status = (map["status"] as? String)?.takeIf {
                it in setOf("notConnected", "loading", "success", "authExpired", "error")
            } ?: return WidgetCardData()
            val amount = (map["remainingBytes"] as? Number)?.toLong()?.takeIf { it >= 0L }
            val queriedAt = (map["queriedAt"] as? Number)?.toLong()?.takeIf { it > 0L }
            val label = map["label"] as? String ?: "通用剩余"
            return WidgetCardData(status = status, remainingBytes = amount, label = label, queriedAt = queriedAt,
                unlimited = map["unlimited"] == true || map["isUnlimited"] == true)
        }

        private fun android.content.SharedPreferences.Editor.writeInstance(index: Int, card: WidgetCardData) {
            putString("instance_${index}_id", card.accountId)
            putString("instance_${index}_carrier", card.carrier)
            putString("instance_${index}_accountLabel", card.accountLabel)
            putString("instance_${index}_status", card.status)
            putString("instance_${index}_label", card.label)
            putBoolean("instance_${index}_unlimited", card.unlimited)
            card.remainingBytes?.let { putLong("instance_${index}_remainingBytes", it) }
            card.queriedAt?.let { putLong("instance_${index}_queriedAt", it) }
        }

        private fun android.content.SharedPreferences.Editor.writeCard(prefix: String, card: WidgetCardData) {
            putString("${prefix}_status", card.status)
            putString("${prefix}_label", card.label)
            putBoolean("${prefix}_unlimited", card.unlimited)
            card.remainingBytes?.let { putLong("${prefix}_remainingBytes", it) }
            card.queriedAt?.let { putLong("${prefix}_queriedAt", it) }
        }

        private fun readCard(context: Context, prefix: String): WidgetCardData {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return WidgetCardData(
                carrier = prefix,
                status = prefs.getString("${prefix}_status", "notConnected") ?: "notConnected",
                remainingBytes = if (prefs.contains("${prefix}_remainingBytes")) prefs.getLong("${prefix}_remainingBytes", -1L) else null,
                label = prefs.getString("${prefix}_label", "通用剩余") ?: "通用剩余",
                queriedAt = if (prefs.contains("${prefix}_queriedAt")) prefs.getLong("${prefix}_queriedAt", 0L) else null,
                unlimited = prefs.getBoolean("${prefix}_unlimited", false),
            )
        }

        private fun readInstance(context: Context, index: Int): WidgetCardData {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return WidgetCardData(
                accountId = prefs.getString("instance_${index}_id", null),
                carrier = prefs.getString("instance_${index}_carrier", null),
                accountLabel = prefs.getString("instance_${index}_accountLabel", null),
                status = prefs.getString("instance_${index}_status", "notConnected") ?: "notConnected",
                remainingBytes = if (prefs.contains("instance_${index}_remainingBytes")) prefs.getLong("instance_${index}_remainingBytes", -1L) else null,
                label = prefs.getString("instance_${index}_label", "余额待确认") ?: "余额待确认",
                queriedAt = if (prefs.contains("instance_${index}_queriedAt")) prefs.getLong("instance_${index}_queriedAt", 0L) else null,
                unlimited = prefs.getBoolean("instance_${index}_unlimited", false),
            )
        }

        private fun createViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.traffic_widget)
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val threshold = prefs.getFloat("thresholdGb", DEFAULT_THRESHOLD_GB.toFloat()).toDouble()
            val now = System.currentTimeMillis()
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
            val slots = listOf(
                intArrayOf(R.id.slot_1, R.id.slot_1_name, R.id.slot_1_state, R.id.slot_1_amount, R.id.slot_1_label, R.id.slot_1_time),
                intArrayOf(R.id.slot_2, R.id.slot_2_name, R.id.slot_2_state, R.id.slot_2_amount, R.id.slot_2_label, R.id.slot_2_time),
                intArrayOf(R.id.slot_3, R.id.slot_3_name, R.id.slot_3_state, R.id.slot_3_amount, R.id.slot_3_label, R.id.slot_3_time),
                intArrayOf(R.id.slot_4, R.id.slot_4_name, R.id.slot_4_state, R.id.slot_4_amount, R.id.slot_4_label, R.id.slot_4_time),
            )
            slots.forEachIndexed { index, ids ->
                val card = cards.getOrNull(index)
                val carrier = card?.carrier ?: legacySelected.getOrNull(index)
                views.setViewVisibility(ids[0], if (card == null) View.GONE else View.VISIBLE)
                if (card != null && carrier != null) bindCard(views, ids, carrier, card, threshold, now, cards.size >= 3)
            }
            views.setViewVisibility(R.id.top_row, if (cards.isEmpty()) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.top_divider, if (cards.size >= 2) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.bottom_row, if (cards.size >= 3) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.bottom_divider, if (cards.size >= 4) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.row_divider, if (cards.size >= 3) View.VISIBLE else View.GONE)
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
            val (defaultName, normal) = when (carrier) {
                "mobile" -> "中国移动" to Color.rgb(51, 116, 188)
                "broadnet" -> "中国广电" to Color.rgb(201, 121, 115)
                "unicom" -> "中国联通" to Color.rgb(219, 94, 105)
                else -> "中国电信" to Color.rgb(92, 113, 207)
            }
            views.setTextViewText(ids[1], card.accountLabel ?: defaultName)
            views.setTextViewText(ids[2], display.state)
            views.setTextViewText(ids[3], display.amount)
            views.setTextViewText(ids[4], display.label)
            views.setTextViewText(ids[5], if (compact) display.time.removePrefix("上次查询 ") else display.time)
            views.setTextColor(ids[1], normal)
            val warning = Color.rgb(184, 86, 74)
            views.setTextColor(ids[3], if (display.low) warning else normal)
            views.setTextColor(ids[2], if (display.low || display.stale || card.status == "error" || card.status == "authExpired") warning else Color.rgb(111, 127, 145))
        }
    }
}

class WidgetPinResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TrafficWidgetProvider.PIN_ACTION) return
        TrafficWidgetProvider.confirmPinRequest(context, intent.getStringExtra("request_token"))
    }
}
