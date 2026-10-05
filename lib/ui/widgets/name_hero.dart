import 'package:flutter/material.dart';

import '../device.dart';
import '../theme/dashboard_visual_theme.dart';
import 'tonal_glass_surface.dart';

/// Top card of an edit page: the item's coloured icon next to its name.
class NameHero extends StatelessWidget {
  const NameHero({
    required this.icon,
    required this.color,
    required this.controller,
    required this.hint,
    super.key,
  });

  final IconData? icon;
  final Color color;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return TonalGlassSurface(
      tone: GlassTone.hero,
      radius: 28,
      pressScale: 1,
      padding: const EdgeInsets.all(Sizes.lg),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: Sizes.md),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: visual.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: visual.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Destructive action at the end of an edit page.
class DeleteAction extends StatelessWidget {
  const DeleteAction({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: visual.negative,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: Sizes.lg,
            vertical: Sizes.md,
          ),
        ),
        icon: const Icon(Icons.delete_outline_rounded),
        label: Text(label),
      ),
    );
  }
}
