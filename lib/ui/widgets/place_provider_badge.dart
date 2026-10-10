import 'package:flutter/material.dart';

import '../../services/places/place_search_provider.dart';

/// Small brand-coloured mark showing which service found a place.
class PlaceProviderBadge extends StatelessWidget {
  const PlaceProviderBadge({required this.provider, this.size = 28, super.key});

  final PlaceSearchProvider? provider;
  final double size;

  static (Color, Color, String) _style(
    PlaceSearchProvider? provider,
  ) => switch (provider) {
    PlaceSearchProvider.osm => (const Color(0xFF7EBC6F), Colors.white, 'OSM'),
    PlaceSearchProvider.kakao => (
      const Color(0xFFFEE500),
      const Color(0xFF191919),
      'K',
    ),
    PlaceSearchProvider.naver => (const Color(0xFF03C75A), Colors.white, 'N'),
    PlaceSearchProvider.google => (const Color(0xFF4285F4), Colors.white, 'G'),
    PlaceSearchProvider.amap => (const Color(0xFF1677FF), Colors.white, '高'),
    null => (Colors.grey, Colors.white, '?'),
  };

  @override
  Widget build(BuildContext context) {
    final (background, foreground, mark) = _style(provider);
    return Tooltip(
      message: provider?.label ?? 'Unknown source',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size / 4),
        ),
        child: Text(
          mark,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w900,
            fontSize: size * (mark.length > 1 ? 0.3 : 0.5),
            height: 1,
          ),
        ),
      ),
    );
  }
}
