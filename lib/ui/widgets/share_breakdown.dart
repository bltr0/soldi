import 'package:flutter/material.dart';

import 'unconverted_amount.dart';
import '../device.dart';
import '../theme/dashboard_visual_theme.dart';
import 'blur_widget.dart';

class ShareSlice {
  const ShareSlice({
    required this.label,
    required this.value,
    required this.color,
    required this.amountText,
    this.icon,
  });

  final String label;

  /// Size of the slice; its sign is ignored.
  final num value;
  final Color color;
  final String amountText;
  final IconData? icon;
}

/// Part-to-whole view: a headline amount over one segmented bar where each
/// slice is a share of the total. Tapping a slice focuses it; tapping it
/// again (or the headline) goes back to the total.
class ShareBreakdown extends StatelessWidget {
  const ShareBreakdown({
    required this.slices,
    required this.totalText,
    required this.selectedIndex,
    required this.onSelect,
    this.totalLabel = 'Total',
    this.amountColor,
    this.unconverted = false,
    super.key,
  });

  final List<ShareSlice> slices;
  final String totalText;
  final String totalLabel;
  final int? selectedIndex;
  final ValueChanged<int?> onSelect;

  /// Colour of the headline amount, e.g. green for income.
  final Color? amountColor;

  /// The total adds some foreign amounts 1:1.
  final bool unconverted;

  static const _barHeight = 14.0;
  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);
    final total = slices.fold<num>(0, (sum, s) => sum + s.value.abs());
    final index = selectedIndex != null && selectedIndex! < slices.length
        ? selectedIndex
        : null;
    final focused = index == null ? null : slices[index];
    final share = focused == null || total == 0
        ? null
        : focused.value.abs() / total * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(null),
          child: AnimatedSwitcher(
            duration: duration,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Row(
              key: ValueKey(index),
              children: [
                if (focused != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: focused.color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      focused.icon ?? Icons.circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: Sizes.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        focused == null
                            ? totalLabel
                            : '${focused.label} · ${share!.toStringAsFixed(share < 10 ? 1 : 0)}%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          color: visual.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      UnconvertedAmount(
                        unconverted: unconverted && focused == null,
                        child: BlurWidget(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              focused?.amountText ?? totalText,
                              style: textTheme.headlineMedium?.copyWith(
                                color: amountColor ?? visual.textPrimary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Sizes.md),
        SizedBox(
          height: _barHeight + 6,
          child: Row(
            children: [
              for (final (i, slice) in slices.indexed) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(
                  flex: total == 0
                      ? 1
                      : (slice.value.abs() / total * 10000).round().clamp(
                          1,
                          10000,
                        ),
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: '${slice.label}, ${slice.amountText}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i == index ? null : i),
                      child: Center(
                        child: AnimatedContainer(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          height: i == index ? _barHeight + 6 : _barHeight,
                          decoration: BoxDecoration(
                            color: index == null || i == index
                                ? slice.color
                                : slice.color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(i == 0 ? 7 : 2),
                              right: Radius.circular(
                                i == slices.length - 1 ? 7 : 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
