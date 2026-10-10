import 'package:flutter/material.dart';

import '../../services/places/place_search_provider.dart';
import '../theme/dashboard_visual_theme.dart';

/// Logo of the service that found a place.
class PlaceProviderBadge extends StatelessWidget {
  const PlaceProviderBadge({required this.provider, this.size = 28, super.key});

  final PlaceSearchProvider? provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final provider = this.provider;
    final radius = BorderRadius.circular(size * 0.28);
    return Tooltip(
      message: provider?.label ?? 'Unknown source',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: visual.hairline),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: provider == null
              ? Icon(
                  Icons.place_rounded,
                  size: size * 0.6,
                  color: visual.textSecondary,
                )
              : Image.asset(
                  provider.logoAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                ),
        ),
      ),
    );
  }
}
