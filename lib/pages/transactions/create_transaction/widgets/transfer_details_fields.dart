import 'package:flutter/material.dart';

import '../../../../model/transaction.dart';
import '../../../../ui/device.dart';
import '../../../../ui/extensions.dart';
import '../../../../ui/formatters/decimal_text_input_formatter.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/segmented_pill.dart';
import '../../../../model/currency_catalog.dart';

enum TransferFeeMode { amount, percent }

/// Fee and received-amount inputs of a transfer.
///
/// The fee is always charged in the sending account's currency and never
/// reaches the receiver. When the two accounts use different currencies the
/// user also types what the receiver got; nothing is converted.
class TransferDetailsController extends ChangeNotifier {
  TransferDetailsController({Transaction? initial}) {
    if (initial != null && initial.type == TransactionType.transfer) {
      final percent = initial.feePercent;
      if (percent != null) {
        mode = TransferFeeMode.percent;
        feeController.text = _plain(percent);
      } else if ((initial.fee ?? 0) > 0) {
        feeController.text = initial.fee!.toCurrency();
      }
      if (initial.amountTransfer != null) {
        receivedController.text = initial.amountTransfer!.toCurrency();
      }
    }
    feeController.addListener(notifyListeners);
    receivedController.addListener(notifyListeners);
  }

  final feeController = TextEditingController();
  final receivedController = TextEditingController();
  TransferFeeMode mode = TransferFeeMode.amount;

  static String _plain(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  static num? _parse(String text) {
    final clean = text.trim().replaceAll(',', '.');
    if (clean.isEmpty) return null;
    return num.tryParse(clean);
  }

  void setMode(TransferFeeMode value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
  }

  /// The number typed in the fee field (an amount or a percentage).
  num? get feeInput => _parse(feeController.text);

  /// Percentage typed by the user, when the fee is entered as one.
  num? get feePercent => mode == TransferFeeMode.percent ? feeInput : null;

  /// Fee in the sender's currency for a transfer of [amount].
  num fee(num? amount) {
    final input = feeInput;
    if (input == null || input <= 0) return 0;
    if (mode == TransferFeeMode.amount) return input;
    if (amount == null) return 0;
    return double.parse((amount * input / 100).toStringAsFixed(2));
  }

  /// Amount typed for the receiving account, in its currency.
  num? get received => _parse(receivedController.text);

  /// Null when the fee field is fine, otherwise why it is not.
  String? feeError() {
    final input = feeInput;
    if (feeController.text.trim().isEmpty) return null;
    if (input == null || input < 0) return 'Enter a valid fee';
    if (mode == TransferFeeMode.percent && input >= 100) {
      return 'A fee must be under 100%';
    }
    return null;
  }

  /// Whether the inputs can be saved for a transfer between two accounts
  /// whose currencies match or not ([crossCurrency]).
  bool isValid({required bool crossCurrency}) {
    if (feeError() != null) return false;
    if (crossCurrency) {
      final value = received;
      if (value == null || value <= 0) return false;
    }
    return true;
  }

  /// Values to store on the transaction for a transfer of [amount].
  ({num? fee, num? feePercent, num? amountTransfer}) values({
    required num? amount,
    required bool crossCurrency,
  }) {
    final feeValue = fee(amount);
    return (
      fee: feeValue > 0 ? feeValue : null,
      feePercent: feeValue > 0 ? feePercent : null,
      amountTransfer: crossCurrency ? received : null,
    );
  }

  @override
  void dispose() {
    feeController.dispose();
    receivedController.dispose();
    super.dispose();
  }
}

/// Fee (as a % or an amount) and, between currencies, the amount received.
class TransferDetailsFields extends StatelessWidget {
  const TransferDetailsFields({
    required this.controller,
    required this.amount,
    required this.senderSymbol,
    required this.receiverSymbol,
    this.senderCode,
    this.receiverCode,
    required this.crossCurrency,
    this.senderName,
    this.receiverName,
    this.padding = const EdgeInsets.symmetric(horizontal: Sizes.lg),
    super.key,
  });

  final TransferDetailsController controller;

  /// Amount sent, in the sender's currency (before the fee).
  final num? amount;
  final String senderSymbol;
  final String receiverSymbol;
  final String? senderCode;
  final String? receiverCode;
  final bool crossCurrency;
  final String? senderName;
  final String? receiverName;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final fee = controller.fee(amount);
    final total = (amount ?? 0) + fee;
    final from = senderName ?? 'sender';
    final to = receiverName ?? 'receiver';

    InputDecoration decoration({String? hint, String? suffix}) =>
        InputDecoration(
          isDense: true,
          hintText: hint,
          suffixText: suffix,
          filled: true,
          fillColor: visual.textPrimary.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.all(Sizes.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        );

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(left: Sizes.xs, bottom: Sizes.xs),
      child: Text(
        text.toUpperCase(),
        style: textTheme.labelSmall?.copyWith(
          color: visual.textSecondary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );

    final hintStyle = textTheme.bodySmall?.copyWith(
      color: visual.textSecondary,
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (crossCurrency) ...[
            label('Received by $to'),
            TextField(
              controller: controller.receivedController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                DecimalTextInputFormatter(
                  decimalDigits: CurrencyCatalog.decimalsFor(receiverCode),
                ),
              ],
              decoration: decoration(
                hint: 'Amount that arrived',
                suffix: receiverSymbol,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.xs,
                Sizes.xs,
                Sizes.xs,
                0,
              ),
              child: Text(
                'Different currencies: enter what $to actually received. '
                'No exchange rate is applied.',
                style: hintStyle,
              ),
            ),
            const SizedBox(height: Sizes.lg),
          ],
          label('Transfer fee'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.feeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    DecimalTextInputFormatter(decimalDigits: 4),
                  ],
                  decoration: decoration(
                    hint: '0',
                    suffix: controller.mode == TransferFeeMode.percent
                        ? '%'
                        : senderSymbol,
                  ).copyWith(errorText: controller.feeError()),
                ),
              ),
              const SizedBox(width: Sizes.sm),
              SizedBox(
                width: 112,
                child: SegmentedPill<TransferFeeMode>(
                  height: 44,
                  options: {
                    TransferFeeMode.amount: senderSymbol,
                    TransferFeeMode.percent: '%',
                  },
                  selected: controller.mode,
                  onChanged: controller.setMode,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Sizes.xs,
              Sizes.xs,
              Sizes.xs,
              0,
            ),
            child: Text(
              fee > 0
                  ? 'Fee ${fee.toCurrency(senderCode)} $senderSymbol · '
                        '$from pays ${total.toCurrency(senderCode)} $senderSymbol in total'
                  : 'Optional. Charged to $from, in $senderSymbol.',
              style: hintStyle,
            ),
          ),
        ],
      ),
    );
  }
}
