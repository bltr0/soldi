import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../model/transaction.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/account_currency.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';
import 'transaction_details_dialog.dart';

class DueSection extends ConsumerWidget {
  const DueSection({
    this.margin = const EdgeInsets.only(top: Sizes.lg),
    super.key,
  });

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingReimbursementsProvider);
    return pending.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: margin,
          child: _DuePanel(items: items),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Padding(
        padding: margin,
        child: _DuePanel(
          items: const [],
          error: true,
          onRetry: () => ref.invalidate(pendingReimbursementsProvider),
        ),
      ),
    );
  }
}

class _DuePanel extends StatelessWidget {
  const _DuePanel({required this.items, this.error = false, this.onRetry});

  final List<Transaction> items;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return TonalGlassSurface(
      radius: 28,
      padding: const EdgeInsets.all(Sizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Sizes.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: visual.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Payments other people still owe you',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: visual.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sizes.md),
          if (error)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Reload pending payments',
                style: TextStyle(color: visual.textSecondary),
              ),
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: Sizes.sm),
              _DueTile(transaction: items[i]),
            ],
        ],
      ),
    );
  }
}

class _DueTile extends ConsumerWidget {
  const _DueTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final symbol = ref.accountSymbol(transaction.idBankAccount);
    final title = transaction.note?.trim().isNotEmpty == true
        ? transaction.note!.trim()
        : (transaction.categoryName ?? 'Payment');
    final showDue = transaction.peopleConcerned > 1;

    return TonalGlassSurface(
      radius: 14,
      color: visual.raisedSurface,
      borderColor: visual.glassBorder,
      padding: const EdgeInsets.symmetric(horizontal: Sizes.sm, vertical: 2),
      boxShadow: const [],
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showTransactionDetailsDialog(context, transaction),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sizes.sm,
                  vertical: Sizes.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: visual.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            DateFormat('d MMM y').format(transaction.date),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: visual.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        BlurWidget(
                          child: Text(
                            '${transaction.amount.toCurrency()}$symbol',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: visual.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        if (showDue)
                          BlurWidget(
                            child: Text(
                              'Due: ${transaction.splitDue.toCurrency()}$symbol',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: visual.negative,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: transaction.reimbursementDue,
                visualDensity: VisualDensity.compact,
                activeColor: visual.textPrimary,
                checkColor: visual.solidSurface,
                onChanged: (due) {
                  ref
                      .read(transactionsProvider.notifier)
                      .saveTransaction(
                        transaction.copy(reimbursementDue: due ?? false),
                      );
                },
              ),
              Text(
                transaction.reimbursementDue ? 'Still due' : 'Paid back',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: visual.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
