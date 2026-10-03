import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/recurring_transaction.dart';
import '../../../model/transaction.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/recurring_transactions_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import "widgets/account_selector.dart";
import 'widgets/amount_section.dart';
import "widgets/category_selector.dart";
import 'widgets/details_list_tile.dart';
import 'widgets/duplicate_transaction_dialog.dart';
import 'widgets/label_list_tile.dart';
import 'widgets/people_concerned_selector.dart';
import 'widgets/recurrence_list_tile.dart';
<<<<<<< Updated upstream
=======
import 'widgets/transfer_details_fields.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';
>>>>>>> Stashed changes

class CreateTransactionPage extends ConsumerStatefulWidget {
  const CreateTransactionPage({super.key, this.transaction});

  final Transaction? transaction;

  @override
  ConsumerState<CreateTransactionPage> createState() =>
      _CreateTransactionPage();
}

class _CreateTransactionPage extends ConsumerState<CreateTransactionPage> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  bool recurrencyEditingPermitted = true;
  late final String _originalAmount;
  late final String _originalNote;
  late final TransactionType _originalType;
  late final DateTime _originalDate;
  late final int? _originalCategoryId;
  late final int? _originalAccountId;
  late final int? _originalTransferId;
  late final int _originalPeopleConcerned;
  late final bool _originalReimbursementDue;
  late final bool _originalRecurring;
  late final Recurrence _originalInterval;
  late final DateTime? _originalEndDate;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      recurrencyEditingPermitted = !widget.transaction!.recurring;
<<<<<<< Updated upstream
      amountController.text = widget.transaction?.amount.toCurrency() ?? '';
=======
      amountController.text = widget.transaction!.amount.toCurrency(
        ref
            .read(accountsProvider)
            .value
            ?.firstWhereOrNull((a) => a.id == widget.transaction!.idBankAccount)
            ?.currencyCode(ref.read(currencyStateProvider).code),
      );
