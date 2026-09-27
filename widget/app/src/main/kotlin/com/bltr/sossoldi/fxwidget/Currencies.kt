package com.bltr.sossoldi.fxwidget

import java.util.Currency
import java.util.Locale

internal object Currencies {
    /** Everything the ECB reference feed publishes, used until the first fetch lands. */
    private val ecb = listOf(
        "AUD", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD",
        "HUF", "IDR", "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR", "NOK",
        "NZD", "PHP", "PLN", "RON", "SEK", "SGD", "THB", "TRY", "USD", "ZAR",
    )

    fun available(): List<String> = ecb.sorted()

    /** Symbol followed by a space when it is just letters, e.g. "CHF 12" but "₩12". */
    fun prefix(code: String): String {
        val symbol = runCatching { Currency.getInstance(code).getSymbol(Locale.US) }.getOrDefault(code)
        return if (symbol.all { it.isLetter() }) "$symbol " else symbol
    }

    fun fractionDigits(code: String): Int =
        runCatching { Currency.getInstance(code).defaultFractionDigits }.getOrDefault(2).coerceIn(0, 2)

    fun name(code: String): String =
        runCatching { Currency.getInstance(code).getDisplayName(Locale.getDefault()) }.getOrDefault(code)
}
