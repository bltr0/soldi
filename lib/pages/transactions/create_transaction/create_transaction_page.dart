import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/style.dart';
import '../../../model/recurring_transaction.dart';
import '../../../model/transaction.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/places_provider.dart';
import '../../../providers/recurring_transactions_provider.dart';
import '../../../providers/places_provider.dart';
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
import 'widgets/place_search_sheet.dart';
import 'widgets/recurrence_list_tile.dart';
import 'widgets/transfer_details_fields.dart';

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
  late final TransferDetailsController _transfer;
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
  late final int? _originalPlaceId;
  late final bool _originalRecurring;
  late final Recurrence _originalInterval;
  late final DateTime? _originalEndDate;

  @override
  void initState() {
    super.initState();
    _transfer = TransferDetailsController(initial: widget.transaction)
      ..addListener(_onTransferChanged);
    if (widget.transaction != null) {
      recurrencyEditingPermitted = !widget.transaction!.recurring;
      amountController.text = widget.transaction?.amount.toCurrency() ?? '';
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
    _originalPlaceId = ref.read(selectedPlaceProvider)?.id;
    _originalRecurring = ref.read(selectedRecurringPayProvider);
    _originalInterval = ref.read(intervalProvider);
    _originalEndDate = ref.read(endDateProvider);
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    _transfer.dispose();
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

  void _onTransferChanged() {
    if (mounted) setState(() {});
  }

  /// True when the two accounts of a transfer hold different currencies, so
  /// the amount received has to be typed separately.
  bool get _isCrossCurrency {
    final main = ref.read(currencyStateProvider).code;
    final from = ref.read(selectedBankAccountProvider);
    final to = ref.read(bankAccountTransferProvider);
    if (from == null || to == null) return false;
    return from.currencyCode(main) != to.currencyCode(main);
  }

  ({num? fee, num? feePercent, num? amountTransfer}) _transferValues() =>
      _transfer.values(
        amount: _parsedAmount(),
        crossCurrency: _isCrossCurrency,
      );

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
        return ref.read(bankAccountTransferProvider) != null &&
            _transfer.isValid(crossCurrency: _isCrossCurrency);
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
    if (selectedType == TransactionType.transfer) {
      final original = widget.transaction;
      final values = _transferValues();
      if (values.fee != original?.fee ||
          values.feePercent != original?.feePercent ||
          values.amountTransfer != original?.amountTransfer) {
        return true;
      }
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
    if (selectedType == TransactionType.expense &&
        ref.read(selectedPlaceProvider)?.id != _originalPlaceId) {
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
    final transfer = _transferValues();

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
                        recurringTransactionId: value.id,
                        fee: transfer.fee,
                        feePercent: transfer.feePercent,
                        amountTransfer: transfer.amountTransfer,
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
                recurringTransactionId:
                    widget.transaction!.idRecurringTransaction,
                fee: transfer.fee,
                feePercent: transfer.feePercent,
                amountTransfer: transfer.amountTransfer,
              )
              .whenComplete(() => _refreshAccountAndNavigateBack());
        }
      } else {
        if (selectedType == TransactionType.transfer) {
          if (ref.read(bankAccountTransferProvider) != null) {
            await ref
                .read(transactionsProvider.notifier)
                .create(
                  amount,
                  noteController.text,
                  fee: transfer.fee,
                  feePercent: transfer.feePercent,
                  amountTransfer: transfer.amountTransfer,
                )
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
    final mainCurrency = ref.watch(currencyStateProvider);
    final fromAccount = ref.watch(selectedBankAccountProvider);
    final toAccount = ref.watch(bankAccountTransferProvider);
    ref.watch(selectedCategoryProvider);
    ref.watch(selectedDateProvider);
    ref.watch(selectedPeopleConcernedProvider);
    final paidForOthers = ref.watch(selectedReimbursementDueProvider);
    final place = ref.watch(selectedPlaceProvider);
    ref.watch(selectedRecurringPayProvider);
    ref.watch(intervalProvider);
    ref.watch(endDateProvider);

    ref.listen(selectedTransactionTypeProvider, (previous, next) {
      _syncExpensePrefix(next);
    });

    final isSaveEnabled = _canSave(selectedType);

    final arrowColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

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
        persistentFooterDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 5.0,
              offset: const Offset(0, -1.0),
            ),
          ],
        ),
        persistentFooterButtons: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Sizes.sm,
              Sizes.xs,
              Sizes.sm,
              Sizes.sm,
            ),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                boxShadow: [defaultShadow],
                borderRadius: BorderRadius.circular(Sizes.borderRadius),
              ),
              child: ElevatedButton(
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
              AmountSection(amountController),
              if (selectedType == TransactionType.transfer)
                Container(
                  color: Theme.of(context).colorScheme.surface,
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
                    crossCurrency: _isCrossCurrency,
                    senderName: fromAccount?.name,
                    receiverName: toAccount?.name,
                  ),
                ),
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
                                  topLeft: Radius.circular(Sizes.borderRadius),
                                  topRight: Radius.circular(Sizes.borderRadius),
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
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          title: Text(
                            'Paid for other people',
                            style: Theme.of(context).textTheme.titleMedium!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          subtitle: Text(
                            paidForOthers ? 'Still due' : 'Paid back',
                          ),
                          trailing: AbsorbPointer(
                            child: Checkbox(
                              value: paidForOthers,
                              activeColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              checkColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                              onChanged: (_) {},
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        DetailsListTile(
                          title: 'Place',
                          icon: Icons.place_outlined,
                          value: place?.name ?? 'None',
                          callback: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            final choice = await showPlaceSearchSheet(
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
                                initialDateTime: ref.read(selectedDateProvider),
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
                        recurrencyEditingPermitted: recurrencyEditingPermitted,
                        selectedTransaction: widget.transaction,
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
