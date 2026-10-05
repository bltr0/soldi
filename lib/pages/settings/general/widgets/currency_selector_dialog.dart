import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../model/currency.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';

class CurrencySelectorDialog {
  static void selectCurrencyDialog(
    BuildContext context,
    Currency currency,
    Future<List<Currency>> currencies,
  ) {
    final visual = context.dashboardTheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: visual.solidSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) => FutureBuilder<List<Currency>>(
            future: currencies,
            builder: (context, snapshot) {
              final textTheme = Theme.of(context).textTheme;
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Currencies could not be loaded.',
                    style: TextStyle(color: visual.textSecondary),
                  ),
                );
              }
              final list = snapshot.data;
              if (list == null) {
                return Center(
                  child: CircularProgressIndicator(color: visual.accent),
                );
              }
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  Sizes.lg,
                  0,
                  Sizes.lg,
                  Sizes.xl,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: Sizes.sm,
                      bottom: Sizes.md,
                    ),
                    child: Text(
                      'Main currency',
                      style: textTheme.titleLarge?.copyWith(
                        color: visual.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final item in list)
                    _CurrencyRow(
                      currency: item,
                      selected: item.code == currency.code,
                      onTap: () {
                        ref
                            .read(currencyStateProvider.notifier)
                            .setSelectedCurrency(item);
                        Navigator.pop(context);
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final Currency currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sizes.xs),
      child: Material(
        color: selected
            ? visual.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Sizes.sm),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? visual.accent
                        : visual.textPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    currency.symbol,
                    style: textTheme.titleMedium?.copyWith(
                      color: selected ? Colors.white : visual.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: Sizes.md),
                Expanded(
                  child: Text(
                    currency.name,
                    style: textTheme.titleSmall?.copyWith(
                      color: visual.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  currency.code,
                  style: textTheme.labelLarge?.copyWith(
                    color: visual.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: Sizes.sm),
                  Icon(Icons.check_rounded, color: visual.accent, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
