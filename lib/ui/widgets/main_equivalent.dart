import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/currency_provider.dart';
import '../../providers/fx_provider.dart';
import '../extensions.dart';
import 'blur_widget.dart';

/// "≈ 12.30 €": what [amount], held in [code], is worth in the main currency
/// on [date]. Shows nothing for main-currency amounts or when no rate is
/// known yet.
class MainEquivalent extends ConsumerWidget {
  const MainEquivalent({
    required this.amount,
    required this.code,
    required this.date,
    this.style,
    this.textAlign,
    super.key,
  });

  final num amount;
  final String code;
  final DateTime date;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final main = ref.watch(currencyStateProvider);
    if (code == main.code) return const SizedBox.shrink();
    final fx = ref.watch(fxTableProvider).value;
    final value = fx?.convert(amount, code, main.code, date);
    if (value == null) return const SizedBox.shrink();
    return BlurWidget(
      sigma: 10,
      child: Text(
        '≈ ${value.toCurrency(main.code)} ${main.symbol}',
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style ??
            Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}
