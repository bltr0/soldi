import "package:flutter/material.dart";

import "../../../../ui/theme/dashboard_visual_theme.dart";
import "../../../../ui/widgets/settings_tiles.dart";

class NonEditableDetailsListTile extends StatelessWidget {
  const NonEditableDetailsListTile({
    required this.title,
    required this.icon,
    required this.value,
    super.key,
  });

  final String title;
  final IconData icon;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: icon,
      title: title,
      trailing: Text(
        value ?? '',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.dashboardTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
