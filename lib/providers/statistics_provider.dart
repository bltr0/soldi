import 'package:fl_chart/fl_chart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/database/repositories/transactions_repository.dart';
import 'accounts_provider.dart';
import 'fx_provider.dart';

part 'statistics_provider.g.dart';

@Riverpod(keepAlive: true)
class MyCosts extends _$MyCosts {
  @override
  bool build() => false;

  void setValue(bool value) => state = value;
}

@Riverpod(keepAlive: true)
class HighlightedMonth extends _$HighlightedMonth {
  @override
  int build() => DateTime.now().month - 1;

  void setValue(int value) => state = value;
}

@Riverpod(keepAlive: true)
class CurrentYearMontlyTransactions extends _$CurrentYearMontlyTransactions {
  @override
  List<FlSpot> build() => const [];

  void setValue(List<FlSpot> value) => state = value;
}

@Riverpod(keepAlive: true)
class Statistics extends _$Statistics {
  @override
  Future<void> build() async {
    await updateStatistics();
  }

  Future<void> updateStatistics() async {
    final now = DateTime.now();
    final fx = await ref.watch(fxTableProvider.future);
    final main = fx.mainCode;
    final changes = await ref
        .read(transactionsRepositoryProvider)
        .monthlyNetWorthChange(
          from: DateTime(now.year, 1, 1),
          to: DateTime(now.year, now.month + 1, 1),
        );
    // Change per month, kept in each account currency and converted at the
    // rate of the month's end.
    final changeByMonth = <int, Map<String, double>>{};
    for (final row in changes) {
      final month = int.parse('${row['month']}'.substring(5)) - 1;
      final code = (row['currency'] as String?) ?? main;
      final perCurrency = changeByMonth.putIfAbsent(month, () => {});
      perCurrency[code] =
          (perCurrency[code] ?? 0) + (row['change'] as num? ?? 0).toDouble();
    }

    final accounts = await ref.read(accountsProvider.future);
    final balances = <String, double>{};
    for (final account in accounts.where(
      (account) => account.countNetWorth && account.deletedAt == null,
    )) {
      final code = account.currency ?? main;
      balances[code] = (balances[code] ?? 0) + (account.total ?? 0);
    }

    // Walk back from today's net worth: the end of each earlier month is the
    // end of the next one minus what changed during it. Every month up to
    // the current one gets a point, including months without transactions.
    final spots = <FlSpot>[];
    for (var month = now.month - 1; month >= 0; month--) {
      final endOfMonth = month == now.month - 1
          ? now
          : DateTime(now.year, month + 2, 0);
      var worth = 0.0;
      for (final entry in balances.entries) {
        worth += fx.toMain(entry.value, entry.key, endOfMonth);
      }
      spots.add(FlSpot(month.toDouble(), double.parse(worth.toStringAsFixed(2))));
      for (final entry in (changeByMonth[month] ?? const <String, double>{}).entries) {
        balances[entry.key] = (balances[entry.key] ?? 0) - entry.value;
      }
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    ref.read(currentYearMontlyTransactionsProvider.notifier).setValue(spots);
  }
}
