package cn.liuliang.liuliang_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var widgetChannel: MethodChannel? = null

    override fun onStart() {
        super.onStart()
        isAppVisible = true
    }

    override fun onStop() {
        isAppVisible = false
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.liuliang/background_refresh_schedule")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "configure" -> {
                        val minutes = call.arguments as? Int
                        if (minutes == null || minutes !in setOf(0, 60, 120, 1440)) {
                            result.error("invalid_interval", "Unsupported refresh interval", null)
                        } else {
                            try {
                                BackgroundRefreshSchedule.configure(this, minutes)
                                result.success(true)
                            } catch (error: IllegalArgumentException) {
                                result.error("invalid_interval", error.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.liuliang/widgets").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateSnapshot" -> {
                        val payload = call.arguments as? Map<*, *>
                        if (payload == null) result.error("invalid_payload", "Missing widget display data", null)
                        else {
                            TrafficWidgetProvider.saveData(this, payload)
                            TrafficWidgetProvider.updateAll(this)
                            result.success(null)
                        }
                    }
                    "clearSnapshot" -> {
                        TrafficWidgetProvider.clearData(this)
                        TrafficWidgetProvider.updateAll(this)
                        result.success(null)
                    }
                    "requestPin" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        val supported = Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported
                        val requested = supported && manager.requestPinAppWidget(
                            ComponentName(this, TrafficWidgetProvider::class.java), null, null)
                        result.success(mapOf("supported" to supported, "requested" to requested))
                    }
                    "consumeLaunchRefresh" -> {
                        val refresh = intent?.getBooleanExtra("widget_refresh", false) == true
                        intent?.removeExtra("widget_refresh")
                        result.success(refresh)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.liuliang/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else if (permissionResult != null) {
                            result.success(false)
                        } else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 731)
                        }
                    }
                    "notify" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            result.success(false)
                        } else {
                            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                            val channel = "low_traffic"
                            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(channel, "低流量提醒", NotificationManager.IMPORTANCE_DEFAULT))
                            val intent = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                            val builder = if (Build.VERSION.SDK_INT >= 26) android.app.Notification.Builder(this, channel) else android.app.Notification.Builder(this)
                            manager.notify(call.argument<Int>("id") ?: 1, builder
                                .setSmallIcon(android.R.drawable.stat_sys_warning)
                                .setContentTitle(call.argument<String>("title"))
                                .setContentText(call.argument<String>("body"))
                                .setContentIntent(intent).setAutoCancel(true).build())
                            result.success(true)
                        }
                    }
                    "cancelAll" -> {
                        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 731) {
            permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("widget_refresh", false)) {
            intent.removeExtra("widget_refresh")
            widgetChannel?.invokeMethod("openFromWidget", null)
        }
    }

    companion object {
        @Volatile
        var isAppVisible: Boolean = false
            private set
    }
}
