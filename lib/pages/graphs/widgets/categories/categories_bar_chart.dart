import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../model/category_transaction.dart';
import '../../../../providers/categories_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../providers/statistics_provider.dart';
import '../../../../providers/transactions_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/extensions.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/blur_widget.dart';

/// Month-by-month totals of the selected type over the year. The selected
/// month is highlighted; tapping a bar selects that month for the whole card.
class CategoriesBarChart extends ConsumerWidget {
  const CategoriesBarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final highlightedMonth = ref.watch(highlightedMonthProvider);
    final monthlyTotals = ref.watch(monthlyTotalsProvider);
    final year = ref.watch(filterDateStartProvider).year;
    final currency = ref.watch(currencyStateProvider);
    final isIncome =
        ref.watch(categoryTypeProvider) == CategoryTransactionType.income;
    final barColor = isIncome ? visual.positive : visual.negative;
    final amountsVisible = ref.watch(visibilityAmountProvider);

    return monthlyTotals.when(
      skipLoadingOnReload: true,
      data: (totals) {
        final active = totals.where((t) => t > 0);
        final average = active.isEmpty
            ? 0.0
            : active.reduce((a, b) => a + b) / active.length;
        final maxValue = totals.fold<double>(0, (a, b) => a > b ? a : b);
        final step = maxValue == 0 ? 1.0 : _niceCeiling(maxValue * 1.05 / 4);
        final top = step * 4;
        final selected = totals[highlightedMonth.clamp(0, 11)];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isIncome ? 'Income' : 'Spending'} per month · $year',
              style: textTheme.titleSmall?.copyWith(
                color: visual.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            BlurWidget(
              child: Text(
                '${DateFormat('MMMM').format(DateTime(year, highlightedMonth + 1))}: '
                '${selected.toCurrency(currency.code)} ${currency.symbol}'
                '${average > 0 ? ' · avg ${average.toCurrency(currency.code)} ${currency.symbol}' : ''}',
                style: textTheme.bodySmall?.copyWith(
                  color: visual.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: Sizes.lg),
            SizedBox(
              height: 200,
              child: BarChart(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                BarChartData(
                  maxY: top,
                  minY: 0,
                  alignment: BarChartAlignment.spaceBetween,
                  barGroups: [
                    for (var month = 0; month < totals.length; month++)
                      BarChartGroupData(
                        x: month,
                        barRods: [
                          BarChartRodData(
                            toY: totals[month],
                            width: 14,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            color: month == highlightedMonth
                                ? barColor
                                : barColor.withValues(alpha: 0.28),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: top,
                              color: visual.textPrimary.withValues(alpha: 0.03),
                            ),
                          ),
                        ],
                      ),
                  ],
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: step,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: visual.hairline, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final month = value.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: Sizes.xs),
                            child: Text(
                              DateFormat(
                                'MMMMM',
                              ).format(DateTime(year, month + 1)),
                              style: textTheme.labelSmall?.copyWith(
                                color: month == highlightedMonth
                                    ? visual.textPrimary
                                    : visual.textSecondary,
                                fontWeight: month == highlightedMonth
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: step,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == 0) {
                            return const SizedBox.shrink();
                          }
                          return BlurWidget(
                            child: Text(
                              NumberFormat.compact().format(value),
                              style: textTheme.labelSmall?.copyWith(
                                color: visual.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (average > 0)
                        HorizontalLine(
                          y: average,
                          color: visual.textSecondary.withValues(alpha: 0.7),
                          strokeWidth: 1.5,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.only(bottom: 2),
                            labelResolver: (_) => 'avg',
                            style: textTheme.labelSmall?.copyWith(
                              color: visual.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => visual.solidSurface,
                      tooltipBorderRadius: BorderRadius.circular(12),
                      tooltipBorder: BorderSide(color: visual.hairline),
                      getTooltipItem: (group, _, rod, _) => !amountsVisible
                          ? null
                          : BarTooltipItem(
                              '${DateFormat('MMM').format(DateTime(year, group.x + 1))}\n',
                              textTheme.labelSmall!.copyWith(
                                color: visual.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${rod.toY.toCurrency(currency.code)} ${currency.symbol}',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: visual.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final spot = response?.spot;
                      if (spot == null) return;
                      final month = spot.touchedBarGroup.x;
                      ref
                          .read(highlightedMonthProvider.notifier)
                          .setValue(month);
                      ref
                          .read(filterDateStartProvider.notifier)
                          .setDate(DateTime(year, month + 1, 1));
                      ref
                          .read(filterDateEndProvider.notifier)
                          .setDate(DateTime(year, month + 2, 0));
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 260),
      error: (error, _) => Text('$error'),
    );
  }

  /// Rounds up to 1, 2, 2.5 or 5 times a power of ten, so axis steps read
  /// as round numbers.
  static double _niceCeiling(double value) {
    var magnitude = 1.0;
    while (magnitude * 10 <= value) {
      magnitude *= 10;
    }
    while (magnitude > value) {
      magnitude /= 10;
    }
    for (final step in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (step * magnitude >= value) return step * magnitude;
    }
    return 10 * magnitude;
  }
}
