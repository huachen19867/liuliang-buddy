package cn.liuliang.liuliang_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/** A concise public rendering of the widget's private display-only cache. */
internal object SystemSurfacePresentation {
    fun lines(cards: List<WidgetCardData>, thresholdGb: Double, nowMillis: Long): List<String> =
        cards.map { card ->
            val name = when (card.carrier) {
                "mobile" -> "中国移动"
                "broadnet" -> "中国广电"
                "unicom" -> "中国联通"
                "telecom" -> "中国电信"
                else -> "流量卡"
            } + (card.accountId?.substringAfterLast('_')?.takeIf { it in setOf("2", "3", "4") }?.let { " $it" } ?: "")
            val display = WidgetPresentation.present(card, thresholdGb, nowMillis)
            "$name · ${display.amount} ${display.label} · ${display.state} · ${display.time}"
        }
}

internal object SystemSurfaceState {
    fun status(
        notificationEnabled: Boolean,
        tileEnabled: Boolean,
        permissionGranted: Boolean,
        appNotificationsAllowed: Boolean,
        channelAllowed: Boolean,
        tileAddSupported: Boolean,
    ): Map<String, Boolean> = mapOf(
        "notificationEnabled" to notificationEnabled,
        "tileEnabled" to tileEnabled,
        "notificationsAllowed" to (permissionGranted && appNotificationsAllowed && channelAllowed),
        "tileAddSupported" to tileAddSupported,
    )
}

internal object SystemSurfaces {
    private const val PREFS = "system_surfaces"
    private const val NOTIFICATION_KEY = "notification_enabled"
    private const val CHANNEL_ID = "cached_balance"
    private const val NOTIFICATION_ID = 7312

    fun status(context: Context): Map<String, Boolean> {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val permissionGranted = Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        val channelAllowed = Build.VERSION.SDK_INT < 26 ||
            notificationManager.getNotificationChannel(CHANNEL_ID)?.importance != NotificationManager.IMPORTANCE_NONE
        val componentState = context.packageManager.getComponentEnabledSetting(tileComponent(context))
        val tileEnabled = componentState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        return SystemSurfaceState.status(
            notificationEnabled = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(NOTIFICATION_KEY, false),
            tileEnabled = tileEnabled,
            permissionGranted = permissionGranted,
            appNotificationsAllowed = notificationManager.areNotificationsEnabled(),
            channelAllowed = channelAllowed,
            tileAddSupported = Build.VERSION.SDK_INT >= 33 &&
                context.getSystemService(Context.STATUS_BAR_SERVICE) is StatusBarManager,
        )
    }

    fun setNotificationEnabled(context: Context, enabled: Boolean): Map<String, Boolean> {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(NOTIFICATION_KEY, enabled).apply()
        refreshNotification(context)
        return status(context)
    }

    fun setTileEnabled(context: Context, enabled: Boolean): Map<String, Boolean> {
        context.packageManager.setComponentEnabledSetting(
            tileComponent(context),
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
        if (enabled) refreshTile(context)
        return status(context)
    }

    fun refresh(context: Context) {
        refreshNotification(context)
        refreshTile(context)
    }

    private fun refreshNotification(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!status(context).getValue("notificationEnabled")) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "常驻流量余额", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "显示各账号上次查询的缓存余额与时间"
                },
            )
        }
        if (!status(context).getValue("notificationsAllowed")) {
            manager.cancel(NOTIFICATION_ID)
            return
        }
        val (cards, threshold) = TrafficWidgetProvider.displayCards(context)
        val lines = SystemSurfacePresentation.lines(cards, threshold, System.currentTimeMillis())
        val body = lines.ifEmpty { listOf("暂无已选账号的查询记录") }.joinToString("\n")
        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = "cn.liuliang.liuliang_app.OPEN_CACHED_BALANCE"
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 7312, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL_ID)
        else Notification.Builder(context)
        val notification = builder
            .setSmallIcon(R.drawable.system_surface_icon)
            .setContentTitle("流量小伙伴 · 上次查询")
            .setContentText(lines.firstOrNull() ?: "暂无已选账号的查询记录")
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // Permission may change between the status check and posting.
        }
    }

    private fun refreshTile(context: Context) {
        if (Build.VERSION.SDK_INT < 24 || !status(context).getValue("tileEnabled")) return
        try {
            TileService.requestListeningState(context, tileComponent(context))
        } catch (_: RuntimeException) {
            // Launcher/OS tile availability never blocks updating the widget cache.
        }
    }

    fun requestAddTile(context: Context, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) {
            result.success("unsupported")
            return
        }
        if (!status(context).getValue("tileEnabled")) {
            result.success("unavailable")
            return
        }
        val manager = context.getSystemService(Context.STATUS_BAR_SERVICE) as? StatusBarManager
        if (manager == null) {
            result.success("unavailable")
            return
        }
        val completed = AtomicBoolean(false)
        val handler = Handler(Looper.getMainLooper())
        val timeout = Runnable {
            if (completed.compareAndSet(false, true)) result.success("unavailable")
        }
        handler.postDelayed(timeout, 60_000L)
        try {
            manager.requestAddTileService(
                tileComponent(context), "流量小伙伴",
                Icon.createWithResource(context, R.drawable.system_surface_icon),
                context.mainExecutor,
            ) { code ->
                if (completed.compareAndSet(false, true)) {
                    handler.removeCallbacks(timeout)
                    result.success(when (code) {
                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "already_added"
                        StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "canceled"
                        else -> "unavailable"
                    })
                }
            }
        } catch (_: RuntimeException) {
            handler.removeCallbacks(timeout)
            if (completed.compareAndSet(false, true)) result.success("unavailable")
        }
    }

    private fun tileComponent(context: Context) = ComponentName(context, TrafficQuickSettingsTileService::class.java)
}

class TrafficQuickSettingsTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        qsTile?.apply {
            label = "流量查询/刷新"
            if (Build.VERSION.SDK_INT >= 29) {
                val (cards, threshold) = TrafficWidgetProvider.displayCards(this@TrafficQuickSettingsTileService)
                val card = cards.firstOrNull {
                    WidgetPresentation.present(it, threshold, System.currentTimeMillis()).amount != "—"
                } ?: cards.firstOrNull()
                val display = card?.let { WidgetPresentation.present(it, threshold, System.currentTimeMillis()) }
                subtitle = if (display == null) "暂无缓存" else "缓存 ${display.amount} · ${display.state}"
            }
            state = Tile.STATE_ACTIVE
            updateTile()
        }
    }

    @Suppress("DEPRECATION")
    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "cn.liuliang.liuliang_app.OPEN_WIDGET"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("widget_refresh", true)
        }
        if (Build.VERSION.SDK_INT >= 34) {
            val pending = PendingIntent.getActivity(
                this, 7313, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            startActivityAndCollapse(pending)
        } else {
            startActivityAndCollapse(intent)
        }
    }
}
