import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ui/widgets/unconverted_amount.dart';
import '../../../providers/main_converter_provider.dart';

import '../../../constants/style.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/statistics_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/formatters/formatted_date_range.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/blur_widget.dart';

enum MonthSelectorType { simple, advanced } //advanced = with amount

class MonthSelector extends ConsumerWidget {
  const MonthSelector({required this.type, super.key});

  final MonthSelectorType type;
  final double height = 60;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAmount = ref.watch(totalAmountProvider);
    final startDate = ref.watch(filterDateStartProvider);
    final endDate = ref.watch(filterDateEndProvider);
    final currencyState = ref.watch(currencyStateProvider);

    final visual = context.dashboardTheme;
    double currentHeight = type == MonthSelectorType.advanced ? 60 : 44;

    return GestureDetector(
      onTap: () async {
        // pick range of dates
        DateTimeRange? range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(1970, 1, 1),
          lastDate: DateTime(2100, 12, 31),
          currentDate: DateTime.now(),
          initialDateRange: DateTimeRange(start: startDate, end: endDate),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              appBarTheme: Theme.of(
                context,
              ).appBarTheme.copyWith(backgroundColor: blue1),
            ),
            child: child!,
          ),
        );
        if (range != null) {
          ref.read(filterDateStartProvider.notifier).setDate(range.start);
          ref.read(filterDateEndProvider.notifier).setDate(range.end);
          ref
              .read(highlightedMonthProvider.notifier)
              .setValue(range.start.month - 1);
        }
      },
      child: Container(
        clipBehavior: Clip.antiAlias, // force rounded corners on children
        height: currentHeight,
        padding: const EdgeInsets.all(Sizes.xs),
        decoration: BoxDecoration(
          color: visual.textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(currentHeight / 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                // move to previous month
                DateTime newStartDate = DateTime(
                  startDate.year,
                  startDate.month - 1,
                  1,
                );
                DateTime newEndDate = DateTime(
                  newStartDate.year,
                  newStartDate.month + 1,
                  0,
                );
                ref
                    .read(filterDateStartProvider.notifier)
                    .setDate(newStartDate);
                ref.read(filterDateEndProvider.notifier).setDate(newEndDate);
                ref.read(transactionsProvider.notifier).filterTransactions();
                ref
                    .read(highlightedMonthProvider.notifier)
                    .setValue(newStartDate.month - 1);
              },
              child: Container(
                width: currentHeight - Sizes.sm,
                height: currentHeight - Sizes.sm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visual.raisedSurface,
                  boxShadow: [
                    BoxShadow(
                      color: visual.shadow.withValues(
                        alpha: visual.shadow.a * 0.4,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: visual.textPrimary,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  getFormattedDateRange(startDate, endDate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: visual.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (type == MonthSelectorType.advanced)
                  UnconvertedAmount(
                    unconverted: ref.watch(totalAmountUnconvertedProvider),
                    child: BlurWidget(
                    sigma: 12,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: totalAmount.toCurrency(currencyState.code),
                            style: Theme.of(context).textTheme.bodyLarge!
                                .copyWith(color: totalAmount.toColor()),
                          ),
                          TextSpan(
                            text: currencyState.symbol,
                            style: Theme.of(context).textTheme.labelLarge!
                                .copyWith(color: totalAmount.toColor()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
              ],
            ),
            GestureDetector(
              onTap: () {
                // move to next month
                DateTime newStartDate = DateTime(
                  startDate.year,
                  startDate.month + 1,
                  1,
                );
                DateTime newEndDate = DateTime(
                  newStartDate.year,
                  newStartDate.month + 1,
                  0,
                );
                ref
                    .read(filterDateStartProvider.notifier)
                    .setDate(newStartDate);
                ref.read(filterDateEndProvider.notifier).setDate(newEndDate);
                ref.read(transactionsProvider.notifier).filterTransactions();
                ref
                    .read(highlightedMonthProvider.notifier)
                    .setValue(newStartDate.month - 1);
              },
              child: Container(
                width: currentHeight - Sizes.sm,
                height: currentHeight - Sizes.sm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visual.raisedSurface,
                  boxShadow: [
                    BoxShadow(
                      color: visual.shadow.withValues(
                        alpha: visual.shadow.a * 0.4,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: visual.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
