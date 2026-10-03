import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/database/repositories/transactions_repository.dart';

part 'dashboard_provider.g.dart';

@Riverpod(keepAlive: true)
class DashboardMonth extends _$DashboardMonth {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previous() => state = DateTime(state.year, state.month - 1);

  void next() {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    final candidate = DateTime(state.year, state.month + 1);
    if (candidate.isAfter(current)) return;
    state = candidate;
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.income,
    required this.expense,
    required this.currentMonth,
    required this.previousMonth,
  });

  final num income;
  final num expense;
  final List<FlSpot> currentMonth;
  final List<FlSpot> previousMonth;

  num get balance => income - expense;
  bool get hasCashFlow => currentMonth.isNotEmpty || previousMonth.isNotEmpty;
}

@Riverpod(keepAlive: true)
Future<DashboardSnapshot> dashboard(Ref ref) async {
  final repository = ref.read(transactionsRepositoryProvider);
  final month = ref.watch(dashboardMonthProvider);
  final results = await Future.wait([
    repository.currentMonthDailyTransactions(month: month),
    repository.lastMonthDailyTransactions(month: month),
  ]);
  final currentMonth = results[0];
  final previousMonth = results[1];

  final income = currentMonth.fold<num>(
    0,
    (total, row) => total + _number(row['income']),
  );
  final expense = currentMonth.fold<num>(
    0,
    (total, row) => total + _number(row['expense']),
  );

  final now = DateTime.now();
  final isCurrentMonth = month.year == now.year && month.month == now.month;
  final previous = DateTime(month.year, month.month - 1);

  return DashboardSnapshot(
    income: income,
    expense: expense,
    // The selected month runs up to today when it is the current month, and
    // to its last day otherwise; the previous month is always complete.
    currentMonth: _toCumulativeSpots(
      currentMonth,
      lastDay: isCurrentMonth
          ? now.day
          : DateUtils.getDaysInMonth(month.year, month.month),
    ),
    previousMonth: _toCumulativeSpots(
      previousMonth,
      lastDay: DateUtils.getDaysInMonth(previous.year, previous.month),
    ),
  );
}

num _number(Object? value) =>
    value is num ? value : num.tryParse('$value') ?? 0;

/// Running income minus expenses for every day from the 1st to [lastDay].
///
/// Days without transactions keep the previous total, and the line starts
/// from zero: before, days ahead of the first transaction took that day's
/// total, and the line stopped at the last transaction instead of today or
/// the month's end.
List<FlSpot> _toCumulativeSpots(List<dynamic> source, {required int lastDay}) {
  if (source.isEmpty) return const [];
  final netByDay = <int, num>{};
  for (final raw in source) {
    final row = Map<String, Object?>.from(raw as Map);
    final day = DateTime.tryParse('${row['day']}')?.day;
    if (day == null) continue;
    netByDay[day] =
        (netByDay[day] ?? 0) + _number(row['income']) - _number(row['expense']);
  }
  if (netByDay.isEmpty) return const [];

  // Future-dated transactions in the current month still show up.
  final end = [lastDay, ...netByDay.keys].reduce((a, b) => a > b ? a : b);
  num runningTotal = 0;
  return [
    for (var day = 1; day <= end; day++)
      FlSpot(
        day - 1.0,
        double.parse(
          (runningTotal += netByDay[day] ?? 0).toStringAsFixed(2),
        ),
      ),
  ];
}
