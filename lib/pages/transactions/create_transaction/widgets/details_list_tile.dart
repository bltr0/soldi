import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../../ui/theme/dashboard_visual_theme.dart";
import "../../../../ui/widgets/rounded_icon.dart";
import "../../../../ui/device.dart";

class DetailsListTile extends ConsumerWidget {
  const DetailsListTile({
    required this.title,
    required this.icon,
    required this.value,
    required this.callback,
    super.key,
  });

  final String title;
  final IconData icon;
  final String? value;
  final VoidCallback callback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
      onTap: callback,
      leading: RoundedIcon(
        icon: icon,
        size: 18,
        padding: const EdgeInsets.all(Sizes.sm),
        backgroundColor: context.dashboardTheme.accent,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          color: context.dashboardTheme.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.45,
            ),
            child: Text(
              value ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: context.dashboardTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: Sizes.xs),
          Icon(
            Icons.chevron_right,
            color: context.dashboardTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}
