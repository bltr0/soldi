import 'package:flutter/material.dart';

import '../theme/dashboard_visual_theme.dart';

class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.height = 44,
    super.key,
  });

  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final entries = options.entries.toList();
    final index = entries.indexWhere((e) => e.key == selected);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w700);

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: visual.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / entries.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: segmentWidth * (index < 0 ? 0 : index),
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: index < 0 ? 0 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: visual.navigationSelected,
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: [
                        BoxShadow(
                          color: visual.shadow,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final entry in entries)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: entry.key == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(entry.key),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: textStyle!.copyWith(
                                color: entry.key == selected
                                    ? visual.navigationFill.withValues(alpha: 1)
                                    : visual.textSecondary,
                              ),
                              child: Text(entry.value),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
