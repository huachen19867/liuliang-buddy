package cn.liuliang.liuliang_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
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
        val amount = if (knownStatus && validAmount != null) formatBytes(validAmount) else "—"
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
            card.label == "套餐明细合计" || card.label == "余额待确认" ||
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
            val mobile = parseCard(root["mobile"])
            val broadnet = parseCard(root["broadnet"])
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
                clear()
                putFloat("thresholdGb", threshold.toFloat())
                writeCard("mobile", mobile)
                writeCard("broadnet", broadnet)
                apply()
            }
        }

        fun clearData(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
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
            bindCard(views, readCard(context, "mobile"), threshold, now, true)
            bindCard(views, readCard(context, "broadnet"), threshold, now, false)
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

        private fun bindCard(views: RemoteViews, card: WidgetCardData, threshold: Double, now: Long, mobile: Boolean) {
            val display = WidgetPresentation.present(card, threshold, now)
            val amountId = if (mobile) R.id.mobile_amount else R.id.broadnet_amount
            val stateId = if (mobile) R.id.mobile_state else R.id.broadnet_state
            val labelId = if (mobile) R.id.mobile_label else R.id.broadnet_label
            val timeId = if (mobile) R.id.mobile_time else R.id.broadnet_time
            views.setTextViewText(amountId, display.amount)
            views.setTextViewText(stateId, display.state)
            views.setTextViewText(labelId, display.label)
            views.setTextViewText(timeId, display.time)
            val normal = if (mobile) Color.rgb(51, 116, 188) else Color.rgb(201, 121, 115)
            val warning = Color.rgb(184, 86, 74)
            views.setTextColor(amountId, if (display.low) warning else normal)
            views.setTextColor(stateId, if (display.low || display.stale || card.status == "error" || card.status == "authExpired") warning else Color.rgb(111, 127, 145))
        }
    }
}
