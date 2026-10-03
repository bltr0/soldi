import 'package:flutter/material.dart';

import '../theme/dashboard_visual_theme.dart';
import 'atmospheric_background.dart';

/// Gives a pushed page the same atmosphere as the main pages: the gradient
/// backdrop, a transparent app bar and hairline dividers. Pages keep using
/// their own Scaffold; it just becomes see-through.
class ThemedPage extends StatelessWidget {
  const ThemedPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final visual = context.dashboardTheme;
    return AtmosphericBackground(
      child: Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          dividerTheme: DividerThemeData(color: visual.hairline, space: 1),
          appBarTheme: base.appBarTheme.copyWith(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: visual.textPrimary,
            iconTheme: IconThemeData(color: visual.textPrimary),
            actionsIconTheme: IconThemeData(color: visual.textPrimary),
            titleTextStyle: base.textTheme.titleLarge?.copyWith(
              color: visual.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}
