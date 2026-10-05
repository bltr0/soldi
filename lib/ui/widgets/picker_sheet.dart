import 'package:flutter/material.dart';

import '../device.dart';
import '../theme/dashboard_visual_theme.dart';

/// Bottom sheet in the app's style. With [scrollable], the content gets a
/// draggable sheet and its scroll controller.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, ScrollController? controller)
  builder,
  bool scrollable = true,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final visual = context.dashboardTheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: visual.solidSurface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => scrollable
        ? DraggableScrollableSheet(
            expand: false,
            minChildSize: 0.4,
            initialChildSize: 0.7,
            maxChildSize: 0.92,
            builder: builder,
          )
        : SafeArea(top: false, child: builder(context, null)),
  );
}

class PickerSheetHeader extends StatelessWidget {
  const PickerSheetHeader({
    required this.title,
    this.subtitle,
    this.onAdd,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sizes.lg, 0, Sizes.md, Sizes.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    color: visual.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: visual.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onAdd != null)
            IconButton.filledTonal(
              onPressed: onAdd,
              tooltip: 'Add',
              style: IconButton.styleFrom(
                backgroundColor: visual.accent.withValues(alpha: 0.14),
                foregroundColor: visual.accent,
              ),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
    );
  }
}

class PickerSectionLabel extends StatelessWidget {
  const PickerSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Sizes.lg,
        Sizes.md,
        Sizes.lg,
        Sizes.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: visual.textSecondary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Coloured square holding an icon, as used for accounts and categories.
class PickerIcon extends StatelessWidget {
  const PickerIcon({required this.icon, required this.color, super.key});

  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color ?? visual.textPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon ?? Icons.help_outline_rounded,
        size: 20,
        color: color == null ? visual.textSecondary : Colors.white,
      ),
    );
  }
}

/// One choice in a picker sheet.
class PickerRow extends StatelessWidget {
  const PickerRow({
    required this.title,
    required this.onTap,
    this.leading,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.indent = 0,
    super.key,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final double indent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(Sizes.md + indent, 0, Sizes.md, Sizes.xs),
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: selected
              ? visual.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(Sizes.sm),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
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
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: visual.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_rounded, color: visual.accent, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact choice for a horizontal "frequent" strip.
class PickerChip extends StatelessWidget {
  const PickerChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sizes.xs),
            child: Column(
              children: [
                PickerIcon(icon: icon, color: color),
                const SizedBox(height: Sizes.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: visual.textPrimary,
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
