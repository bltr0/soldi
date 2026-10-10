import '../../model/place.dart';
import 'amap_search.dart';
import 'google_places_search.dart';
import 'kakao_search.dart';
import 'naver_search.dart';
import 'photon_search.dart';
import 'place_search_provider.dart';
import 'place_search_settings_store.dart';

/// Searches with [provider], or with the effective provider of [settings].
/// Only the query text is sent, never amounts.
Future<List<PlaceHit>> searchPlaces(
  String query,
  PlaceSearchSettings settings, {
  PlaceSearchProvider? provider,
  String languageCode = 'en',
}) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return const [];
  final using = provider ?? settings.effective;
  final keys = settings.keysFor(using);
  if (!settings.isConfigured(using)) {
    throw PlaceSearchException('${using.label} needs an API key');
  }
  return switch (using) {
    PlaceSearchProvider.osm => searchPhotonPlaces(
      trimmed,
      languageCode: languageCode,
    ),
    PlaceSearchProvider.kakao => searchKakaoPlaces(
      trimmed,
      restApiKey: keys[0].trim(),
    ),
    PlaceSearchProvider.naver => searchNaverPlaces(
      trimmed,
      clientId: keys[0].trim(),
      clientSecret: keys[1].trim(),
    ),
    PlaceSearchProvider.google => searchGooglePlaces(
      trimmed,
      apiKey: keys[0].trim(),
      languageCode: languageCode,
    ),
    PlaceSearchProvider.amap => searchAmapPlaces(trimmed, key: keys[0].trim()),
  };
}
