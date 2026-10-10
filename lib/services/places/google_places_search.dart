import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../model/place.dart';
import 'search_http.dart';

/// Google Places API (New) text search. Only the fields shown are requested;
/// together they are billed as the Text Search Pro SKU.
Future<List<PlaceHit>> searchGooglePlaces(
  String query, {
  required String apiKey,
  String languageCode = 'en',
}) async {
  final response = await http
      .post(
        Uri.https('places.googleapis.com', '/v1/places:searchText'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location',
        },
        body: jsonEncode({
          'textQuery': query,
          'languageCode': languageCode,
          'pageSize': 8,
        }),
      )
      .timeout(placeSearchTimeout);
  return parseGoogleReply(decodeSearchReply('Google', response));
}

@visibleForTesting
List<PlaceHit> parseGoogleReply(Map<String, dynamic> body) {
  final places = body['places'];
  if (places is! List) return const [];
  final hits = <PlaceHit>[];
  for (final place in places) {
    if (place is! Map) continue;
    final displayName = place['displayName'];
    final name = cleanText(displayName is Map ? displayName['text'] : null);
    final location = place['location'];
    final id = cleanText(place['id']);
    if (name == null || id == null || location is! Map) continue;
    final latitude = (location['latitude'] as num?)?.toDouble();
    final longitude = (location['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) continue;
    hits.add(
      PlaceHit(
        name: name,
        address: cleanText(place['formattedAddress']),
        latitude: latitude,
        longitude: longitude,
        provider: 'google',
        providerPlaceId: id,
      ),
    );
  }
  return hits;
}
