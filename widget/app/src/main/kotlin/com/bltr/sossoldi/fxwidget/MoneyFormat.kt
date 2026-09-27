package com.bltr.sossoldi.fxwidget

import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode
import java.text.DateFormat
import java.text.DecimalFormatSymbols
import java.text.NumberFormat
import java.util.Calendar
import java.util.Date

private fun number(fraction: Int): NumberFormat =
    NumberFormat.getNumberInstance().apply {
        minimumFractionDigits = fraction
        maximumFractionDigits = fraction
        roundingMode = RoundingMode.HALF_UP
    }

internal fun formatAmount(amount: BigDecimal, code: String): String =
    Currencies.prefix(code) + number(Currencies.fractionDigits(code)).format(amount)

/** Formats a partially typed amount without dropping a trailing separator or zeros. */
internal fun formatTyped(raw: String, code: String): String {
    val whole = raw.substringBefore('.').toLongOrNull() ?: 0L
    val grouped = NumberFormat.getIntegerInstance().format(whole)
    if (!raw.contains('.')) return Currencies.prefix(code) + grouped
    val fraction = raw.substringAfter('.').take(Currencies.fractionDigits(code))
    return Currencies.prefix(code) + grouped + DecimalFormatSymbols.getInstance().decimalSeparator + fraction
}

/** Two decimals for normal rates, four significant digits for tiny ones like 1 KRW in EUR. */
internal fun formatRate(rate: BigDecimal, code: String): String {
    if (rate >= BigDecimal.ONE) return Currencies.prefix(code) + number(2).format(rate)
    val rounded = rate.round(MathContext(4, RoundingMode.HALF_UP)).stripTrailingZeros()
    return Currencies.prefix(code) + number(rounded.scale().coerceAtLeast(2)).format(rounded)
}

internal fun formatStamp(epochMs: Long): String {
    val now = Calendar.getInstance()
    val then = Calendar.getInstance().apply { timeInMillis = epochMs }
    val time = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(epochMs))
    val sameDay = now.get(Calendar.YEAR) == then.get(Calendar.YEAR) &&
        now.get(Calendar.DAY_OF_YEAR) == then.get(Calendar.DAY_OF_YEAR)
    if (sameDay) return time
    val day = DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(epochMs))
    return "$day, $time"
}
