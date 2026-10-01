package cn.liuliang.liuliang_app

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

internal object BackgroundRefreshSchedule {
    private const val UNIQUE_NAME = "liuliang_background_refresh"
    private const val MIN_INTERVAL_MINUTES = 15
    private const val MAX_INTERVAL_MINUTES = 24 * 60
    private val revision = AtomicLong(0)

    fun currentRevision(): Long = revision.get()

    fun isCurrent(expected: Long): Boolean = revision.get() == expected

    fun invalidateRunningTask() { revision.incrementAndGet() }

    fun status(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences("background_refresh_status", Context.MODE_PRIVATE)
        return mapOf(
            "intervalMinutes" to prefs.getInt("intervalMinutes", 0),
            "lastStartedAt" to prefs.getLong("startedAt", 0),
            "lastFinishedAt" to prefs.getLong("finishedAt", 0),
            "lastOutcome" to (prefs.getString("outcome", "never") ?: "never"),
            "lastMessage" to "",
        )
    }

    fun configure(context: Context, intervalMinutes: Int) {
        require(intervalMinutes in setOf(0, 60, 120, 1440))
        invalidateRunningTask()
        context.getSharedPreferences("background_refresh_status", Context.MODE_PRIVATE)
            .edit().putInt("intervalMinutes", intervalMinutes).apply()
        val workManager = WorkManager.getInstance(context)
        if (intervalMinutes == 0) {
            workManager.cancelUniqueWork(UNIQUE_NAME)
            return
        }
        require(intervalMinutes == 60 || intervalMinutes == 120 || intervalMinutes == 1440)
        require(intervalMinutes in MIN_INTERVAL_MINUTES..MAX_INTERVAL_MINUTES)
        val request = PeriodicWorkRequestBuilder<BackgroundRefreshWorker>(
            intervalMinutes.toLong(), TimeUnit.MINUTES,
        )
            .setInitialDelay(intervalMinutes.toLong(), TimeUnit.MINUTES)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .build()
        workManager.enqueueUniquePeriodicWork(
            UNIQUE_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }
}

/** Runs the same Dart parsers and official page probes in a headless Flutter engine. */
class BackgroundRefreshWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        if (MainActivity.isAppVisible) return Result.success()
        val runRevision = BackgroundRefreshSchedule.currentRevision()

        val loader = FlutterInjector.instance().flutterLoader()
        val finished = CountDownLatch(1)
        val engineReady = CountDownLatch(1)
        val mainHandler = Handler(Looper.getMainLooper())
        val engineRef = AtomicReference<FlutterEngine?>()
        val initializationError = AtomicReference<Exception?>()
        val cancelled = AtomicBoolean(false)
        val outcome = AtomicReference("timeout")
        val statusPrefs = applicationContext.getSharedPreferences("background_refresh_status", Context.MODE_PRIVATE)
        statusPrefs.edit().putLong("startedAt", System.currentTimeMillis())
            .putLong("finishedAt", 0).putString("outcome", "running").apply()

        fun current(): Boolean = !cancelled.get() && !isStopped &&
            !MainActivity.isAppVisible && BackgroundRefreshSchedule.isCurrent(runRevision)

        mainHandler.post {
            try {
                if (!current()) return@post
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                if (!current()) return@post
                val engine = FlutterEngine(applicationContext)
                engineRef.set(engine)
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "ready" -> {
                            result.success(null)
                            mainHandler.post { if (current()) channel.invokeMethod("start", null) }
                        }
                        "isTaskCurrent" -> result.success(current())
                        "completed" -> {
                            val payload = call.argument<Map<*, *>>("widgetPayload")
                            if (payload != null && current()) {
                                TrafficWidgetProvider.saveData(applicationContext, payload)
                                TrafficWidgetProvider.updateAll(applicationContext)
                            }
                            outcome.set(if (current()) call.argument<String>("outcome") ?: "completed" else "cancelled")
                            result.success(null)
                            finished.countDown()
                        }
                        "failed" -> {
                            outcome.set("failed")
                            result.success(null)
                            finished.countDown()
                        }
                        else -> result.notImplemented()
                    }
                }
                val entrypoint = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "backgroundRefreshEntrypoint",
                )
                engine.dartExecutor.executeDartEntrypoint(entrypoint)
            } catch (error: Exception) {
                initializationError.set(error)
            } finally {
                engineReady.countDown()
            }
        }

        try {
            if (!engineReady.await(30, TimeUnit.SECONDS) || initializationError.get() != null) {
                outcome.set("initialization_failed")
                return Result.success()
            }
            val deadline = System.nanoTime() + TimeUnit.MINUTES.toNanos(4)
            while (System.nanoTime() < deadline && !isStopped) {
                if (!current()) { outcome.set("cancelled"); break }
                if (finished.await(1, TimeUnit.SECONDS)) break
            }
        } catch (_: InterruptedException) {
            outcome.set("cancelled")
            Thread.currentThread().interrupt()
        } catch (_: Exception) {
            outcome.set("failed")
            // A periodic task will try again on a later scheduled interval.
        } finally {
            cancelled.set(true)
            if (isStopped) outcome.set("cancelled")
            statusPrefs.edit().putLong("finishedAt", System.currentTimeMillis())
                .putString("outcome", outcome.get()).apply()
            val destroyed = CountDownLatch(1)
            mainHandler.post {
                engineRef.getAndSet(null)?.destroy()
                destroyed.countDown()
            }
            try {
                destroyed.await(5, TimeUnit.SECONDS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
        // Do not return retry for carrier login/network failures: that could
        // create a retry burst. The next user-selected period is authoritative.
        return Result.success()
    }

    companion object {
        private const val CHANNEL = "cn.liuliang/background_refresh"
    }
}
