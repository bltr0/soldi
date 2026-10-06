import "package:flutter/material.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../constants/constants.dart';
import '../../../model/currency.dart';
import '../../../model/transaction.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/main_converter_provider.dart';
import '../../../ui/account_currency.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/widgets/rounded_icon.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';

class PanelListTile extends ConsumerWidget {
  const PanelListTile({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.transactions,
    required this.percent,
    required this.index,
    this.enableSubcategories = false,
  });

  final String name;
  final IconData? icon;
  final Color color;
  final double amount;
  final List<Transaction> transactions;
  final double percent;
  final int index;
  final bool enableSubcategories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedListIndexProvider);
    final currency = ref.watch(currencyStateProvider);
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final expanded = selectedIndex == index;
    return TonalGlassSurface(
      radius: 22,
      pressScale: 1,
      borderColor: expanded ? color.withValues(alpha: 0.6) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => expanded
                ? ref.invalidate(selectedListIndexProvider)
                : ref.read(selectedListIndexProvider.notifier).setIndex(index),
            child: Padding(
              padding: const EdgeInsets.all(Sizes.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: Sizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: visual.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          "${transactions.length} transaction${transactions.length == 1 ? '' : 's'} · ${percent.abs().toStringAsFixed(1)}%",
                          style: textTheme.bodySmall?.copyWith(
                            color: visual.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BlurWidget(
                    child: Text(
                      "${amount.toCurrency(currency.code)} ${currency.symbol}",
                      style: textTheme.titleSmall?.copyWith(
                        color: amount >= 0 ? visual.positive : visual.negative,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: visual.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? enableSubcategories
                      ? _buildGroupedTransactions(
                          context,
                          transactions,
                          currency,
                          ref.watch(mainConverterProvider).value,
                        )
                      : TransactionsList(
                          currency: currency,
                          transactions: transactions,
                        )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedTransactions(
    BuildContext context,
    List<Transaction> txs,
    Currency currency,
    MainConverter? converter,
  ) {
    final Map<int?, List<Transaction>> grouped = {};
    final List<Widget> children = [];

    for (final t in txs) {
      grouped.putIfAbsent(t.idCategory, () => []).add(t);
    }

    if (grouped.length == 1) {
      return TransactionsList(currency: currency, transactions: txs);
    }

    grouped.forEach((categoryId, list) {
      double sum = 0;
      for (final t in list) {
        if (t.isBalanceReset) continue;
        // Shown in the main currency, at each transaction's own rate.
        final amount = converter?.transaction(t) ?? t.amount.toDouble();
        sum += t.type == TransactionType.income ? amount : -amount;
      }

      final headerName = list.first.categoryName ?? 'Uncategorized';
      final percent = list.length * 100 / txs.length;

      children.add(
        Container(
          padding: const EdgeInsets.fromLTRB(
            Sizes.sm,
            Sizes.lg,
            Sizes.lg,
            Sizes.lg,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border(left: BorderSide(width: 3, color: color)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.only(left: Sizes.sm, right: Sizes.md),
                child: RoundedIcon(
                  icon: list.first.categorySymbol != null
                      ? iconList[list.first.categorySymbol!]
                      : Icons.category,
                  backgroundColor: categoryId != null
                      ? categoryColorList[list.first.categoryColor ?? 0]
                      : Colors.grey,
                  padding: const EdgeInsets.all(Sizes.xs),
                  size: Sizes.lg,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            headerName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          "${sum.toCurrency(currency.code)} ${currency.symbol}",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: sum.toColor()),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${list.length} transactions",
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          "${percent.toStringAsFixed(2)}%",
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      children.add(TransactionsList(transactions: list, currency: currency));
    });

    return Column(children: children);
  }
}

class TransactionsList extends ConsumerWidget {
  const TransactionsList({
    super.key,
    required this.currency,
    required this.transactions,
  });

  final Currency currency;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) =>
          const Divider(indent: 15, endIndent: 15),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final amount = transaction.isBalanceReset
            ? transaction.amount
            : transaction.type == TransactionType.income
            ? transaction.amount
            : -transaction.amount;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await ref
                  .read(transactionsProvider.notifier)
                  .transactionSelect(transaction);
              if (context.mounted) {
                Navigator.of(context).pushNamed(
                  '/add-page',
                  arguments: {'transaction': transaction},
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(Sizes.lg),
              child: Row(
                children: [
                  const SizedBox(width: Sizes.lg * 2),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                (transaction.note?.isEmpty ?? true)
                                    ? DateFormat(
                                        "dd MMMM - HH:mm",
                                      ).format(transaction.date)
                                    : transaction.note!,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              "${amount.toCurrency(ref.accountCode(transaction.idBankAccount))} ${ref.accountSymbol(transaction.idBankAccount)}",
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: amount.toColor()),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              transaction.isBalanceReset
                                  ? 'Adjustment'
                                  : transaction.categoryName?.toUpperCase() ??
                                        'Uncategorized',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(
                              transaction.bankAccountName?.toUpperCase() ?? "",
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
