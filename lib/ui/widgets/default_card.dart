import 'package:flutter/material.dart';

import '../device.dart';
import 'default_container.dart';
import 'tonal_glass_surface.dart';

class DefaultCard extends StatelessWidget {
  const DefaultCard({required this.child, required this.onTap, super.key});

  final Widget child;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
      child: TonalGlassSurface(
        radius: DefaultContainer.radius,
        padding: const EdgeInsets.all(Sizes.md),
        onTap: onTap,
        child: child,
      ),
    );
  }
}
