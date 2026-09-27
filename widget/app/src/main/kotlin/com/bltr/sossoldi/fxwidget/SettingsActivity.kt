package com.bltr.sossoldi.fxwidget

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.View
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import java.math.BigDecimal

/**
 * Launched from the app icon it edits every widget (and the pair new ones start with);
 * launched from a widget's "Settings" it edits only that widget.
 */
class SettingsActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val configuring get() = widgetId != AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var from: String
    private lateinit var to: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (configuring) {
            setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
            from = WidgetStore.inCode(this, widgetId)
            to = WidgetStore.outCode(this, widgetId)
        } else {
            from = WidgetStore.defaultIn(this)
            to = WidgetStore.defaultOut(this)
        }
        setContentView(R.layout.settings)

        findViewById<TextView>(R.id.scope).setText(
            if (configuring) R.string.scope_one else R.string.scope_all,
        )
        findViewById<View>(R.id.row_in).setOnClickListener { pickCurrency(input = true) }
        findViewById<View>(R.id.row_out).setOnClickListener { pickCurrency(input = false) }
        findViewById<View>(R.id.swap).setOnClickListener { applyPair(to, from) }
        findViewById<View>(R.id.row_refresh).setOnClickListener { pickInterval() }
        findViewById<View>(R.id.refresh_now).setOnClickListener { refreshNow() }
        findViewById<View>(R.id.row_battery).setOnClickListener { askBatteryExemption() }
        findViewById<Button>(R.id.primary).apply {
            setText(if (configuring) R.string.done else R.string.add_to_home)
            setOnClickListener { if (configuring) finish() else pinWidget() }
        }

        RateRefresh.ensureScheduled(this)
        RateRefresh.fetchNowIfStale(this) { runOnUiThread { render() } }
    }

    override fun onResume() {
        super.onResume()
        render()
    }

    private fun render() {
        findViewById<TextView>(R.id.in_value).text = describe(from)
        findViewById<TextView>(R.id.out_value).text = describe(to)
        findViewById<TextView>(R.id.refresh_value).text = intervalLabel(RateRepository.refreshHours(this))

        val perOut = RateRepository.rate(this, to, from)
        findViewById<TextView>(R.id.status_rate).text = perOut
            ?.let { getString(R.string.status_rate, formatAmount(BigDecimal.ONE, to), formatRate(it, from)) }
            ?: getString(R.string.fetching_rate)
        val fetched = RateRepository.fetchedAt(this, to, from)
        findViewById<TextView>(R.id.status_time).text = fetched
            ?.let { getString(R.string.updated_at, formatStamp(it)) }
            ?: getString(R.string.status_never)

        val power = getSystemService(PowerManager::class.java)
        findViewById<View>(R.id.row_battery).visibility =
            if (power?.isIgnoringBatteryOptimizations(packageName) == true) View.GONE else View.VISIBLE
    }

    private fun describe(code: String) = "$code · ${Currencies.name(code)}"

    private fun intervalLabel(hours: Int): String =
        resources.getQuantityString(R.plurals.every_hours, hours, hours)

    private fun pickCurrency(input: Boolean) {
        val codes = Currencies.available()
        val current = if (input) from else to
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
            .setTitle(if (input) R.string.you_type else R.string.you_get)
            .setSingleChoiceItems(codes.map(::describe).toTypedArray(), codes.indexOf(current)) { dialog, which ->
                val picked = codes[which]
                if (input) applyPair(picked, to) else applyPair(from, picked)
                dialog.dismiss()
            }
            .show()
    }

    private fun applyPair(newFrom: String, newTo: String) {
        from = newFrom
        to = newTo
        if (configuring) {
            WidgetStore.setPair(this, widgetId, from, to)
        } else {
            WidgetStore.setDefaults(this, from, to)
            WidgetRenderer.widgetIds(this).forEach { WidgetStore.setPair(this, it, from, to) }
        }
        WidgetRenderer.widgetIds(this).forEach { WidgetRenderer.show(this, it) }
        render()
        findViewById<TextView>(R.id.status_time).setText(R.string.checking)
        RateRefresh.fetchNowIfStale(this, force = true) { runOnUiThread { render() } }
    }

    private fun pickInterval() {
        val choices = RateRepository.refreshChoices
        AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
            .setTitle(R.string.refresh_title)
            .setSingleChoiceItems(
                choices.map(::intervalLabel).toTypedArray(),
                choices.indexOf(RateRepository.refreshHours(this)),
            ) { dialog, which ->
                RateRepository.setRefreshHours(this, choices[which])
                RateRefresh.ensureScheduled(this)
                render()
                dialog.dismiss()
            }
            .show()
    }

    private fun refreshNow() {
        val wait = RateRepository.manualWaitMs(this)
        if (wait > 0L) {
            val minutes = ((wait + 59_999) / 60_000).toInt()
            Toast.makeText(this, resources.getQuantityString(R.plurals.refresh_wait, minutes, minutes), Toast.LENGTH_SHORT).show()
            return
        }
        RateRepository.markManualRefresh(this)
        findViewById<TextView>(R.id.status_time).setText(R.string.checking)
        RateRefresh.fetchNowIfStale(this, force = true) { fetched ->
            runOnUiThread {
                render()
                if (!fetched) Toast.makeText(this, R.string.refresh_failed, Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun askBatteryExemption() {
        val request = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            .setData(Uri.parse("package:$packageName"))
        val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        runCatching { startActivity(request) }.recoverCatching { startActivity(fallback) }
    }

    private fun pinWidget() {
        val manager = getSystemService(AppWidgetManager::class.java)
        val pinned = manager?.isRequestPinAppWidgetSupported == true &&
            manager.requestPinAppWidget(ComponentName(this, KrwEurWidgetReceiver::class.java), null, null)
        if (!pinned) Toast.makeText(this, R.string.place_hint, Toast.LENGTH_LONG).show()
    }
}
