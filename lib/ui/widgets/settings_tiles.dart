import 'package:flutter/material.dart';

import '../device.dart';
import '../theme/dashboard_visual_theme.dart';
import 'tonal_glass_surface.dart';

/// A titled glass card holding settings rows, separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.children,
    this.title,
    this.footer,
    super.key,
  });

  final String? title;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Sizes.md, 0, Sizes.md, Sizes.sm),
            child: Text(
              title!.toUpperCase(),
              style: textTheme.labelMedium?.copyWith(
                color: visual.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        TonalGlassSurface(
          radius: 24,
          pressScale: 1,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: Sizes.md,
                    endIndent: Sizes.md,
                    color: visual.hairline,
                  ),
                child,
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Sizes.md, Sizes.sm, Sizes.md, 0),
            child: Text(
              footer!,
              style: textTheme.bodySmall?.copyWith(color: visual.textSecondary),
            ),
          ),
      ],
    );
  }
}

/// One settings row: accent icon, title, optional subtitle, and a trailing
/// control or chevron. [below] sits under the row, inside the same tile.
/// [leading] replaces the icon box, for logos and other custom marks.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.below,
    super.key,
  });

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Sizes.md,
          vertical: Sizes.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: Sizes.md),
                ] else if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: visual.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 20, color: visual.accent),
                  ),
                  const SizedBox(width: Sizes.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          color: visual.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            color: visual.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: Sizes.sm),
                  trailing!,
                ] else if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: visual.textSecondary,
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: below == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: Sizes.md),
                      child: below,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.subtitle,
    this.below,
    super.key,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? below;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      below: below,
      trailing: Switch.adaptive(
        value: value,
        activeTrackColor: visual.accent,
        onChanged: onChanged,
      ),
    );
  }
}

/// Small rounded value shown at the end of a [SettingsTile].
class SettingsValue extends StatelessWidget {
  const SettingsValue(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.md,
        vertical: Sizes.xs + 2,
      ),
      decoration: BoxDecoration(
        color: visual.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: visual.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Rounded on/off chip for filters and short choices.
class TogglePill extends StatelessWidget {
  const TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shown before the label, such as a small logo.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: Material(
        color: selected
            ? visual.navigationSelected
            : visual.textPrimary.withValues(alpha: 0.06),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sizes.md,
              vertical: Sizes.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: Sizes.sm),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? visual.navigationFill.withValues(alpha: 1)
                        : visual.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
