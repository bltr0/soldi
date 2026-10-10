/// Services that can search for places.
///
/// [id] is stored on saved places, so it must never change.
enum PlaceSearchProvider {
  osm(
    id: 'osm',
    label: 'OpenStreetMap',
    freeTier: 'Free, no key. Shared public server, light use only',
    usefulFor: 'Worldwide, but sparse in South Korea and China',
    keyFields: [],
  ),
  kakao(
    id: 'kakao',
    label: 'Kakao Local',
    freeTier: 'Free up to 100,000 searches a day',
    usefulFor: 'South Korea',
    keyFields: ['REST API key'],
  ),
  naver(
    id: 'naver',
    label: 'Naver Search',
    freeTier: 'Free up to 25,000 searches a day, 5 results each',
    usefulFor: 'South Korea',
    keyFields: ['Client ID', 'Client secret'],
  ),
  google(
    id: 'google',
    label: 'Google Places',
    freeTier:
        'Free up to 5,000 searches a month, then paid. Billing account required',
    usefulFor: 'Worldwide, except mainland China',
    keyFields: ['API key'],
  ),
  amap(
    id: 'amap',
    label: 'Amap',
    freeTier:
        'Free up to 5,000 searches a month for verified personal developers',
    usefulFor: 'Mainland China',
    keyFields: ['Web service key'],
  );

  const PlaceSearchProvider({
    required this.id,
    required this.label,
    required this.freeTier,
    required this.usefulFor,
    required this.keyFields,
  });

  final String id;
  final String label;

  /// Free tier rate limit, as published by the provider (October 2026).
  final String freeTier;

  /// Countries where its place data is good.
  final String usefulFor;

  /// What the user has to paste in settings, in order.
  final List<String> keyFields;

  String get logoAsset => 'assets/images/place_provider_$id.png';

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
