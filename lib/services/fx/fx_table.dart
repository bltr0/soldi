import '../database/repositories/exchange_rate_repository.dart';

/// Looks up exchange rates for a given day.
///
/// Rates come from two places: the daily rates fetched when the user allowed
/// it, and the rates implied by the user's own cross-currency transfers.
/// Fetched rates win for a pair; transfer-derived ones are the offline
/// fallback. A day without a published rate (weekends, holidays) uses the
/// nearest earlier one.
class FxTable {
  FxTable({
    required this.mainCode,
    List<StoredRate> stored = const [],
    List<TransferRate> transfers = const [],
    this.strict = false,
  }) {
    final fetched = <String, List<_Point>>{};
    for (final rate in stored) {
      final day = _dayKey(DateTime.tryParse(rate.date));
      if (day == null) continue;
      (fetched['${rate.base}>${rate.quote}'] ??= []).add(
        _Point(day, rate.rate),
      );
    }
    final derived = <String, List<_Point>>{};
    for (final transfer in transfers) {
      final from = transfer.from ?? mainCode;
      final to = transfer.to ?? mainCode;
      if (from == to) continue;
      (derived['$from>$to'] ??= []).add(
        _Point(_dayKey(transfer.date)!, transfer.received / transfer.amount),
      );
    }
    for (final series in [...fetched.values, ...derived.values]) {
      series.sort((a, b) => a.day.compareTo(b.day));
    }
    _fetched = fetched;
    _derived = derived;
  }

  /// ISO code of the app's main currency.
  final String mainCode;

  /// Only a rate published on the day, or the last one before it within a
  /// week (weekends, holidays); never a later day's rate.
  final bool strict;

  late final Map<String, List<_Point>> _fetched;
  late final Map<String, List<_Point>> _derived;

  /// Whether any rate is known for converting [from] into [to].
  bool canConvert(String from, String to) => rate(from, to, DateTime.now()) != null;

  /// 1 [from] in [to] on [date], or null when no rate is known.
  double? rate(String from, String to, DateTime date) {
    if (from == to) return 1;
    final day = _dayKey(date)!;
    final direct = _lookup('$from>$to', day);
    if (direct != null) return direct;
    final inverse = _lookup('$to>$from', day);
    return inverse == null || inverse == 0 ? null : 1 / inverse;
  }

  /// [amount] held in [from], worth in [to] on [date]; null without a rate.
  num? convert(num amount, String from, String to, DateTime date) {
    final r = rate(from, to, date);
    return r == null ? null : amount * r;
  }

  /// Converts to the main currency; amounts without a known rate come back
  /// unchanged so totals never drop money (see [hasRate] to flag them).
  num toMain(num amount, String? from, DateTime date) =>
      convert(amount, from ?? mainCode, mainCode, date) ?? amount;

  bool hasRate(String? from, DateTime date) =>
      rate(from ?? mainCode, mainCode, date) != null;

  double? _lookup(String pair, int day) {
    final series = _fetched[pair] ?? _derived[pair];
    if (series == null || series.isEmpty) return null;
    // Latest point on or before [day]; before the first point, the first.
    var low = 0, high = series.length - 1, found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (series[mid].day <= day) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (found < 0) return strict ? null : series.first.rate;
    if (strict && _daysBetween(series[found].day, day) > 7) return null;
    return series[found].rate;
  }

  static int _daysBetween(int from, int to) => DateTime(
    to ~/ 10000,
    to ~/ 100 % 100,
    to % 100,
  ).difference(DateTime(from ~/ 10000, from ~/ 100 % 100, from % 100)).inDays;

  static int? _dayKey(DateTime? date) =>
      date == null ? null : date.year * 10000 + date.month * 100 + date.day;
}

class _Point {
  const _Point(this.day, this.rate);

  final int day;
  final double rate;
}
