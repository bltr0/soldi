import 'package:flutter/material.dart';

import '../device.dart';
import '../theme/dashboard_visual_theme.dart';

/// Full-width call to action used in empty states.
class AccentButton extends StatelessWidget {
  const AccentButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: visual.navigationSelected,
          foregroundColor: visual.navigationFill.withValues(alpha: 1),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
          textStyle: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
