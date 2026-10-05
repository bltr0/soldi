import "package:flutter/material.dart";

import "../../../../ui/device.dart";
import "../../../../ui/theme/dashboard_visual_theme.dart";
import "../../../../ui/widgets/settings_tiles.dart";

class DetailsListTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return SettingsTile(
      icon: icon,
      title: title,
      onTap: callback,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
            ),
            child: Text(
              value ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: visual.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: Sizes.xs),
          Icon(Icons.chevron_right_rounded, color: visual.textSecondary),
        ],
      ),
    );
  }
}
