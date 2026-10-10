/// Services that can search for places.
///
/// [id] is stored on saved places, so it must never change.
enum PlaceSearchProvider {
  osm(
    id: 'osm',
    label: 'OpenStreetMap',
    region: 'Worldwide, no key needed',
    keyFields: [],
  ),
  kakao(
    id: 'kakao',
    label: 'Kakao Local',
    region: 'Best for South Korea',
    keyFields: ['REST API key'],
  ),
  naver(
    id: 'naver',
    label: 'Naver Search',
    region: 'South Korea (5 results per search)',
    keyFields: ['Client ID', 'Client secret'],
  ),
  google(
    id: 'google',
    label: 'Google Places',
    region: 'Worldwide, needs billing enabled',
    keyFields: ['API key'],
  ),
  amap(
    id: 'amap',
    label: 'Amap',
    region: 'Best for mainland China',
    keyFields: ['Web service key'],
  );

  const PlaceSearchProvider({
    required this.id,
    required this.label,
    required this.region,
    required this.keyFields,
  });

  final String id;
  final String label;
  final String region;

  /// What the user has to paste in settings, in order.
  final List<String> keyFields;

  static PlaceSearchProvider? fromId(String? id) {
    for (final provider in values) {
      if (provider.id == id) return provider;
    }
    return null;
  }
}

class PlaceSearchException implements Exception {
  PlaceSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}
