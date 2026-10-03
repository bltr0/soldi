import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/constants.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/widgets/rounded_icon.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';
import '../../../model/recurring_transaction.dart';
import '../../../ui/device.dart';
import 'older_recurring_payments.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/currency_provider.dart';

import '../../../providers/categories_provider.dart';

/// This class shows account summaries in dashboard
class RecurringPaymentCard extends ConsumerWidget {
  const RecurringPaymentCard({
    required this.transaction,
    this.onTap,
    super.key,
  });

  final RecurringTransaction transaction;
  final VoidCallback? onTap;

  String getNextText() {
    final now = DateTime.now();
    final daysPassed = now
        .difference(transaction.lastInsertion ?? transaction.fromDate)
        .inDays;
    final daysInterval = transaction.recurrency.days;
    final daysUntilNextTransaction = daysInterval - (daysPassed % daysInterval);
    return daysUntilNextTransaction.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value;
    final accounts = ref.watch(accountsProvider).value;
    final visual = context.dashboardTheme;
    final currencyState = ref.watch(currencyStateProvider);

    var category = categories?.firstWhereOrNull(
      (element) => element.id == transaction.idCategory,
    );

    if (category == null) return const SizedBox.shrink();

    final accountName = accounts
        ?.firstWhereOrNull((account) => account.id == transaction.idBankAccount)
        ?.name;
    final amountColor = transaction.type.toColor(
      brightness: Theme.of(context).brightness,
    );
    final meta = [
      transaction.recurrency.label,
      category.name,
      ?accountName,
    ].join(' · ');

    return TonalGlassSurface(
      onTap: onTap,
      radius: 28,
      padding: const EdgeInsets.all(Sizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RoundedIcon(
                icon: iconList[category.symbol],
                backgroundColor: categoryColorList[category.color],
                padding: const EdgeInsets.all(Sizes.sm),
                size: 22,
              ),
              const SizedBox(width: Sizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: visual.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: visual.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sizes.sm),
              BlurWidget(
                sigma: 12,
                child: Text(
                  '${transaction.type.prefix}${transaction.amount.toCurrency(currencyState.code)}${currencyState.symbol}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  transaction.toDate == null
                      ? 'In ${getNextText()} days'
                      : 'In ${getNextText()} days · until ${transaction.toDate?.formatEDMY()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: visual.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: Sizes.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    builder: (_) => FractionallySizedBox(
                      heightFactor: 0.9,
                      child: OlderRecurringPayments(transaction: transaction),
                    ),
                  );
                },
                child: const Text('Older payments'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
