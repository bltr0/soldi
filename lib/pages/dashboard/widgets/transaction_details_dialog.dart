import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/bank_account.dart';
import '../../../model/place.dart';
import '../../../model/transaction.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../services/database/repositories/place_repository.dart';
import '../../transactions/create_transaction/widgets/place_search_sheet.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/formatters/decimal_text_input_formatter.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/accent_button.dart';
import '../../../ui/widgets/segmented_pill.dart';

Future<void> showTransactionDetailsDialog(
  BuildContext context,
  Transaction transaction,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => TransactionDetailsDialog(transaction: transaction),
  );
}

/// Edits everything about a transaction except its category.
class TransactionDetailsDialog extends ConsumerStatefulWidget {
  const TransactionDetailsDialog({required this.transaction, super.key});

  final Transaction transaction;

  @override
  ConsumerState<TransactionDetailsDialog> createState() =>
      _TransactionDetailsDialogState();
}

class _TransactionDetailsDialogState
    extends ConsumerState<TransactionDetailsDialog> {
  late final TextEditingController _noteController;
  late final TextEditingController _amountController;
  late TransactionType _type;
  late DateTime _date;
  late int _accountId;
  int? _toAccountId;
  late int _people;
  late bool _reimbursementDue;
  int? _placeId;
  Place? _place;
  bool _saving = false;

  Transaction get _original => widget.transaction;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: _original.note ?? '');
    _amountController = TextEditingController(
      text: _original.amount.toCurrency(),
    );
    _type = _original.type;
    _date = _original.date;
    _accountId = _original.idBankAccount;
    _toAccountId = _original.idBankAccountTransfer;
    _people = _original.peopleConcerned;
    _reimbursementDue = _original.reimbursementDue;
    _placeId = _original.idPlace;
    final placeId = _placeId;
    if (placeId != null) {
      Future.microtask(() async {
        final place = await ref
            .read(placeRepositoryProvider)
            .selectById(placeId);
        if (mounted) setState(() => _place = place);
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  num? get _amount => num.tryParse(_amountController.text.replaceAll(',', '.'));

  bool get _isValid {
    final amount = _amount;
    if (amount == null || amount == 0) return false;
    if (_type != TransactionType.adjustment && amount < 0) return false;
    if (_type == TransactionType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      return false;
    }
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(
      () => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
        _date.second,
      ),
    );
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    final keepCategory =
        _type == _original.type &&
        _type != TransactionType.transfer &&
        _type != TransactionType.adjustment;
    final updated = _original.copy(
      note: _noteController.text.trim(),
      amount: _amount,
      date: _date,
      type: _type,
      idBankAccount: _accountId,
      idBankAccountTransfer: _type == TransactionType.transfer
          ? _toAccountId
          : null,
      idCategory: keepCategory ? _original.idCategory : null,
      peopleConcerned: _type == TransactionType.expense ? _people : 1,
      reimbursementDue: _type == TransactionType.expense && _reimbursementDue,
      idPlace: _type == TransactionType.expense ? _placeId : null,
    );
    await ref.read(transactionsProvider.notifier).saveTransaction(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = ref.watch(currencyStateProvider);
    final accounts = (ref.watch(accountsProvider).value ?? const [])
        .where(
          (a) =>
              a.deletedAt == null || a.id == _accountId || a.id == _toAccountId,
        )
        .toList();

    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final inset = math.max(
      size.shortestSide * 0.1,
      math.max(safe.top, safe.bottom) + Sizes.sm,
    );
    final horizontal = math.max(inset, (size.width - 720) / 2);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontal,
        vertical: inset,
      ),
      backgroundColor: visual.solidSurface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: visual.hairline),
      ),
      child: SizedBox.expand(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.xl,
                Sizes.lg,
                Sizes.sm,
                Sizes.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transaction details',
                      style: textTheme.titleLarge?.copyWith(
                        color: visual.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: visual.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: visual.hairline),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Sizes.xl),
                children: [
                  if (_original.type != TransactionType.adjustment) ...[
                    SegmentedPill<TransactionType>(
                      height: 40,
                      options: const {
                        TransactionType.income: 'Income',
                        TransactionType.expense: 'Expense',
                        TransactionType.transfer: 'Transfer',
                      },
                      selected: _type,
                      onChanged: (t) => setState(() => _type = t),
                    ),
                    const SizedBox(height: Sizes.lg),
                  ],
                  _field(
                    context,
                    label: 'Description',
                    child: TextField(
                      controller: _noteController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration(
                        context,
                        hint: 'Add a description',
                      ),
                    ),
                  ),
                  _field(
                    context,
                    label: 'Amount',
                    child: TextField(
                      controller: _amountController,
                      onChanged: (_) => setState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        DecimalTextInputFormatter(decimalDigits: 2),
                      ],
                      style: textTheme.titleMedium?.copyWith(
                        color: _type.toColor(
                          brightness: Theme.of(context).brightness,
                        ),
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: _decoration(
                        context,
                        hint: '0.00',
                      ).copyWith(suffixText: currency.symbol),
                    ),
                  ),
                  _field(
                    context,
                    label: 'Date',
                    child: _Tappable(
                      icon: Icons.event_rounded,
                      text: _date.formatEDMY(),
                      onTap: _pickDate,
                    ),
                  ),
                  _field(
                    context,
                    label: _type == TransactionType.transfer
                        ? 'From account'
                        : 'Account',
                    child: _accountDropdown(
                      context,
                      accounts,
                      _accountId,
                      (id) => setState(() => _accountId = id),
                    ),
                  ),
                  if (_type == TransactionType.transfer)
                    _field(
                      context,
                      label: 'To account',
                      child: _accountDropdown(
                        context,
                        accounts,
                        _toAccountId,
                        (id) => setState(() => _toAccountId = id),
                      ),
                    ),
                  if (_type == TransactionType.expense) ...[
                    _field(
                      context,
                      label: 'People concerned',
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: _people > 1
                                ? () => setState(() => _people--)
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Expanded(
                            child: Text(
                              '$_people',
                              textAlign: TextAlign.center,
                              style: textTheme.titleLarge?.copyWith(
                                color: visual.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () => setState(() => _people++),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _reimbursementDue,
                      activeColor: visual.textPrimary,
                      checkColor: visual.solidSurface,
                      title: Text(
                        'Paid for other people',
                        style: textTheme.titleSmall?.copyWith(
                          color: visual.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _reimbursementDue ? 'Still due' : 'Paid back',
                        style: textTheme.bodySmall?.copyWith(
                          color: visual.textSecondary,
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _reimbursementDue = value ?? false),
                    ),
                    _field(
                      context,
                      label: 'Place',
                      child: _Tappable(
                        icon: Icons.place_outlined,
                        text:
                            _place?.name ??
                            (_placeId == null ? 'Add a place' : 'Saved place'),
                        onTap: () async {
                          final choice = await showPlaceSearchSheet(
                            context,
                            canClear: _placeId != null,
                          );
                          if (choice == null || !choice.apply || !mounted) {
                            return;
                          }
                          setState(() {
                            _place = choice.place;
                            _placeId = choice.place?.id;
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: visual.hairline),
            Padding(
              padding: const EdgeInsets.all(Sizes.lg),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: Sizes.md),
                  Expanded(
                    flex: 2,
                    child: AccentButton(
                      label: 'Save',
                      icon: Icons.check_rounded,
                      onPressed: _isValid && !_saving ? _save : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    final visual = context.dashboardTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Sizes.xs, bottom: Sizes.xs),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: visual.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  InputDecoration _decoration(BuildContext context, {String? hint}) {
    final visual = context.dashboardTheme;
    return InputDecoration(
      isDense: true,
      hintText: hint,
      filled: true,
      fillColor: visual.textPrimary.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.all(Sizes.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _accountDropdown(
    BuildContext context,
    List<BankAccount> accounts,
    int? value,
    ValueChanged<int> onChanged,
  ) {
    return DropdownButtonFormField<int>(
      initialValue: accounts.any((a) => a.id == value) ? value : null,
      isExpanded: true,
      decoration: _decoration(context, hint: 'Choose an account'),
      items: [
        for (final account in accounts)
          DropdownMenuItem(value: account.id, child: Text(account.name)),
      ],
      onChanged: (id) {
        if (id != null) onChanged(id);
      },
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Material(
      color: visual.textPrimary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Sizes.md),
          child: Row(
            children: [
              Icon(icon, size: 20, color: visual.accent),
              const SizedBox(width: Sizes.md),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: visual.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: visual.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
