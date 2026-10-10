import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/transactions_provider.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';

/// Inline − n + stepper for how many people share an expense, bound to the
/// transaction being created.
class PeopleConcernedStepper extends ConsumerWidget {
  const PeopleConcernedStepper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(selectedPeopleConcernedProvider.notifier);
    return PeopleStepper(
      value: ref.watch(selectedPeopleConcernedProvider),
      onDecrement: notifier.decrement,
      onIncrement: notifier.increment,
    );
  }
}

/// Inline − n + stepper. The minus button is disabled at one person.
class PeopleStepper extends StatelessWidget {
  const PeopleStepper({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    super.key,
  });

  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;

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
        button(Icons.remove_rounded, value > 1 ? onDecrement : null),
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
        button(Icons.add_rounded, onIncrement),
      ],
    );
  }
}
