package com.bltr.sossoldi.fxwidget

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONObject
import java.math.BigDecimal
import java.math.MathContext
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import kotlin.coroutines.cancellation.CancellationException

internal object RateRepository {
    private const val PREFS = "krw_eur_widget"
    private const val KEY_HOURS = "refresh_hours"
    private const val KEY_MANUAL = "manual_refresh_at"
    private const val TAG = "FxWidget"
    private const val HOST = "https://api.bltr.fr/fx?"
    private const val MANUAL_GAP_MS = 60L * 60 * 1000

    val refreshChoices = listOf(1, 3, 6, 12, 24)
    private const val DEFAULT_HOURS = 6

    data class Outcome(val updated: Boolean, val retry: Boolean, val message: String?)

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun refreshHours(context: Context): Int =
        prefs(context).getInt(KEY_HOURS, DEFAULT_HOURS).takeIf { it in refreshChoices } ?: DEFAULT_HOURS

    fun setRefreshHours(context: Context, hours: Int) {
        prefs(context).edit().putInt(KEY_HOURS, hours).commit()
    }

    fun refreshIntervalMs(context: Context): Long = refreshHours(context) * 60L * 60 * 1000

    /** Milliseconds until Refresh now is allowed again, or 0 when it is. */
    fun manualWaitMs(context: Context): Long {
        val last = prefs(context).getLong(KEY_MANUAL, 0L)
        return (MANUAL_GAP_MS - (System.currentTimeMillis() - last)).coerceAtLeast(0L)
    }

    fun markManualRefresh(context: Context) {
        prefs(context).edit().putLong(KEY_MANUAL, System.currentTimeMillis()).commit()
    }

    /** Units of [to] for 1 unit of [from]. Uses the inverse quote when that is what was stored. */
    fun rate(context: Context, from: String, to: String): BigDecimal? {
        if (from.equals(to, ignoreCase = true)) return BigDecimal.ONE
        stored(context, from, to)?.let { return it }
        val inverse = stored(context, to, from) ?: return null
        return BigDecimal.ONE.divide(inverse, MathContext.DECIMAL64)
    }

    fun fetchedAt(context: Context, from: String, to: String): Long? {
        val direct = quotedAt(context, from, to)
        val inverse = quotedAt(context, to, from)
        return listOfNotNull(direct, inverse).maxOrNull()
    }

    /** [from] is the base of the quote that is shown: how many [to] equal 1 [from]. */
    fun isPairStale(context: Context, from: String, to: String): Boolean {
        val at = quotedAt(context, from, to) ?: return true
        return System.currentTimeMillis() - at >= refreshIntervalMs(context)
    }

    /**
     * [pairs] are (typed currency, received currency). The quote fetched is the one on the
     * widget: how many of the typed currency equal 1 of the received currency.
     * [force] ignores the interval, including when only the order changed.
     */
    fun refreshNeeded(context: Context, pairs: List<Pair<String, String>>, force: Boolean): Outcome {
        var updated = false
        var retry = false
        var message: String? = null
        val seen = HashSet<String>()
        for ((typed, received) in pairs) {
            if (typed.equals(received, ignoreCase = true)) continue
            val key = "${received.lowercase()}.${typed.lowercase()}"
            if (!seen.add(key)) continue
            if (!force && !isPairStale(context, received, typed)) continue
            when (val result = fetchPair(context, received, typed)) {
                is Fetch.Ok -> updated = true
                is Fetch.Retry -> {
                    retry = true
                    message = result.message
                }
                is Fetch.GiveUp -> message = result.message
            }
        }
        return Outcome(updated, retry, message)
    }

    private fun stored(context: Context, from: String, to: String): BigDecimal? =
        prefs(context).getString(rateKey(from, to), null)?.toBigDecimalOrNull()?.takeIf { it.signum() > 0 }

    private fun quotedAt(context: Context, from: String, to: String): Long? =
        prefs(context).getLong(timeKey(from, to), 0L).takeIf { it > 0L }

    private fun rateKey(from: String, to: String) = "q_${from.lowercase()}.${to.lowercase()}"
    private fun timeKey(from: String, to: String) = "t_${from.lowercase()}.${to.lowercase()}"

    private sealed class Fetch {
        data object Ok : Fetch()
        data class Retry(val message: String) : Fetch()
        data class GiveUp(val message: String) : Fetch()
    }

    private fun fetchPair(context: Context, base: String, quote: String): Fetch {
        val pair = "${base.lowercase()}.${quote.lowercase()}"
        return try {
            val (code, body) = get(HOST + pair)
            val json = runCatching { JSONObject(body) }.getOrNull()
            val message = json?.optString("message").orEmpty()
            when (code) {
                in 200..299 -> {
                    val rate = json?.optString("rate")?.toBigDecimalOrNull()
                    if (rate == null || rate.signum() <= 0) return Fetch.Retry("missing rate")
                    val at = json.optString("date").let { raw ->
                        runCatching { Instant.parse(raw).toEpochMilli() }.getOrDefault(System.currentTimeMillis())
                    }
                    prefs(context).edit()
                        .putString(rateKey(base, quote), rate.toPlainString())
                        .putLong(timeKey(base, quote), at)
                        .commit()
                    Fetch.Ok
                }
                404, 400 -> Fetch.GiveUp(message.ifBlank { "No rate for $pair" })
                else -> Fetch.Retry(message.ifBlank { "HTTP $code" })
            }
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            Log.w(TAG, "fetch $pair failed", error)
            Fetch.Retry(error.message ?: "network")
        }
    }

    private fun get(url: String): Pair<Int, String> {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 12_000
            readTimeout = 12_000
            requestMethod = "GET"
            instanceFollowRedirects = false
            setRequestProperty("Accept", "application/json")
            setRequestProperty("User-Agent", "SossoldiFxWidget/1.6")
        }
        try {
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
            return code to body
        } finally {
            connection.disconnect()
        }
    }
}
