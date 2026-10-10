import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../model/place.dart';
import 'search_http.dart';

/// Kakao Local keyword search. Coordinates are already WGS84.
Future<List<PlaceHit>> searchKakaoPlaces(
  String query, {
  required String restApiKey,
}) async {
  final uri = Uri.https('dapi.kakao.com', '/v2/local/search/keyword.json', {
    'query': query,
    'size': '10',
  });
  final response = await http
      .get(uri, headers: {'Authorization': 'KakaoAK $restApiKey'})
      .timeout(placeSearchTimeout);
  return parseKakaoReply(decodeSearchReply('Kakao', response));
}

@visibleForTesting
List<PlaceHit> parseKakaoReply(Map<String, dynamic> body) {
  final documents = body['documents'];
  if (documents is! List) return const [];
  final hits = <PlaceHit>[];
  for (final doc in documents) {
    if (doc is! Map) continue;
    final name = cleanText(doc['place_name']);
    final longitude = double.tryParse('${doc['x']}');
    final latitude = double.tryParse('${doc['y']}');
    if (name == null || latitude == null || longitude == null) continue;
    hits.add(
      PlaceHit(
        name: name,
        address:
            cleanText(doc['road_address_name']) ??
            cleanText(doc['address_name']),
        latitude: latitude,
        longitude: longitude,
        provider: 'kakao',
        providerPlaceId: cleanText(doc['id']) ?? '$latitude,$longitude:$name',
      ),
    );
  }
  return hits;
}
