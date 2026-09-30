package cn.liuliang.liuliang_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
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
)

data class WidgetCardPresentation(
    val amount: String,
    val state: String,
    val label: String,
    val time: String,
    val low: Boolean,
    val stale: Boolean,
)

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
        val rawAmount = if (knownStatus && validAmount != null) formatBytes(validAmount) else "—"
        val amount = if (card.label == "套餐估算余量" && rawAmount != "—") "约 $rawAmount" else rawAmount
        val state = when (card.status) {
            "success" -> when {
                validAmount == null -> "待确认"
                stale -> "已过期"
                low -> "余量偏低"
                else -> "上次记录"
            }
            "loading" -> "查询中"
            "authExpired" -> "待验证"
            "error" -> "查询失败"
            else -> "未连接"
        }
        val label = if (card.label == "通用剩余" || card.label == "套餐余量" ||
            card.label == "套餐明细合计" || card.label == "套餐估算余量" || card.label == "余额待确认" ||
            card.label == "套餐余量·用途待确认") card.label else "套餐余量·用途待确认"
        val time = validTime?.let {
            "上次查询 " + SimpleDateFormat("MM/dd HH:mm", Locale.CHINA).format(Date(it))
        } ?: "尚无查询时间"
        return WidgetCardPresentation(amount, state, label, time, low && amount != "—", stale)
    }
}

class TrafficWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { manager.updateAppWidget(it, createViews(context)) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: android.os.Bundle) {
        manager.updateAppWidget(appWidgetId, createViews(context))
    }

    companion object {
        private const val PREFS = "traffic_widget_display"
        private const val DEFAULT_THRESHOLD_GB = 5.0

        /** Stores only the whitelisted display snapshot. No number or session is accepted. */
        fun saveData(context: Context, root: Map<*, *>) {
            if ((root["schema"] as? Number)?.toInt() != 1) {
                clearData(context)
                return
            }
            val threshold = (root["thresholdGb"] as? Number)?.toDouble()
                ?.takeIf { it.isFinite() && it >= 0.0 } ?: DEFAULT_THRESHOLD_GB
            val selected = WidgetCarrierSelection.fromPayload(
                root["selectedCarriers"], root.containsKey("selectedCarriers"))
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                clear()
                putFloat("thresholdGb", threshold.toFloat())
                putBoolean("selectionPresent", true)
                WidgetCarrierSelection.order.forEach { carrier ->
                    putBoolean("${carrier}Selected", carrier in selected)
                    if (carrier in selected) writeCard(carrier, parseCard(root[carrier]))
                }
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

        private fun parseCard(raw: Any?): WidgetCardData {
            val map = raw as? Map<*, *> ?: return WidgetCardData()
            val status = (map["status"] as? String)?.takeIf {
                it in setOf("notConnected", "loading", "success", "authExpired", "error")
            } ?: return WidgetCardData()
            val amount = (map["remainingBytes"] as? Number)?.toLong()?.takeIf { it >= 0L }
            val queriedAt = (map["queriedAt"] as? Number)?.toLong()?.takeIf { it > 0L }
            val label = map["label"] as? String ?: "通用剩余"
            return WidgetCardData(status, amount, label, queriedAt)
        }

        private fun android.content.SharedPreferences.Editor.writeCard(prefix: String, card: WidgetCardData) {
            putString("${prefix}_status", card.status)
            putString("${prefix}_label", card.label)
            card.remainingBytes?.let { putLong("${prefix}_remainingBytes", it) }
            card.queriedAt?.let { putLong("${prefix}_queriedAt", it) }
        }

        private fun readCard(context: Context, prefix: String): WidgetCardData {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return WidgetCardData(
                status = prefs.getString("${prefix}_status", "notConnected") ?: "notConnected",
                remainingBytes = if (prefs.contains("${prefix}_remainingBytes")) prefs.getLong("${prefix}_remainingBytes", -1L) else null,
                label = prefs.getString("${prefix}_label", "通用剩余") ?: "通用剩余",
                queriedAt = if (prefs.contains("${prefix}_queriedAt")) prefs.getLong("${prefix}_queriedAt", 0L) else null,
            )
        }

        private fun createViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.traffic_widget)
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val threshold = prefs.getFloat("thresholdGb", DEFAULT_THRESHOLD_GB.toFloat()).toDouble()
            val now = System.currentTimeMillis()
            val hasSelection = prefs.getBoolean("selectionPresent", false)
            val selected = if (hasSelection) WidgetCarrierSelection.displayOrder(
                WidgetCarrierSelection.order.filter { prefs.getBoolean("${it}Selected", false) }.toSet()
            ) else listOf("mobile", "broadnet")
            val slots = listOf(
                intArrayOf(R.id.slot_1, R.id.slot_1_name, R.id.slot_1_state, R.id.slot_1_amount, R.id.slot_1_label, R.id.slot_1_time),
                intArrayOf(R.id.slot_2, R.id.slot_2_name, R.id.slot_2_state, R.id.slot_2_amount, R.id.slot_2_label, R.id.slot_2_time),
                intArrayOf(R.id.slot_3, R.id.slot_3_name, R.id.slot_3_state, R.id.slot_3_amount, R.id.slot_3_label, R.id.slot_3_time),
                intArrayOf(R.id.slot_4, R.id.slot_4_name, R.id.slot_4_state, R.id.slot_4_amount, R.id.slot_4_label, R.id.slot_4_time),
            )
            slots.forEachIndexed { index, ids ->
                val carrier = selected.getOrNull(index)
                views.setViewVisibility(ids[0], if (carrier == null) View.GONE else View.VISIBLE)
                if (carrier != null) bindCard(views, ids, carrier, readCard(context, carrier), threshold, now, selected.size >= 3)
            }
            views.setViewVisibility(R.id.top_row, if (selected.isEmpty()) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.top_divider, if (selected.size >= 2) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.bottom_row, if (selected.size >= 3) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.bottom_divider, if (selected.size >= 4) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.row_divider, if (selected.size >= 3) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_empty, if (selected.isEmpty()) View.VISIBLE else View.GONE)
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
            return views
        }

        private fun bindCard(views: RemoteViews, ids: IntArray, carrier: String, card: WidgetCardData, threshold: Double, now: Long, compact: Boolean) {
            val display = WidgetPresentation.present(card, threshold, now)
            val (name, normal) = when (carrier) {
                "mobile" -> "中国移动" to Color.rgb(51, 116, 188)
                "broadnet" -> "中国广电" to Color.rgb(201, 121, 115)
                "unicom" -> "中国联通" to Color.rgb(219, 94, 105)
                else -> "中国电信" to Color.rgb(92, 113, 207)
            }
            views.setTextViewText(ids[1], name)
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
