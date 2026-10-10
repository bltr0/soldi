import 'package:flutter/material.dart';
import "package:flutter_riverpod/flutter_riverpod.dart";

import '../../../../constants/constants.dart';
import '../../../../model/bank_account.dart';
import '../../../../model/transaction.dart';
import '../../../../providers/transactions_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/picker_sheet.dart';
import '../../../../ui/widgets/segmented_pill.dart';
import 'account_selector.dart';
import 'amount_widget.dart';

class AmountSection extends ConsumerWidget {
  const AmountSection(
    this.amountController, {
    this.autofocus = false,
    super.key,
  });

  final TextEditingController amountController;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(selectedTransactionTypeProvider);
    final visual = context.dashboardTheme;

    return Padding(
      padding: const EdgeInsets.all(Sizes.md),
      child: Column(
        children: [
          if (selectedType == TransactionType.adjustment)
            Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Balance adjustment",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            SegmentedPill<TransactionType>(
              height: 40,
              selected: selectedType,
              options: const {
                TransactionType.expense: 'Expense',
                TransactionType.income: 'Income',
                TransactionType.transfer: 'Transfer',
              },
              onChanged: (type) {
                ref
                    .read(selectedTransactionTypeProvider.notifier)
                    .setType(type);
                ref.invalidate(bankAccountTransferProvider);
              },
            ),
          AmountWidget(amountController, autofocus: autofocus),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: selectedType == TransactionType.transfer
                ? Row(
                    children: [
                      Expanded(
                        child: _AccountChip(
                          label: 'From',
                          account: ref.watch(selectedBankAccountProvider),
                          onTap: () => showAccountSelector(context),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Swap accounts',
                        color: visual.textSecondary,
                        onPressed: () => ref
                            .read(transactionsProvider.notifier)
                            .switchAccount(),
                        icon: const Icon(Icons.swap_horiz_rounded),
                      ),
                      Expanded(
                        child: _AccountChip(
                          label: 'To',
                          account: ref.watch(bankAccountTransferProvider),
                          onTap: () =>
                              showAccountSelector(context, transfer: true),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.label,
    required this.account,
    required this.onTap,
  });

  final String label;
  final BankAccount? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final account = this.account;
    return Material(
      color: visual.textPrimary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Sizes.sm),
          child: Row(
            children: [
              PickerIcon(
                icon: account == null
                    ? Icons.account_balance_wallet_outlined
                    : accountIconList[account.symbol],
                color: account == null
                    ? null
                    : accountColorListTheme[account.color],
              ),
              const SizedBox(width: Sizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.labelSmall?.copyWith(
                        color: visual.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      account?.name ?? 'Choose',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: visual.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
