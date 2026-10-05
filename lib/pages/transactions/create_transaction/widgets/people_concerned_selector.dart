import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/transactions_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';

/// Inline − n + stepper for how many people share an expense.
class PeopleConcernedStepper extends ConsumerWidget {
  const PeopleConcernedStepper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final value = ref.watch(selectedPeopleConcernedProvider);
    final notifier = ref.read(selectedPeopleConcernedProvider.notifier);

    Widget button(IconData icon, VoidCallback? onPressed) => IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: visual.textPrimary.withValues(alpha: 0.06),
        foregroundColor: visual.textPrimary,
        disabledForegroundColor: visual.textSecondary.withValues(alpha: 0.4),
      ),
      icon: Icon(icon, size: 18),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(Icons.remove_rounded, value > 1 ? notifier.decrement : null),
        SizedBox(
          width: 36,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              '$value',
              key: ValueKey(value),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: visual.textPrimary,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        button(Icons.add_rounded, notifier.increment),
      ],
    );
  }
}

/// Sheet version of [PeopleConcernedStepper].
class PeopleConcernedSelector extends StatelessWidget {
  const PeopleConcernedSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Sizes.xl,
          0,
          Sizes.xl,
          Sizes.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'People concerned',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: visual.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Sizes.xs),
            Text(
              'Your cost is the total divided equally.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: visual.textSecondary),
            ),
            const SizedBox(height: Sizes.xl),
            const PeopleConcernedStepper(),
          ],
        ),
      ),
    );
  }
}