>>>>>>> Stashed changes
      noteController.text = widget.transaction?.note ?? '';
    }
    _syncExpensePrefix(ref.read(selectedTransactionTypeProvider));
    amountController.addListener(_onAmountChanged);
    noteController.addListener(_onNoteChanged);

    _originalAmount = getCleanAmountString();
    _originalNote = noteController.text;
    _originalType = ref.read(selectedTransactionTypeProvider);
    _originalDate = ref.read(selectedDateProvider);
    _originalCategoryId = ref.read(selectedCategoryProvider)?.id;
    _originalAccountId = ref.read(selectedBankAccountProvider)?.id;
    _originalTransferId = ref.read(bankAccountTransferProvider)?.id;
    _originalPeopleConcerned = ref.read(selectedPeopleConcernedProvider);
    _originalReimbursementDue = ref.read(selectedReimbursementDueProvider);
    _originalRecurring = ref.read(selectedRecurringPayProvider);
    _originalInterval = ref.read(intervalProvider);
    _originalEndDate = ref.read(endDateProvider);
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  String getCleanAmountString() {
    // Remove all non-numeric characters
    var cleanNumberString = amountController.text.replaceAll(
      RegExp(r'[^0-9\.]'),
      '',
    );

    // Remove leading zeros only if the number does not start with "0."
    if (!cleanNumberString.startsWith('0.')) {
      cleanNumberString = cleanNumberString.replaceAll(
        RegExp(r'^0+(?!\.)'),
        '',
      );
    }

    if (cleanNumberString.startsWith('.')) {
      cleanNumberString = '0$cleanNumberString';
    }

    return cleanNumberString;
  }

  num? _parsedAmount() {
    final clean = getCleanAmountString();
    if (clean.isEmpty) return null;
    final value = clean.toNum();
    final selectedType = ref.read(selectedTransactionTypeProvider);
    if (selectedType == TransactionType.adjustment &&
        amountController.text.trim().startsWith('-')) {
      return -value;
    }
    return value;
  }

  void _onNoteChanged() {
    if (mounted) setState(() {});
  }

  void _onAmountChanged() {
    _syncExpensePrefix(ref.read(selectedTransactionTypeProvider));
    if (mounted) setState(() {});
  }

  void _syncExpensePrefix(TransactionType selectedType) {
    if (selectedType == TransactionType.adjustment) return;

    var toBeWritten = getCleanAmountString();

    if (selectedType == TransactionType.expense && toBeWritten.isNotEmpty) {
      toBeWritten = "-$toBeWritten";
    }

    if (toBeWritten != amountController.text) {
      amountController.value = TextEditingValue(
        text: toBeWritten,
        selection: TextSelection.collapsed(offset: toBeWritten.length),
      );
    }
  }

  bool _isFormValid(TransactionType selectedType) {
    if (getCleanAmountString().isEmpty) return false;
    if (ref.read(selectedBankAccountProvider) == null) return false;
    switch (selectedType) {
      case TransactionType.transfer:
        return ref.read(bankAccountTransferProvider) != null;
      case TransactionType.income:
      case TransactionType.expense:
        if (ref.read(selectedRecurringPayProvider)) {
          return ref.read(selectedCategoryProvider) != null;
        }
        return true;
      case TransactionType.adjustment:
        return true;
    }
  }

  bool _isDirty(TransactionType selectedType) {
    if (_parsedAmount() !=
        (widget.transaction?.amount ??
            (_originalAmount.isEmpty ? null : _originalAmount.toNum()))) {
      return true;
    }
    if (noteController.text != _originalNote) return true;
    if (selectedType != _originalType) return true;
    if (!ref.read(selectedDateProvider).isSameDay(_originalDate)) return true;
    if (ref.read(selectedCategoryProvider)?.id != _originalCategoryId) {
      return true;
    }
    if (ref.read(selectedBankAccountProvider)?.id != _originalAccountId) {
      return true;
    }
    if (ref.read(bankAccountTransferProvider)?.id != _originalTransferId) {
      return true;
    }
    if (selectedType == TransactionType.expense &&
        ref.read(selectedPeopleConcernedProvider) != _originalPeopleConcerned) {
      return true;
    }
    if (selectedType == TransactionType.expense &&
        ref.read(selectedReimbursementDueProvider) !=
            _originalReimbursementDue) {
      return true;
    }
    if (ref.read(selectedRecurringPayProvider) != _originalRecurring) {
      return true;
    }
    if (ref.read(intervalProvider) != _originalInterval) return true;
    if (ref.read(endDateProvider) != _originalEndDate) return true;
    return false;
  }

  bool _canSave(TransactionType selectedType) {
    if (!_isFormValid(selectedType)) return false;
    return widget.transaction == null || _isDirty(selectedType);
  }

  void _refreshAccountAndNavigateBack() async {
    ref
        .read(accountsProvider.notifier)
        .refreshAccount(ref.read(selectedBankAccountProvider)!)
        .whenComplete(() {
          if (mounted) Navigator.of(context).pop();
        });
  }

  void _createOrUpdateTransaction() async {
    final selectedType = ref.read(selectedTransactionTypeProvider);

    final amount = _parsedAmount();

    if (amount != null) {
      if (widget.transaction != null) {
        if (ref.read(selectedRecurringPayProvider) &&
            !widget.transaction!.recurring) {
          await ref
              .read(recurringTransactionsProvider.notifier)
              .create(amount, noteController.text, selectedType)
              .then((value) async {
                if (value != null) {
                  await ref
                      .read(transactionsProvider.notifier)
                      .updateTransaction(
                        widget.transaction!,
                        amount,
                        noteController.text,
                        value.id,
                      )
                      .whenComplete(() => _refreshAccountAndNavigateBack());
                }
              });
        } else {
          await ref
              .read(transactionsProvider.notifier)
              .updateTransaction(
                widget.transaction!,
                amount,
                noteController.text,
                widget.transaction!.idRecurringTransaction,
              )
              .whenComplete(() => _refreshAccountAndNavigateBack());
        }
      } else {
        if (selectedType == TransactionType.transfer) {
          if (ref.read(bankAccountTransferProvider) != null) {
            await ref
                .read(transactionsProvider.notifier)
                .create(amount, noteController.text)
                .whenComplete(() => _refreshAccountAndNavigateBack());
          }
        } else {
          if (ref.read(selectedRecurringPayProvider)) {
            await ref
                .read(recurringTransactionsProvider.notifier)
                .create(amount, noteController.text, selectedType);
          } else {
            await ref
                .read(transactionsProvider.notifier)
                .create(amount, noteController.text);
          }
          _refreshAccountAndNavigateBack();
        }
      }
    }
  }

  void _deleteTransaction() async {
    await ref
        .read(transactionsProvider.notifier)
        .delete(widget.transaction!.id!)
        .whenComplete(() => _refreshAccountAndNavigateBack());
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(selectedTransactionTypeProvider);
    ref.watch(selectedBankAccountProvider);
    ref.watch(bankAccountTransferProvider);
    ref.watch(selectedCategoryProvider);
    ref.watch(selectedDateProvider);
    ref.watch(selectedPeopleConcernedProvider);
    final paidForOthers = ref.watch(selectedReimbursementDueProvider);
    ref.watch(selectedRecurringPayProvider);
    ref.watch(intervalProvider);
    ref.watch(endDateProvider);

    ref.listen(selectedTransactionTypeProvider, (previous, next) {
      _syncExpensePrefix(next);
    });

    final isSaveEnabled = _canSave(selectedType);

    final visual = context.dashboardTheme;
    final arrowColor = visual.textPrimary;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(transactionsProvider.notifier).reset();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            color: arrowColor,
            icon: const BackButtonIcon(),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            (widget.transaction != null)
                ? "Editing transaction"
                : "New transaction",
          ),
          actions: [
            if (widget.transaction != null) ...[
              IconButton(
                icon: Icon(
                  Icons.copy,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DuplicateTransactionDialog(
                    transaction: widget.transaction!,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: _deleteTransaction,
              ),
            ],
          ],
        ),
        persistentFooterDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        persistentFooterButtons: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Sizes.sm,
              Sizes.xs,
              Sizes.sm,
              Sizes.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: visual.navigationSelected,
                  foregroundColor: visual.navigationFill.withValues(alpha: 1),
                  disabledBackgroundColor: visual.textPrimary.withValues(
                    alpha: 0.12,
                  ),
                  disabledForegroundColor: visual.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                onPressed: isSaveEnabled ? _createOrUpdateTransaction : null,
                child: Text(
                  widget.transaction != null
                      ? "UPDATE TRANSACTION"
                      : "ADD TRANSACTION",
                ),
              ),
            ),
          ),
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: Sizes.md),
          child: Column(
            children: [
<<<<<<< Updated upstream
              AmountSection(amountController),
              const SizedBox(height: Sizes.sm),
              Container(
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  children: [
                    LabelListTile(noteController),
                    const Divider(height: 1),
                    if (selectedType != TransactionType.transfer) ...[
                      DetailsListTile(
                        title: "Account",
                        icon: Icons.account_balance_wallet,
                        value: ref.watch(selectedBankAccountProvider)?.name,
                        callback: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          showModalBottomSheet(
                            context: context,
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            isScrollControlled: true,
                            useSafeArea: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(Sizes.borderRadius),
                                topRight: Radius.circular(Sizes.borderRadius),
                              ),
                            ),
                            builder: (_) => DraggableScrollableSheet(
                              expand: false,
                              minChildSize: 0.5,
                              initialChildSize: 0.7,
                              maxChildSize: 0.9,
                              builder: (_, controller) =>
                                  AccountSelector(scrollController: controller),
                            ),
                          );
                        },
                      ),
                      if (selectedType != TransactionType.adjustment) ...[
                        const Divider(height: 1),
=======
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
                child: TonalGlassSurface(
                  tone: GlassTone.hero,
                  radius: 28,
                  pressScale: 1,
                  child: AmountSection(amountController),
                ),
              ),
              if (selectedType == TransactionType.transfer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Sizes.lg,
                    Sizes.md,
                    Sizes.lg,
                    0,
                  ),
                  child: TonalGlassSurface(
                    radius: 24,
                    pressScale: 1,
                    padding: const EdgeInsets.only(
                      top: Sizes.sm,
                      bottom: Sizes.lg,
                    ),
                    child: TransferDetailsFields(
                      controller: _transfer,
                      amount: _parsedAmount(),
                      senderSymbol:
                          fromAccount?.currencySymbol(mainCurrency.symbol) ??
                          mainCurrency.symbol,
                      receiverSymbol:
                          toAccount?.currencySymbol(mainCurrency.symbol) ??
                          mainCurrency.symbol,
                      senderCode: fromAccount?.currencyCode(mainCurrency.code),
                      receiverCode: toAccount?.currencyCode(mainCurrency.code),
                      crossCurrency: _isCrossCurrency,
                      senderName: fromAccount?.name,
                      receiverName: toAccount?.name,
                    ),
                  ),
                ),
              const SizedBox(height: Sizes.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
                child: TonalGlassSurface(
                  radius: 24,
                  pressScale: 1,
                  child: Column(
                    children: [
                      LabelListTile(noteController),
                      const Divider(height: 1),
                      if (selectedType != TransactionType.transfer) ...[
>>>>>>> Stashed changes
                        DetailsListTile(
                          title: "Account",
                          icon: Icons.account_balance_wallet,
                          value: ref.watch(selectedBankAccountProvider)?.name,
                          callback: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            showModalBottomSheet(
                              context: context,
                              clipBehavior: Clip.antiAliasWithSaveLayer,
                              isScrollControlled: true,
                              useSafeArea: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(Sizes.borderRadius),
                                  topRight: Radius.circular(Sizes.borderRadius),
                                ),
                              ),
                              builder: (_) => DraggableScrollableSheet(
                                expand: false,
                                minChildSize: 0.5,
                                initialChildSize: 0.7,
                                maxChildSize: 0.9,
                                builder: (_, controller) => AccountSelector(
                                  scrollController: controller,
                                ),
                              ),
                            );
                          },
                        ),
                        if (selectedType != TransactionType.adjustment) ...[
                          const Divider(height: 1),
                          DetailsListTile(
                            title: "Category",
                            icon: Icons.list_alt,
                            value:
                                ref.watch(selectedCategoryProvider)?.name ??
                                "Uncategorized",
                            callback: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              showModalBottomSheet(
                                context: context,
                                clipBehavior: Clip.antiAliasWithSaveLayer,
                                isScrollControlled: true,
                                useSafeArea: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(
                                      Sizes.borderRadius,
                                    ),
                                    topRight: Radius.circular(
                                      Sizes.borderRadius,
                                    ),
                                  ),
                                ),
                                builder: (_) => DraggableScrollableSheet(
                                  expand: false,
                                  minChildSize: 0.5,
                                  initialChildSize: 0.7,
                                  maxChildSize: 0.9,
                                  builder: (_, controller) => CategorySelector(
                                    scrollController: controller,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        if (selectedType == TransactionType.expense) ...[
                          const Divider(height: 1),
                          DetailsListTile(
                            title: "People concerned",
                            icon: Icons.group_outlined,
                            value:
                                "${ref.watch(selectedPeopleConcernedProvider)}",
                            callback: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              showModalBottomSheet<void>(
                                context: context,
                                useSafeArea: true,
                                showDragHandle: true,
                                builder: (_) => const PeopleConcernedSelector(),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: Sizes.lg,
                            ),
                            onTap: () => ref
                                .read(selectedReimbursementDueProvider.notifier)
                                .setValue(!paidForOthers),
                            leading: Icon(
                              Icons.group_outlined,
                              color: visual.accent,
                            ),
                            title: Text(
                              'Paid for other people',
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(
                                    color: visual.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            subtitle: Text(
                              paidForOthers ? 'Still due' : 'Paid back',
                              style: TextStyle(color: visual.textSecondary),
                            ),
                            trailing: AbsorbPointer(
                              child: Checkbox(
                                value: paidForOthers,
                                activeColor: visual.textPrimary,
                                checkColor: visual.solidSurface,
                                onChanged: (_) {},
                              ),
                            ),
                          ),
<<<<<<< Updated upstream
                        ),
                      ],
                      const Divider(height: 1),
                    ],
                    DetailsListTile(
                      title: "Date",
                      icon: Icons.calendar_month,
                      value: ref.watch(selectedDateProvider).formatEDMY(),
                      callback: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        if (Platform.isIOS) {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (_) => Container(
                              height: 300,
                              color: CupertinoDynamicColor.resolve(
                                CupertinoColors.secondarySystemBackground,
=======
                          const Divider(height: 1),
                          DetailsListTile(
                            title: 'Place',
                            icon: Icons.place_outlined,
                            value: place?.name ?? 'None',
                            callback: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              final choice = await showPlaceSearchSheet(
>>>>>>> Stashed changes
                                context,
                                canClear: place != null,
                              );
                              if (choice == null || !choice.apply) return;
                              ref
                                  .read(selectedPlaceProvider.notifier)
                                  .setPlace(choice.place);
                            },
                          ),
                        ],
                        const Divider(height: 1),
                      ],
                      DetailsListTile(
                        title: "Date",
                        icon: Icons.calendar_month,
                        value: ref.watch(selectedDateProvider).formatEDMY(),
                        callback: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          if (Platform.isIOS) {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (_) => Container(
                                height: 300,
                                color: CupertinoDynamicColor.resolve(
                                  CupertinoColors.secondarySystemBackground,
                                  context,
                                ),
                                child: CupertinoDatePicker(
                                  initialDateTime: ref.read(
                                    selectedDateProvider,
                                  ),
                                  minimumYear: 2015,
                                  maximumYear: 2050,
                                  mode: CupertinoDatePickerMode.date,
                                  onDateTimeChanged: (date) => ref
                                      .read(selectedDateProvider.notifier)
                                      .setDate(date),
                                ),
                              ),
                            );
                          } else {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: ref.read(selectedDateProvider),
                              firstDate: DateTime(2015),
                              lastDate: DateTime(2050),
                            );
                            if (pickedDate != null) {
                              ref
                                  .read(selectedDateProvider.notifier)
                                  .setDate(pickedDate);
                            }
                          }
                        },
                      ),
                      if (selectedType != TransactionType.adjustment)
                        RecurrenceListTile(
                          recurrencyEditingPermitted:
                              recurrencyEditingPermitted,
                          selectedTransaction: widget.transaction,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
