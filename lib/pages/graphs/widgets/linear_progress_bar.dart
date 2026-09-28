import 'package:flutter/material.dart';

import '../../../constants/constants.dart';
import '../../../ui/device.dart';

enum BarType { account, category }

class LinearProgressBar extends StatelessWidget {
  const LinearProgressBar({
    super.key,
    required this.type,
    required this.amount,
    required this.total,
    required this.colorIndex,
  });

  final BarType type;
  final num amount;
  final num total;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;
    final colorList = isDarkMode
        ? (type == BarType.account
              ? darkAccountColorList
              : darkCategoryColorList)
        : (type == BarType.account ? accountColorList : categoryColorList);

    final color = colorList[colorIndex % colorList.length];
    final value = amount != 0 && total != 0
        ? (amount / total).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) => LinearProgressIndicator(
        value: current,
        minHeight: 10,
        backgroundColor: color.withValues(alpha: 0.18),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        borderRadius: BorderRadius.circular(Sizes.borderRadiusLarge),
      ),
    );
  }
}
