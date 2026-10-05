import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../constants/constants.dart';
import '../../model/transaction.dart';
import '../../providers/currency_provider.dart';
import '../../providers/main_converter_provider.dart';
import '../account_currency.dart';
import '../../providers/transactions_provider.dart';
import '../device.dart';
import '../extensions.dart';
import '../theme/dashboard_visual_theme.dart';
import 'blur_widget.dart';
import 'default_container.dart';
import 'rounded_icon.dart';
import 'main_equivalent.dart';
import 'unconverted_amount.dart';

class TransactionsList extends ConsumerStatefulWidget {
  const TransactionsList({
    super.key,
    required this.transactions,
    this.margin = const EdgeInsets.symmetric(horizontal: Sizes.lg),
    this.padding,
    this.ignoreBlur = true,
  });

  final List<Transaction> transactions;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool ignoreBlur;

  @override
  ConsumerState<TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends ConsumerState<TransactionsList> {
  Map<String, double> totals = {};
  Set<String> unconvertedDays = {};
  List<Transaction> get transactions => widget.transactions;

  /// Daily totals in the main currency, each transaction at its own rate.
  void updateTotal(MainConverter? converter) {
    totals = {};
    unconvertedDays = {};
    for (final transaction in transactions) {
      final date = transaction.date.formatYMD();
      final currentTotal = totals[date] ?? 0.0;

      final value =
          converter?.transaction(transaction) ??
          transaction.amount.toDouble();
      final amount = transaction.isBalanceReset
          ? 0.0
          : switch (transaction.type) {
              TransactionType.expense => -value,
              TransactionType.income => value,
              TransactionType.transfer => 0.0,
              TransactionType.adjustment => 0.0,
            };

      totals[date] = currentTotal + amount;
      if (amount != 0 && (converter?.unconverted(transaction) ?? false)) {
        unconvertedDays.add(date);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    updateTotal(ref.watch(mainConverterProvider).value);
    if (transactions.isNotEmpty) {
      return DefaultContainer(
        margin: widget.margin,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: widget.padding,
          shrinkWrap: true,
          itemCount: totals.keys.length,
          separatorBuilder: (_, _) => const SizedBox(height: Sizes.lg),
          itemBuilder: (context, monthIndex) {
            // Group transactions by month
            final dates = totals.keys.toList()..sort((a, b) => b.compareTo(a));
            final currentDate = dates[monthIndex];
            final dateTransactions = transactions
                .where((t) => t.date.formatYMD() == currentDate)
                .toList();

            return Column(
              children: [
                TransactionTitle(
                  ignoreBlur: widget.ignoreBlur,
                  date: DateTime.parse(currentDate),
                  total: totals[currentDate] ?? 0,
                  unconverted: unconvertedDays.contains(currentDate),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.dashboardTheme.solidSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.dashboardTheme.hairline),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: dateTransactions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 64,
                        endIndent: Sizes.md,
                        color: context.dashboardTheme.hairline,
                      ),
                      itemBuilder: (context, index) {
                        final transaction = dateTransactions[index];
                        return TransactionTile(
                          key: ValueKey(transaction.id),
                          ignoreBlur: widget.ignoreBlur,
                          transaction: transaction,
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: DefaultContainer(
        margin: widget.margin,
        child: Text(
          "Add a transaction to make this section more appealing",
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    required this.transaction,
    required this.ignoreBlur,
    super.key,
  });

  final bool ignoreBlur;
  final Transaction transaction;

  String _transferSubtitle(WidgetRef ref, String senderSymbol) =>
      _transferSubtitleFor(
        transaction,
        senderSymbol,
        ref.accountSymbol(transaction.idBankAccountTransfer),
        ref.accountCode(transaction.idBankAccount),
        ref.accountCode(transaction.idBankAccountTransfer),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.accountSymbol(transaction.idBankAccount);
    final code = ref.accountCode(transaction.idBankAccount);
    final visual = context.dashboardTheme;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        visualDensity: VisualDensity.compact,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Sizes.md,
          vertical: Sizes.xs,
        ),
        onTap: () async {
          await ref
              .read(transactionsProvider.notifier)
              .transactionSelect(transaction)
              .whenComplete(() {
                if (context.mounted) {
                  Navigator.of(context).pushNamed(
                    "/add-page",
                    arguments: {'transaction': transaction},
                  );
                }
              });
        },
        leading: RoundedIcon(
          icon: transaction.type == TransactionType.adjustment
              ? Icons.sync
              : transaction.categorySymbol != null
              ? iconList[transaction.categorySymbol]
              : Icons.swap_horiz_rounded,
          backgroundColor: transaction.categoryColor != null
              ? categoryColorListTheme[transaction.categoryColor!]
              : Theme.of(context).colorScheme.secondary,
          size: 25,
          padding: const EdgeInsets.all(Sizes.sm),
        ),
        title: Text(
          (transaction.note?.trim().isNotEmpty ?? false)
              ? transaction.note!
              : transaction.type == TransactionType.transfer
              ? "Transfer"
              : DateFormat("dd MMMM - HH:mm").format(transaction.date),
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
            color: visual.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          switch (transaction.type) {
            TransactionType.transfer => _transferSubtitle(ref, symbol),
            TransactionType.adjustment => "Adjustment",
            TransactionType.income || TransactionType.expense =>
              transaction.categoryName ?? "Uncategorized",
          },
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelMedium!.copyWith(color: visual.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MainEquivalent(
              amount: transaction.amount,
              code: code,
              date: transaction.date,
              ignoreBlur: ignoreBlur,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 15,
              ),
              child: BlurWidget(
                ignore: ignoreBlur,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      switch (transaction.type) {
                        TransactionType.expense =>
                          "-${transaction.amount.toCurrency(code)}",
                        TransactionType.adjustment =>
                          transaction.amount.toCurrency(code),
                        TransactionType.income || TransactionType.transfer =>
                          transaction.amount.toCurrency(code),
                      },
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: transaction.type.toColor(
                          brightness: Theme.of(context).brightness,
                        ),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      symbol,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: transaction.type.toColor(
                          brightness: Theme.of(context).brightness,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              transaction.type == TransactionType.transfer
                  ? "${transaction.bankAccountName ?? ''}→${transaction.bankAccountTransferName ?? ''}"
                  : transaction.bankAccountName ?? '',
              style: Theme.of(
                context,
              ).textTheme.labelMedium!.copyWith(color: visual.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Transfer", plus the received amount when it differs and the fee.
String _transferSubtitleFor(
  Transaction transaction,
  String senderSymbol,
  String receiverSymbol,
  String senderCode,
  String receiverCode,
) {
  final parts = <String>['Transfer'];
  if (transaction.amountTransfer != null) {
    parts.add(
      'receives ${transaction.amountIn.toCurrency(receiverCode)} $receiverSymbol',
    );
  }
  if (transaction.transferFee > 0) {
    parts.add('fee ${transaction.transferFee.toCurrency(senderCode)} $senderSymbol');
  }
  return parts.join(' · ');
}

class TransactionTitle extends ConsumerWidget {
  final DateTime date;
  final num total;
  final bool ignoreBlur;

  const TransactionTitle({
    super.key,
    required this.date,
    required this.total,
    required this.ignoreBlur,
    this.unconverted = false,
  });

  final bool unconverted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyStateProvider);
    final visual = context.dashboardTheme;
    final color = total < 0
        ? visual.negative
        : (total > 0 ? visual.positive : visual.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sizes.xs, 0, Sizes.xs, Sizes.sm),
      child: Row(
        children: [
          Text(
            date.formatEDMY(),
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: visual.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          UnconvertedAmount(
            unconverted: unconverted,
            child: BlurWidget(
              ignore: ignoreBlur,
              child: Text(
                '${total.toCurrency(currencyState.code)} ${currencyState.symbol}',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
