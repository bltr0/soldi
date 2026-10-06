import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/currency_provider.dart';

import '../../../../model/category_transaction.dart';
import '../../../../ui/extensions.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/blur_widget.dart';
import '../../../../ui/device.dart';

class CategoryLabel extends ConsumerWidget {
  const CategoryLabel({
    super.key,
    required this.category,
    required this.amount,
    required this.total,
  });

  final CategoryTransaction category;
  final double amount;
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyState = ref.watch(currencyStateProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.dashboardTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: Sizes.sm),
        BlurWidget(
          sigma: 8,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text:
                      "${amount.toCurrency(currencyState.code)} ${currencyState.symbol}  ",
                  style: TextStyle(color: context.dashboardTheme.textPrimary),
                ),
                TextSpan(
                  text: "${((amount / total) * 100).abs().toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: context.dashboardTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
