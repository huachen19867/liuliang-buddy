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

internal object BackgroundRefreshSchedule {
    private const val UNIQUE_NAME = "liuliang_background_refresh"
    private const val MIN_INTERVAL_MINUTES = 15
    private const val MAX_INTERVAL_MINUTES = 24 * 60
    @Volatile private var revision: Long = 0

    fun currentRevision(): Long = revision

    fun isCurrent(expected: Long): Boolean = revision == expected

    fun configure(context: Context, intervalMinutes: Int) {
        revision += 1
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

        mainHandler.post {
            try {
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val engine = FlutterEngine(applicationContext)
                engineRef.set(engine)
                val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "ready" -> {
                            result.success(null)
                            mainHandler.post { channel.invokeMethod("start", null) }
                        }
                        "isTaskCurrent" -> result.success(
                            !MainActivity.isAppVisible &&
                                BackgroundRefreshSchedule.isCurrent(runRevision),
                        )
                        "completed" -> {
                            val payload = call.argument<Map<*, *>>("widgetPayload")
                            if (payload != null &&
                                !MainActivity.isAppVisible &&
                                BackgroundRefreshSchedule.isCurrent(runRevision)) {
                                TrafficWidgetProvider.saveData(applicationContext, payload)
                                TrafficWidgetProvider.updateAll(applicationContext)
                            }
                            result.success(null)
                            finished.countDown()
                        }
                        "failed" -> {
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
                return Result.success()
            }
            val deadline = System.nanoTime() + TimeUnit.MINUTES.toNanos(4)
            while (System.nanoTime() < deadline && !isStopped) {
                if (MainActivity.isAppVisible ||
                    !BackgroundRefreshSchedule.isCurrent(runRevision)) break
                if (finished.await(1, TimeUnit.SECONDS)) break
            }
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        } catch (_: Exception) {
            // A periodic task will try again on a later scheduled interval.
        } finally {
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
