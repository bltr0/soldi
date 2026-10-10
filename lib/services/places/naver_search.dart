import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../model/place.dart';
import 'search_http.dart';

/// Naver Search local API. It returns at most 5 results and no place ID.
Future<List<PlaceHit>> searchNaverPlaces(
  String query, {
  required String clientId,
  required String clientSecret,
}) async {
  final uri = Uri.https('openapi.naver.com', '/v1/search/local.json', {
    'query': query,
    'display': '5',
  });
  final response = await http
      .get(
        uri,
        headers: {
          'X-Naver-Client-Id': clientId,
          'X-Naver-Client-Secret': clientSecret,
        },
      )
      .timeout(placeSearchTimeout);
  return parseNaverReply(decodeSearchReply('Naver', response));
}

@visibleForTesting
List<PlaceHit> parseNaverReply(Map<String, dynamic> body) {
  final items = body['items'];
  if (items is! List) return const [];
  final hits = <PlaceHit>[];
  for (final item in items) {
    if (item is! Map) continue;
    final name = cleanText(_stripTags(item['title']?.toString() ?? ''));
    // WGS84 degrees scaled by 10^7.
    final x = int.tryParse('${item['mapx']}');
    final y = int.tryParse('${item['mapy']}');
    if (name == null || x == null || y == null) continue;
    hits.add(
      PlaceHit(
        name: name,
        address: cleanText(item['roadAddress']) ?? cleanText(item['address']),
        latitude: y / 1e7,
        longitude: x / 1e7,
        provider: 'naver',
        providerPlaceId: '$x,$y:$name',
      ),
    );
  }
  return hits;
}

String _stripTags(String html) => html
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");
