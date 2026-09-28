package com.bltr.sossoldi.fxwidget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.widget.RemoteViews

class KrwEurWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        widgetIds.forEach { WidgetRenderer.show(context, it) }
        RateRefresh.ensureScheduled(context)
        val pending = goAsync()
        RateRefresh.fetchNowIfStale(context) { pending.finish() }
    }

    override fun onEnabled(context: Context) {
        RateRefresh.ensureScheduled(context)
        val pending = goAsync()
        RateRefresh.fetchNowIfStale(context) { pending.finish() }
    }

    override fun onDisabled(context: Context) {
        RateRefresh.cancel(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        newOptions: Bundle,
    ) {
        WidgetRenderer.refresh(context, widgetId)
    }

    override fun onDeleted(context: Context, widgetIds: IntArray) {
        WidgetStore.clear(context, widgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return
        when (intent.action) {
            ACTION_CONFIRM -> WidgetFlow.commit(context, widgetId)
            ACTION_RESET -> {
                WidgetFlow.reset(context, widgetId)
                val pending = goAsync()
                RateRefresh.fetchNowIfStale(context) { pending.finish() }
            }
        }
    }

    companion object {
        const val ACTION_CONFIRM = "com.bltr.sossoldi.fxwidget.CONFIRM"
        const val ACTION_RESET = "com.bltr.sossoldi.fxwidget.RESET"
    }
}

internal object WidgetFlow {
    fun begin(context: Context, widgetId: Int) {
        if (WidgetStore.mode(context, widgetId) != Mode.INPUT) {
            WidgetStore.startInput(context, widgetId)
        }
        WidgetRenderer.show(context, widgetId)
    }

    fun type(context: Context, widgetId: Int, digits: String) {
        if (WidgetStore.mode(context, widgetId) != Mode.INPUT) return
        WidgetStore.setDigits(context, widgetId, digits)
        WidgetRenderer.showDigits(context, widgetId)
    }

    fun commit(context: Context, widgetId: Int) {
        if (WidgetStore.mode(context, widgetId) != Mode.INPUT) return
        val amount = WidgetStore.digits(context, widgetId).toBigDecimalOrNull()?.takeIf { it.signum() > 0 }
        if (amount == null) {
            WidgetStore.showRate(context, widgetId)
        } else {
            WidgetStore.showResult(context, widgetId, amount)
        }
        WidgetRenderer.show(context, widgetId)
    }

    fun reset(context: Context, widgetId: Int) {
        if (WidgetStore.mode(context, widgetId) == Mode.RATE) return
        WidgetStore.showRate(context, widgetId)
        WidgetRenderer.show(context, widgetId)
    }
}

internal object WidgetRenderer {
    /** Full update: the ViewFlipper animates when the displayed state changes. */
    fun show(context: Context, widgetId: Int) {
        AppWidgetManager.getInstance(context)
            .updateAppWidget(widgetId, build(context, widgetId, withMode = true))
    }

    /** Text-only update. Replaces the remote views without setDisplayedChild, so the
     *  flipper does not replay its transition on a rate refresh or a new digit. */
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        widgetIds(context).forEach { manager.updateAppWidget(it, build(context, it, withMode = false)) }
    }

    fun widgetIds(context: Context): IntArray =
        AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, KrwEurWidgetReceiver::class.java))

    fun refresh(context: Context, widgetId: Int) {
        AppWidgetManager.getInstance(context)
            .updateAppWidget(widgetId, build(context, widgetId, withMode = false))
    }

    fun showDigits(context: Context, widgetId: Int) {
        AppWidgetManager.getInstance(context)
            .updateAppWidget(widgetId, build(context, widgetId, withMode = false))
    }

    private fun build(context: Context, widgetId: Int, withMode: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_fx)
        val from = WidgetStore.inCode(context, widgetId)
        val to = WidgetStore.outCode(context, widgetId)
        val perOut = RateRepository.rate(context, to, from)
        val rateText = perOut?.let { formatRate(it, from) }

        views.setTextViewText(R.id.rate_value, rateText ?: "—")

        views.setTextViewText(R.id.input_label, from)
        bindDigits(context, views, WidgetStore.digits(context, widgetId), from)

        val amount = WidgetStore.amount(context, widgetId)
        views.setTextViewText(R.id.result_label, formatAmount(amount, from))
        views.setTextViewText(
            R.id.result_value,
            RateRepository.rate(context, from, to)?.let { formatAmount(amount.multiply(it), to) } ?: "—",
        )
        views.setTextViewText(
            R.id.result_footer,
            rateText?.let { "${Currencies.prefix(to)}1 = $it" }
                ?: context.getString(R.string.rate_unavailable),
        )

        views.setOnClickPendingIntent(R.id.state_rate, inputIntent(context, widgetId))
        views.setOnClickPendingIntent(
            R.id.state_input,
            broadcast(context, widgetId, KrwEurWidgetReceiver.ACTION_CONFIRM, slot = 1),
        )
        views.setOnClickPendingIntent(
            R.id.state_result,
            broadcast(context, widgetId, KrwEurWidgetReceiver.ACTION_RESET, slot = 2),
        )

        if (withMode) {
            views.setDisplayedChild(R.id.flipper, WidgetStore.mode(context, widgetId).ordinal)
        }
        fitPill(context, views, widgetId)
        return views
    }

    /** Weather 2×1 on this phone reports 141.71428×65.52381 dp. */
    private fun fitPill(context: Context, views: RemoteViews, widgetId: Int) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        views.setViewLayoutWidth(R.id.pill, WEATHER_WIDTH_DP, TypedValue.COMPLEX_UNIT_DIP)
        views.setViewLayoutHeight(R.id.pill, WEATHER_HEIGHT_DP, TypedValue.COMPLEX_UNIT_DIP)
    }

    private const val WEATHER_WIDTH_DP = 141.71428f
    private const val WEATHER_HEIGHT_DP = 65.52381f

    private fun bindDigits(context: Context, views: RemoteViews, digits: String, code: String) {
        views.setTextViewText(R.id.input_value, formatTyped(digits, code))
        views.setTextColor(
            R.id.input_value,
            context.getColor(if (digits.isEmpty()) R.color.fx_placeholder else R.color.fx_krw),
        )
    }

    private fun inputIntent(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, InputActivity::class.java)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION)
        return PendingIntent.getActivity(
            context,
            widgetId * 3,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun broadcast(context: Context, widgetId: Int, action: String, slot: Int): PendingIntent {
        val intent = Intent(context, KrwEurWidgetReceiver::class.java)
            .setAction(action)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        return PendingIntent.getBroadcast(
            context,
            widgetId * 3 + slot,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }
}
