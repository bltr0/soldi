import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../constants/constants.dart';
import '../../../model/transaction.dart';
import '../../../providers/accounts_provider.dart';
import '../../../ui/account_currency.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/widgets/rounded_icon.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';

class LedgerDay {
  const LedgerDay({
    required this.date,
    required this.entries,
    required this.endBalance,
  });

  final DateTime date;

  /// Newest first.
  final List<LedgerEntry> entries;
  final num endBalance;

  num get net => entries.map((e) => e.delta).sum;
}

class LedgerDayGroup extends ConsumerWidget {
  const LedgerDayGroup({required this.day, required this.accountId, super.key});

  final LedgerDay day;
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final symbol = ref.accountSymbol(accountId);
    final code = ref.accountCode(accountId);
    final net = day.net;
    final netColor = net > 0
        ? visual.positive
        : net < 0
        ? visual.negative
        : visual.textSecondary;
    final numberStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Sizes.xs, 0, Sizes.xs, Sizes.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  day.date.formatEDMY(),
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: visual.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              BlurWidget(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sizes.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${net > 0 ? '+' : ''}${net.toCurrency(code)}',
                    style: numberStyle?.copyWith(color: netColor, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: Sizes.sm),
              BlurWidget(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '= ',
                        style: TextStyle(color: visual.textSecondary),
                      ),
                      TextSpan(
                        text:
                            '${day.endBalance.toCurrency(code)} $symbol',
                      ),
                    ],
                  ),
                  style: numberStyle?.copyWith(
                    color: visual.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        TonalGlassSurface(
          radius: 20,
          pressScale: 1,
          child: Column(
            children: [
              for (final (index, entry) in day.entries.indexed) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: 64,
                    endIndent: Sizes.md,
                    color: visual.hairline,
                  ),
                _LedgerTile(entry: entry, accountId: accountId),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile({required this.entry, required this.accountId});

  final LedgerEntry entry;
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final symbol = ref.accountSymbol(accountId);
    final code = ref.accountCode(accountId);
    final t = entry.transaction;
    final incoming = t.idBankAccountTransfer == accountId;
    final otherAccount = incoming
        ? t.bankAccountName
        : t.bankAccountTransferName;
    final hasNote = t.note?.trim().isNotEmpty ?? false;

    final title = hasNote
        ? t.note!
        : switch (t.type) {
            TransactionType.transfer =>
              incoming
                  ? 'Transfer from ${otherAccount ?? 'account'}'
                  : 'Transfer to ${otherAccount ?? 'account'}',
            TransactionType.adjustment => 'Balance adjustment',
            TransactionType.income ||
            TransactionType.expense => t.categoryName ?? 'Untitled',
          };
    final kind = t.isBalanceReset
        ? 'Adjustment'
        : switch (t.type) {
            TransactionType.transfer =>
              incoming
                  ? 'From ${otherAccount ?? '?'}'
                  : t.transferFee > 0
                  ? 'To ${otherAccount ?? '?'} · fee ${t.transferFee.toCurrency(code)} $symbol'
                  : 'To ${otherAccount ?? '?'}',
            TransactionType.adjustment => 'Adjustment',
            TransactionType.income ||
            TransactionType.expense => t.categoryName ?? 'Uncategorized',
          };
    final amountColor = t.type == TransactionType.transfer
        ? t.type.toColor(brightness: Theme.of(context).brightness)
        : entry.delta < 0
        ? visual.negative
        : visual.positive;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Sizes.md,
          vertical: Sizes.xs,
        ),
        onTap: () async {
          await ref.read(transactionsProvider.notifier).transactionSelect(t);
          if (context.mounted) {
            Navigator.of(
              context,
            ).pushNamed('/add-page', arguments: {'transaction': t});
          }
        },
        leading: RoundedIcon(
          icon: t.isBalanceReset
              ? Icons.sync
              : t.categorySymbol != null
              ? iconList[t.categorySymbol]
              : incoming
              ? Icons.call_received_rounded
              : Icons.swap_horiz_rounded,
          backgroundColor: t.categoryColor != null
              ? categoryColorListTheme[t.categoryColor!]
              : Theme.of(context).colorScheme.secondary,
          size: 22,
          padding: const EdgeInsets.all(Sizes.sm),
        ),
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: visual.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '$kind · ${DateFormat.Hm().format(t.date)}',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: visual.textSecondary),
        ),
        trailing: BlurWidget(
          child: Text(
            '${entry.delta > 0 ? '+' : ''}${entry.delta.toCurrency(code)} $symbol',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: amountColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
