import 'dart:io';

import 'package:flutter/material.dart';
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../constants/style.dart";
import '../../../../model/currency_catalog.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../providers/transactions_provider.dart';
import '../../../../ui/formatters/decimal_text_input_formatter.dart';
import '../../../../ui/device.dart';

class AmountWidget extends ConsumerStatefulWidget {
  const AmountWidget(
    this.amountController, {
    this.autofocus = false,
    super.key,
  });

  final TextEditingController amountController;

  /// Opens the keyboard when the page appears. Used for new transactions.
  final bool autofocus;

  @override
  ConsumerState<AmountWidget> createState() => _AmountWidgetState();
}

class _AmountWidgetState extends ConsumerState<AmountWidget> {
  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(selectedTransactionTypeProvider);
    final currencyState = ref.watch(currencyStateProvider);
    final account = ref.watch(selectedBankAccountProvider);
    final symbol =
        account?.currencySymbol(currencyState.symbol) ?? currencyState.symbol;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.lg,
        vertical: Sizes.xs,
      ),
      child: TextField(
        controller: widget.amountController,
        decoration: InputDecoration(
          hintText: "0",
          border: InputBorder.none,
          prefixText: ' ',
          suffixText: symbol,
          suffixStyle: Theme.of(context).textTheme.headlineMedium!.copyWith(
            color: selectedType.toColor(
              brightness: Theme.of(context).brightness,
            ),
          ),
        ),
        keyboardType: TextInputType.numberWithOptions(
          decimal: true,
          // Leaving the default behaviour on Android which seems to be working as expeceted.
          signed: Platform.isAndroid,
        ),
        inputFormatters: [
          DecimalTextInputFormatter(
            decimalDigits: CurrencyCatalog.decimalsFor(
              account?.currencyCode(currencyState.code) ?? currencyState.code,
            ),
          ),
        ],
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        textAlign: TextAlign.center,
        cursorColor: grey1,
        style: TextStyle(
          color: selectedType.toColor(brightness: Theme.of(context).brightness),
          fontSize: 50,
          fontWeight: FontWeight.bold,
        ),
        onTapOutside: (_) {
          FocusScopeNode currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
      ),
    );
  }
}
