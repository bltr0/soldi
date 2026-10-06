import "package:flutter/material.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../constants/constants.dart';
import '../../../../model/category_transaction.dart';
import '../../../../providers/categories_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../ui/extensions.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/share_breakdown.dart';

class CategoriesGraphPieChart extends ConsumerWidget {
  const CategoriesGraphPieChart({
    required this.categoryMap,
    required this.total,
    super.key,
  });

  final Map<CategoryTransaction, double> categoryMap;
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final currency = ref.watch(currencyStateProvider);
    final visual = context.dashboardTheme;
    final entries = [
      for (final entry in categoryMap.entries)
        if (entry.value != 0) entry,
    ];
    final categories = [for (final entry in entries) entry.key];
    final selected = categories.indexWhere((c) => c.id == selectedCategory?.id);
    return ShareBreakdown(
      totalText: '${total.toCurrency(currency.code)} ${currency.symbol}',
      unconverted: ref.watch(categoryTotalUnconvertedProvider).value ?? false,
      amountColor: total >= 0 ? visual.positive : visual.negative,
      selectedIndex: selected < 0 ? null : selected,
      onSelect: (i) => ref
          .read(selectedCategoryProvider.notifier)
          .setCategory(i == null ? null : categories[i]),
      slices: [
        for (final entry in entries)
          ShareSlice(
            label: entry.key.name,
            value: entry.value,
            color: categoryColorListTheme[entry.key.color],
            icon: iconList[entry.key.symbol],
            amountText:
                '${entry.value.toCurrency(currency.code)} ${currency.symbol}',
          ),
      ],
    );
  }
}
