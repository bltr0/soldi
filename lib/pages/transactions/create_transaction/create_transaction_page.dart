import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/recurring_transaction.dart';
import '../../../model/transaction.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/places_provider.dart';
import '../../../providers/recurring_transactions_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/accent_button.dart';
import '../../../ui/widgets/settings_tiles.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';
import 'widgets/account_selector.dart';
import 'widgets/amount_section.dart';
import 'widgets/category_selector.dart';
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
      amountController.text = widget.transaction!.amount.toCurrency(
        ref
            .read(accountsProvider)
            .value
            ?.firstWhereOrNull((a) => a.id == widget.transaction!.idBankAccount)
            ?.currencyCode(ref.read(currencyStateProvider).code),
      );
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
    final visual = context.dashboardTheme;
    final isEditing = widget.transaction != null;
    final date = ref.watch(selectedDateProvider);

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
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(isEditing ? "Edit transaction" : "New transaction"),
          actions: [
            if (isEditing) ...[
              IconButton(
                tooltip: 'Duplicate',
                icon: Icon(Icons.copy_rounded, color: visual.textPrimary),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => DuplicateTransactionDialog(
                    transaction: widget.transaction!,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded, color: visual.negative),
                onPressed: _deleteTransaction,
              ),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Sizes.lg,
              Sizes.sm,
              Sizes.lg,
              Sizes.md + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: AccentButton(
              label: isEditing ? 'Save changes' : 'Add transaction',
              icon: isEditing ? Icons.check_rounded : Icons.add_rounded,
              onPressed: isSaveEnabled ? _createOrUpdateTransaction : null,
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
              child: AmountSection(amountController),
            ),
            if (selectedType == TransactionType.transfer) ...[
              const SizedBox(height: Sizes.lg),
              TonalGlassSurface(
                radius: 24,
                pressScale: 1,
                padding: const EdgeInsets.symmetric(vertical: Sizes.lg),
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
            ],
            const SizedBox(height: Sizes.lg),
            SettingsGroup(
              children: [
                LabelListTile(noteController),
                if (selectedType != TransactionType.transfer)
                  DetailsListTile(
                    title: "Account",
                    icon: Icons.account_balance_wallet_rounded,
                    value: fromAccount?.name ?? 'Choose',
                    callback: () => showAccountSelector(context),
                  ),
                if (selectedType == TransactionType.income ||
                    selectedType == TransactionType.expense)
                  DetailsListTile(
                    title: "Category",
                    icon: Icons.category_rounded,
                    value:
                        ref.watch(selectedCategoryProvider)?.name ??
                        "Uncategorized",
                    callback: () => showCategorySelector(context),
                  ),
                DetailsListTile(
                  title: "Date",
                  icon: Icons.calendar_month_rounded,
                  value: date.isSameDay(DateTime.now())
                      ? 'Today'
                      : date.formatEDMY(),
                  callback: _pickDate,
                ),
              ],
            ),
            if (selectedType == TransactionType.expense) ...[
              const SizedBox(height: Sizes.lg),
              SettingsGroup(
                title: 'Shared & place',
                children: [
                  SettingsTile(
                    icon: Icons.group_rounded,
                    title: 'People concerned',
                    subtitle: 'Your share is the total divided equally',
                    trailing: const PeopleConcernedStepper(),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.volunteer_activism_rounded,
                    title: 'Paid for other people',
                    subtitle: paidForOthers
                        ? 'Still due, shown in Paybacks'
                        : 'Nothing to get back',
                    value: paidForOthers,
                    onChanged: (value) => ref
                        .read(selectedReimbursementDueProvider.notifier)
                        .setValue(value),
                  ),
                  DetailsListTile(
                    title: 'Place',
                    icon: Icons.place_rounded,
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
              ),
            ],
            if (selectedType != TransactionType.adjustment) ...[
              const SizedBox(height: Sizes.lg),
              SettingsGroup(
                children: [
                  RecurrenceListTile(
                    recurrencyEditingPermitted: recurrencyEditingPermitted,
                    selectedTransaction: widget.transaction,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: ref.read(selectedDateProvider),
      firstDate: DateTime(2015),
      lastDate: DateTime(2050),
    );
    if (picked == null) return;
    final current = ref.read(selectedDateProvider);
    ref
        .read(selectedDateProvider.notifier)
        .setDate(
          DateTime(
            picked.year,
            picked.month,
            picked.day,
            current.hour,
            current.minute,
            current.second,
          ),
        );
  }
}
