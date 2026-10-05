import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/bank_account.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/formatters/decimal_text_input_formatter.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/accent_button.dart';
import '../../../model/currency_catalog.dart';

class ReconcileResult {
  const ReconcileResult({required this.date, required this.balance});

  final DateTime date;
  final num balance;
}

Future<ReconcileResult?> showReconcileDialog(
  BuildContext context, {
  required BankAccount account,
  required List<LedgerEntry> ledger,
}) {
  return showDialog<ReconcileResult>(
    context: context,
    builder: (_) => _ReconcileDialog(account: account, ledger: ledger),
  );
}

class _ReconcileDialog extends ConsumerStatefulWidget {
  const _ReconcileDialog({required this.account, required this.ledger});

  final BankAccount account;
  final List<LedgerEntry> ledger;

  @override
  ConsumerState<_ReconcileDialog> createState() => _ReconcileDialogState();
}

class _ReconcileDialogState extends ConsumerState<_ReconcileDialog> {
  final _amountController = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _negative = false;

  DateTime? get _firstDay => widget.ledger.isEmpty
      ? null
      : DateUtils.dateOnly(widget.ledger.first.transaction.date);

  num? get _target {
    final text = _amountController.text;
    if (text.isEmpty) return null;
    final value = num.tryParse(text.replaceAll(',', '.'));
    if (value == null) return null;
    return _negative ? -value : value;
  }

  /// Balance recorded at the end of [_date], from the loaded ledger.
  num get _recordedBalance {
    final end = DateTime(_date.year, _date.month, _date.day, 23, 59, 59);
    num balance = widget.account.startingValue;
    for (final entry in widget.ledger) {
      if (entry.transaction.date.isAfter(end)) break;
      balance = entry.balanceAfter;
    }
    return balance;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final symbol = widget.account.currencySymbol(
      ref.watch(currencyStateProvider).symbol,
    );
    final code = widget.account.currencyCode(
      ref.watch(currencyStateProvider).code,
    );
    final textTheme = Theme.of(context).textTheme;
    final target = _target;
    final recorded = _recordedBalance;
    final difference = target == null ? null : target - recorded;
    final firstDay = _firstDay;

    return Dialog(
      backgroundColor: visual.solidSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: visual.hairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set balance on a date',
                style: textTheme.titleLarge?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Sizes.sm),
              Text(
                'The balance at the end of the chosen day will match this '
                'amount. An adjustment is added on that day, and every later '
                'balance shifts with it.',
                style: textTheme.bodySmall?.copyWith(
                  color: visual.textSecondary,
                ),
              ),
              const SizedBox(height: Sizes.lg),
              Material(
                color: visual.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.all(Sizes.md),
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded, color: visual.accent),
                        const SizedBox(width: Sizes.md),
                        Expanded(
                          child: Text(
                            _date.formatEDMY(),
                            style: textTheme.titleSmall?.copyWith(
                              color: visual.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: visual.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (firstDay != null) ...[
                const SizedBox(height: Sizes.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => _date = firstDay.subtract(const Duration(days: 1)),
                    ),
                    icon: const Icon(Icons.first_page_rounded, size: 18),
                    label: const Text('Day before the first transaction'),
                  ),
                ),
              ],
              const SizedBox(height: Sizes.sm),
              TextField(
                controller: _amountController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [DecimalTextInputFormatter(
                  decimalDigits: CurrencyCatalog.decimalsFor(code),
                )],
                style: textTheme.headlineSmall?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  labelText: 'Balance at end of day',
                  prefixIcon: IconButton(
                    tooltip: 'Toggle sign',
                    onPressed: () => setState(() => _negative = !_negative),
                    icon: Text(
                      _negative ? '−' : '+',
                      style: textTheme.titleLarge?.copyWith(
                        color: _negative ? visual.negative : visual.positive,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  suffixText: symbol,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              const SizedBox(height: Sizes.md),
              BlurWidget(
                always: widget.account.alwaysBlurred,
                child: Text(
                  difference == null
                      ? 'Recorded on that day: ${recorded.toCurrency(code)} $symbol'
                      : 'Recorded ${recorded.toCurrency(code)} $symbol → '
                            'adjustment of ${difference > 0 ? '+' : ''}${difference.toCurrency(code)} $symbol',
                  style: textTheme.bodySmall?.copyWith(
                    color: visual.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: Sizes.xl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: Sizes.md),
                  Expanded(
                    child: AccentButton(
                      label: 'Apply',
                      icon: Icons.check_rounded,
                      onPressed: target == null
                          ? null
                          : () => Navigator.of(context).pop(
                              ReconcileResult(date: _date, balance: target),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
