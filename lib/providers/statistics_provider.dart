import 'package:fl_chart/fl_chart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/database/repositories/transactions_repository.dart';
import 'accounts_provider.dart';

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
    final changes = await ref
        .read(transactionsRepositoryProvider)
        .monthlyNetWorthChange(
          from: DateTime(now.year, 1, 1),
          to: DateTime(now.year, now.month + 1, 1),
        );
    final changeByMonth = <int, double>{
      for (final row in changes)
        int.parse('${row['month']}'.substring(5)) - 1:
            (row['change'] as num? ?? 0).toDouble(),
    };

    final accounts = await ref.read(accountsProvider.future);
    final currentBalance = accounts
        .where((account) => account.countNetWorth && account.deletedAt == null)
        .fold(0.0, (sum, account) => sum + (account.total ?? 0));

    // Walk back from today's net worth: the end of each earlier month is the
    // end of the next one minus what changed during it. Every month up to
    // the current one gets a point, including months without transactions.
    final spots = <FlSpot>[];
    var runningBalance = currentBalance;
    for (var month = now.month - 1; month >= 0; month--) {
      spots.add(
        FlSpot(month.toDouble(), double.parse(runningBalance.toStringAsFixed(2))),
      );
      runningBalance -= changeByMonth[month] ?? 0;
    }

    spots.sort((a, b) => a.x.compareTo(b.x));

    ref.read(currentYearMontlyTransactionsProvider.notifier).setValue(spots);
  }
}
