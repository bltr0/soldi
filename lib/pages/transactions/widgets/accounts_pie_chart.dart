import "package:flutter/material.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/constants.dart';
import '../../../model/bank_account.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/share_breakdown.dart';

class AccountsPieChart extends ConsumerWidget {
  const AccountsPieChart({
    required this.accounts,
    required this.amounts,
    required this.total,
    this.unconverted = false,
    super.key,
  });

  final List<BankAccount> accounts;
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
        for (final account in accounts)
          ShareSlice(
            label: account.name,
            value: amounts[account.id] ?? 0,
            color: accountColorListTheme[account.color],
            icon: accountIconList[account.symbol],
            amountText:
                '${(amounts[account.id] ?? 0).toCurrency(currency.code)} ${currency.symbol}',
          ),
      ],
    );
  }
}
