import 'package:flutter/material.dart';

import '../../../../ui/device.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';

class LabelListTile extends StatelessWidget {
  const LabelListTile(this.labelController, {super.key});

  final TextEditingController labelController;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.md,
        vertical: Sizes.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.notes_rounded, size: 20, color: visual.accent),
          ),
          const SizedBox(width: Sizes.md),
          Expanded(
            child: TextField(
              controller: labelController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'What was it for?',
                hintStyle: TextStyle(color: visual.textSecondary),
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: visual.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
