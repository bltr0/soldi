package com.bltr.sossoldi.fxwidget

import android.content.Context
import android.content.SharedPreferences
import java.math.BigDecimal

internal enum class Mode { RATE, INPUT, RESULT }

internal object WidgetStore {
    private const val PREFS = "krw_eur_widget_state"

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun modeKey(widgetId: Int) = "mode_$widgetId"
    private fun digitsKey(widgetId: Int) = "digits_$widgetId"
    private fun amountKey(widgetId: Int) = "value_$widgetId"
    private fun legacyAmountKey(widgetId: Int) = "amount_$widgetId"
    private fun inKey(widgetId: Int) = "in_$widgetId"
    private fun outKey(widgetId: Int) = "out_$widgetId"
    private const val DEFAULT_IN = "default_in"
    private const val DEFAULT_OUT = "default_out"

    fun defaultIn(context: Context): String = prefs(context).getString(DEFAULT_IN, null) ?: "KRW"
    fun defaultOut(context: Context): String = prefs(context).getString(DEFAULT_OUT, null) ?: "EUR"

    fun inCode(context: Context, widgetId: Int): String =
        prefs(context).getString(inKey(widgetId), null) ?: defaultIn(context)

    fun outCode(context: Context, widgetId: Int): String =
        prefs(context).getString(outKey(widgetId), null) ?: defaultOut(context)

    fun setDefaults(context: Context, from: String, to: String) {
        prefs(context).edit().putString(DEFAULT_IN, from).putString(DEFAULT_OUT, to).commit()
    }

    /** Changing currencies drops any half-typed amount or old result for that widget. */
    fun setPair(context: Context, widgetId: Int, from: String, to: String) {
        prefs(context).edit()
            .putString(inKey(widgetId), from)
            .putString(outKey(widgetId), to)
            .putInt(modeKey(widgetId), Mode.RATE.ordinal)
            .putString(digitsKey(widgetId), "")
            .commit()
    }

    fun mode(context: Context, widgetId: Int): Mode =
        Mode.entries.getOrElse(prefs(context).getInt(modeKey(widgetId), 0)) { Mode.RATE }

    fun digits(context: Context, widgetId: Int): String =
        prefs(context).getString(digitsKey(widgetId), null).orEmpty()

    fun amount(context: Context, widgetId: Int): BigDecimal {
        val prefs = prefs(context)
        prefs.getString(amountKey(widgetId), null)?.toBigDecimalOrNull()?.let { return it }
        return BigDecimal.valueOf(prefs.getLong(legacyAmountKey(widgetId), 0L))
    }

    fun startInput(context: Context, widgetId: Int) {
        prefs(context).edit()
            .putInt(modeKey(widgetId), Mode.INPUT.ordinal)
            .putString(digitsKey(widgetId), "")
            .commit()
    }

    fun setDigits(context: Context, widgetId: Int, digits: String) {
        prefs(context).edit().putString(digitsKey(widgetId), digits).commit()
    }

    fun showResult(context: Context, widgetId: Int, amount: BigDecimal) {
        prefs(context).edit()
            .putString(amountKey(widgetId), amount.toPlainString())
            .putInt(modeKey(widgetId), Mode.RESULT.ordinal)
            .commit()
    }

    fun showRate(context: Context, widgetId: Int) {
        prefs(context).edit().putInt(modeKey(widgetId), Mode.RATE.ordinal).commit()
    }

    fun clear(context: Context, widgetIds: IntArray) {
        val editor = prefs(context).edit()
        widgetIds.forEach {
            editor.remove(modeKey(it)).remove(digitsKey(it)).remove(amountKey(it))
                .remove(legacyAmountKey(it)).remove(inKey(it)).remove(outKey(it))
        }
        editor.apply()
    }

    fun listen(context: Context, listener: SharedPreferences.OnSharedPreferenceChangeListener) =
        prefs(context).registerOnSharedPreferenceChangeListener(listener)

    fun unlisten(context: Context, listener: SharedPreferences.OnSharedPreferenceChangeListener) =
        prefs(context).unregisterOnSharedPreferenceChangeListener(listener)
}
