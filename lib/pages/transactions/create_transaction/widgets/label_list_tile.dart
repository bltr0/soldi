import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ui/widgets/rounded_icon.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/device.dart';

class LabelListTile extends ConsumerWidget {
  const LabelListTile(this.labelController, {super.key});

  final TextEditingController labelController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Sizes.lg,
        Sizes.xs,
        Sizes.xl,
        Sizes.xs,
      ),
      child: Row(
        children: [
          RoundedIcon(
            icon: Icons.description,
            size: 18,
            padding: const EdgeInsets.all(Sizes.sm),
            backgroundColor: context.dashboardTheme.accent,
          ),
          const SizedBox(width: Sizes.md),
          Text(
            "Description",
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: context.dashboardTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: Sizes.lg),
          Expanded(
            child: TextField(
              controller: labelController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: "Add a description",
                hintStyle: TextStyle(
                  color: context.dashboardTheme.textSecondary,
                ),
              ),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: context.dashboardTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
