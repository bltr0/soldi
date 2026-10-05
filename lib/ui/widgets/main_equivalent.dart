import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/currency_provider.dart';
import '../../providers/fx_provider.dart';
import '../extensions.dart';
import '../theme/dashboard_visual_theme.dart';
import 'blur_widget.dart';

/// Shows [child] (an amount held in [code]) with what it is worth in the
/// main currency on [date] in grey on its left: "≈ 12.30 €  16,000 ₩".
/// Main-currency amounts, or ones without a known rate, show [child] alone.
class MainEquivalent extends ConsumerWidget {
  const MainEquivalent({
    required this.amount,
    required this.code,
    required this.date,
    required this.child,
    this.style,
    this.alwaysBlurred = false,
    this.ignoreBlur = false,
    super.key,
  });

  final num amount;
  final String code;
  final DateTime date;
  final Widget child;

  /// Style of [child]; the equivalent takes its size, in grey.
  final TextStyle? style;
  final bool alwaysBlurred;
  final bool ignoreBlur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final main = ref.watch(currencyStateProvider);
    if (code == main.code) return child;
    final value = ref
        .watch(fxTableProvider)
        .value
        ?.convert(amount, code, main.code, date);
    if (value == null) return child;
    final base = style ?? Theme.of(context).textTheme.labelLarge;
    final equivalent = BlurWidget(
      sigma: 10,
      ignore: ignoreBlur && !alwaysBlurred,
      always: alwaysBlurred,
      child: Text(
        '≈ ${value.toCurrency(main.code)} ${main.symbol}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base?.copyWith(
          color: context.dashboardTheme.textSecondary,
          fontSize: (base.fontSize ?? 14) * 0.85,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedWidth;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            bounded ? Flexible(child: equivalent) : equivalent,
            const SizedBox(width: 6),
            bounded ? Flexible(flex: 2, child: child) : child,
          ],
        );
      },
    );
  }
}
