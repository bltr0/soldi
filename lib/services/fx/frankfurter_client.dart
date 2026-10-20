import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_log.dart';
import '../database/repositories/exchange_rate_repository.dart';

/// Minimal client for the Frankfurter API (https://frankfurter.dev):
/// daily reference rates, no key needed. Only used when the user allows it.
class FrankfurterClient {
  FrankfurterClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _host = 'api.frankfurter.dev';

  /// Longest window asked in one request; longer ones come back thinned out.
  static const _windowDays = 90;

  /// Daily rates of 1 [base] in [quote] between [from] and [to], inclusive.
  /// Returns an empty list when the pair is unsupported or unreachable.
  Future<List<StoredRate>> series({
    required String base,
    required String quote,
    required DateTime from,
    required DateTime to,
  }) async {
    final rates = <StoredRate>[];
    var start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!start.isAfter(end)) {
      var stop = start.add(const Duration(days: _windowDays));
      if (stop.isAfter(end)) stop = end;
      final chunk = await _window(base, quote, start, stop);
      if (chunk == null) return rates;
      rates.addAll(chunk);
      start = stop.add(const Duration(days: 1));
    }
    return rates;
  }

  Future<List<StoredRate>?> _window(
    String base,
    String quote,
    DateTime from,
    DateTime to,
  ) async {
    // Asked the other way round and inverted: Frankfurter rounds to five
    // decimals, so 1 KRW in EUR comes back as 0.00067 (0.3% off) while
    // 1 EUR in KRW keeps all its digits.
    final uri = Uri.https(_host, '/v1/${_ymd(from)}..${_ymd(to)}', {
      'base': quote,
      'symbols': base,
    });
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        AppLog.warn(
          'fx',
          'GET $uri -> HTTP ${response.statusCode}: '
              '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
        );
        return null;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = body['rates'] as Map<String, dynamic>? ?? const {};
      final out = <StoredRate>[];
      // Time series: {"2024-01-02": {"EUR": 0.1}}. A single day comes back
      // flat: {"date": "...", "rates": {"EUR": 0.1}}.
      if (body['date'] is String && rates[base] is num) {
        final inverse = (rates[base] as num).toDouble();
        if (inverse != 0) {
          out.add(StoredRate(body['date'] as String, base, quote, 1 / inverse));
        }
        return out;
      }
      for (final entry in rates.entries) {
        final day = entry.value;
        if (day is Map && day[base] is num && day[base] != 0) {
          out.add(
            StoredRate(
              entry.key,
              base,
              quote,
              1 / (day[base] as num).toDouble(),
            ),
          );
        }
      }
      AppLog.info('fx', 'GET $uri -> ${out.length} rates');
      return out;
    } catch (e, stack) {
      AppLog.error('fx', 'GET $uri failed: $e', stack);
      return null;
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
