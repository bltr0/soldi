import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/recurring_transactions_provider.dart';
import 'recurring_payment_card.dart';
import '../../../model/recurring_transaction.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/accent_button.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';

class RecurringPaymentSection extends ConsumerWidget {
  const RecurringPaymentSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var recurringTransactionsAsync = ref.watch(recurringTransactionsProvider);

    void addRecurringPayment() {
      ref.read(selectedRecurringPayProvider.notifier).setValue(true);
      ref.read(intervalProvider.notifier).setValue(Recurrence.monthly);
      ref.invalidate(selectedBankAccountProvider);
      ref.invalidate(selectedCategoryProvider);
      ref.invalidate(selectedPeopleConcernedProvider);
      ref.invalidate(endDateProvider);
      Navigator.of(context).pushNamed(
        "/add-page",
        arguments: {'recurrencyEditingPermitted': false},
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Sizes.xxl),
      child: recurringTransactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            final visual = context.dashboardTheme;
            return TonalGlassSurface(
              radius: 28,
              padding: const EdgeInsets.all(Sizes.lg),
              child: Column(
                children: [
                  Text(
                    'No recurring payments yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: visual.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: Sizes.xs),
                  Text(
                    'Scheduled incomes and expenses will show up here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: visual.textSecondary,
                    ),
                  ),
                  const SizedBox(height: Sizes.lg),
                  AccentButton(
                    label: 'Add recurring payment',
                    onPressed: addRecurringPayment,
                  ),
                ],
              ),
            );
          }
          return Column(
            spacing: Sizes.lg,
            children: [
              ListView.separated(
                itemCount: transactions.length,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (context, index) => RecurringPaymentCard(
                  transaction: transactions[index],
                  onTap: () {
                    ref
                        .read(recurringTransactionsProvider.notifier)
                        .transactionSelect(transactions[index])
                        .whenComplete(() {
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).pushNamed("/edit-recurring-transaction");
                          }
                        });
                  },
                ),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: Sizes.lg),
              ),
              AccentButton(
                label: "Add recurring payment",
                onPressed: addRecurringPayment,
              ),
            ],
          );
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, _) {
          return Text('Error: $error');
        },
      ),
    );
  }
}
