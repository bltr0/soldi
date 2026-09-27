package com.bltr.sossoldi.fxwidget

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class RateWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val app = applicationContext
        val outcome = RateRepository.refreshNeeded(app, RateRefresh.pairs(app), force = false)
        if (outcome.updated) WidgetRenderer.refreshAll(app)
        return if (outcome.retry) Result.retry() else Result.success()
    }
}

internal object RateRefresh {
    private const val PERIODIC = "krw_eur_periodic"
    private const val ONCE = "krw_eur_once"
    private val busy = AtomicBoolean(false)

    fun ensureScheduled(context: Context) {
        val intervalMinutes = RateRepository.refreshHours(context) * 60L
        val flexMinutes = (intervalMinutes / 4).coerceAtLeast(15)
        val request = PeriodicWorkRequestBuilder<RateWorker>(
            intervalMinutes,
            TimeUnit.MINUTES,
            flexMinutes,
            TimeUnit.MINUTES,
        )
            .setConstraints(constraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            PERIODIC,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }

    /** Runs on a background thread; [done] is called there with whether a new rate landed. */
    fun fetchNowIfStale(context: Context, force: Boolean = false, done: (Boolean) -> Unit = {}) {
        val app = context.applicationContext
        val wanted = pairs(app)
        if (!force && wanted.none { (typed, received) -> RateRepository.isPairStale(app, received, typed) }) {
            done(false)
            return
        }
        if (!busy.compareAndSet(false, true)) {
            done(false)
            return
        }
        thread(name = "fx-refresh", isDaemon = true) {
            var fetched = false
            try {
                val outcome = RateRepository.refreshNeeded(app, wanted, force)
                fetched = outcome.updated
                if (fetched) WidgetRenderer.refreshAll(app)
                if (outcome.retry) enqueueCatchUp(app)
            } finally {
                busy.set(false)
                done(fetched)
            }
        }
    }

    fun pairs(context: Context): List<Pair<String, String>> {
        val ids = WidgetRenderer.widgetIds(context)
        if (ids.isEmpty()) {
            return listOf(WidgetStore.defaultIn(context) to WidgetStore.defaultOut(context))
        }
        return ids.map { WidgetStore.inCode(context, it) to WidgetStore.outCode(context, it) }
    }

    private fun enqueueCatchUp(context: Context) {
        val request = OneTimeWorkRequestBuilder<RateWorker>()
            .setConstraints(
                Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build(),
            )
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(ONCE, ExistingWorkPolicy.KEEP, request)
    }

    fun cancel(context: Context) {
        val manager = WorkManager.getInstance(context)
        manager.cancelUniqueWork(PERIODIC)
        manager.cancelUniqueWork(ONCE)
    }

    private fun constraints() = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .setRequiresBatteryNotLow(true)
        .build()
}
