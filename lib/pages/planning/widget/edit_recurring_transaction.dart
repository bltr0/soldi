import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/transaction.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/recurring_transactions_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/accent_button.dart';
import '../../../ui/widgets/settings_tiles.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';
import '../../transactions/create_transaction/widgets/account_selector.dart';
import '../../transactions/create_transaction/widgets/amount_widget.dart';
import '../../transactions/create_transaction/widgets/details_list_tile.dart';
import '../../transactions/create_transaction/widgets/details_list_disabled_tile.dart';
import '../../transactions/create_transaction/widgets/label_list_tile.dart';
import '../../transactions/create_transaction/widgets/people_concerned_selector.dart';
import '../../transactions/create_transaction/widgets/recurrence_list_tile_edit.dart';

class EditRecurringTransaction extends ConsumerStatefulWidget {
  const EditRecurringTransaction({super.key});

  @override
  ConsumerState<EditRecurringTransaction> createState() =>
      _EditRecurringTransactionState();
}

class _EditRecurringTransactionState
    extends ConsumerState<EditRecurringTransaction> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  late DateTime startDate;

  @override
  void initState() {
    amountController.text =
        ref
            .read(selectedRecurringTransactionUpdateProvider)
            ?.amount
            .toCurrency() ??
        '';
    noteController.text =
        ref.read(selectedRecurringTransactionUpdateProvider)?.note ?? '';
    startDate =
        ref.read(selectedRecurringTransactionUpdateProvider)?.fromDate ??
        DateTime.now();

    super.initState();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecurringTransaction = ref.watch(
      selectedRecurringTransactionUpdateProvider,
    );

    final visual = context.dashboardTheme;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.invalidate(selectedPeopleConcernedProvider);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Recurring payment"),
          actions: [
            if (selectedRecurringTransaction != null)
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded, color: visual.negative),
                onPressed: () => ref
                    .read(recurringTransactionsProvider.notifier)
                    .delete(selectedRecurringTransaction.id!)
                    .whenComplete(() {
                      if (context.mounted) Navigator.pop(context);
                    }),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Sizes.lg,
              Sizes.sm,
              Sizes.lg,
              Sizes.md,
            ),
            child: AccentButton(
              label: 'Save changes',
              icon: Icons.check_rounded,
              onPressed: () => ref
                  .read(recurringTransactionsProvider.notifier)
                  .updateTransaction(
                    amountController.text.toNum(),
                    noteController.text,
                  )
                  .whenComplete(() {
                    if (context.mounted) Navigator.of(context).pop();
                  }),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sizes.lg,
            Sizes.sm,
            Sizes.lg,
            Sizes.xl,
          ),
          physics: const BouncingScrollPhysics(),
          children: [
            TonalGlassSurface(
              tone: GlassTone.hero,
              radius: 28,
              pressScale: 1,
              padding: const EdgeInsets.symmetric(vertical: Sizes.md),
              child: AmountWidget(amountController),
            ),
            const SizedBox(height: Sizes.xl),
            SettingsGroup(
              title: 'Details',
              footer: 'Changes only affect future transactions.',
              children: [
                LabelListTile(noteController),
                DetailsListTile(
                  title: "Account",
                  icon: Icons.account_balance_wallet_rounded,
                  value: ref.watch(selectedBankAccountProvider)?.name,
                  callback: () => showAccountSelector(context),
                ),
                NonEditableDetailsListTile(
                  title: "Category",
                  icon: Icons.category_rounded,
                  value: ref.watch(selectedCategoryProvider)?.name,
                ),
                if (selectedRecurringTransaction?.type ==
                    TransactionType.expense)
                  const SettingsTile(
                    icon: Icons.group_rounded,
                    title: 'People concerned',
                    trailing: PeopleConcernedStepper(),
                  ),
                NonEditableDetailsListTile(
                  title: "Starts",
                  icon: Icons.calendar_month_rounded,
                  value: startDate.formatEDMY(),
                ),
                const RecurrenceListTileEdit(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
