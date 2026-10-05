import "package:flutter/material.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/constants.dart';
import '../../../model/category_transaction.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/share_breakdown.dart';

class CategoriesPieChart extends ConsumerWidget {
  const CategoriesPieChart({
    required this.categories,
    required this.amounts,
    required this.total,
    this.unconverted = false,
    super.key,
  });

  final List<CategoryTransaction> categories;
  final Map<int, double> amounts;
  final double total;
  final bool unconverted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedListIndexProvider);
    final currency = ref.watch(currencyStateProvider);
    final visual = context.dashboardTheme;
    return ShareBreakdown(
      totalText: '${total.toCurrency(currency.code)} ${currency.symbol}',
      unconverted: unconverted,
      amountColor: total >= 0 ? visual.positive : visual.negative,
      selectedIndex: selectedIndex < 0 ? null : selectedIndex,
      onSelect: (i) =>
          ref.read(selectedListIndexProvider.notifier).setIndex(i ?? -1),
      slices: [
        for (final category in categories)
          ShareSlice(
            label: category.name,
            value: amounts[category.id] ?? 0,
            color: categoryColorListTheme[category.color],
            icon: iconList[category.symbol],
            amountText:
                '${(amounts[category.id] ?? 0).toCurrency(currency.code)} ${currency.symbol}',
          ),
      ],
    );
  }
}
