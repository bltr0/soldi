import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../model/place.dart';
import 'place_search_provider.dart';
import 'search_http.dart';

/// Amap (Gaode) POI search, v5 web service.
///
/// Amap returns GCJ-02 coordinates, which are shifted by up to a few hundred
/// metres in mainland China. They are converted to WGS84 before saving so all
/// stored places share one coordinate system.
Future<List<PlaceHit>> searchAmapPlaces(
  String query, {
  required String key,
}) async {
  final uri = Uri.https('restapi.amap.com', '/v5/place/text', {
    'keywords': query,
    'key': key,
    'page_size': '10',
  });
  final response = await http.get(uri).timeout(placeSearchTimeout);
  return parseAmapReply(decodeSearchReply('Amap', response));
}

@visibleForTesting
List<PlaceHit> parseAmapReply(Map<String, dynamic> body) {
  // Amap reports errors with HTTP 200 and status "0".
  if (body['status']?.toString() != '1') {
    throw PlaceSearchException(
      'Amap: ${cleanText(body['info']) ?? 'request failed'}',
    );
  }
  final pois = body['pois'];
  if (pois is! List) return const [];
  final hits = <PlaceHit>[];
  for (final poi in pois) {
    if (poi is! Map) continue;
    final name = cleanText(poi['name']);
    final location = cleanText(poi['location'])?.split(',');
    if (name == null || location == null || location.length < 2) continue;
    final lng = double.tryParse(location[0]);
    final lat = double.tryParse(location[1]);
    if (lng == null || lat == null) continue;
    final (latitude, longitude) = gcj02ToWgs84(lat, lng);
    final parts = <String>[
      for (final key in ['address', 'adname', 'cityname', 'pname'])
        ?cleanText(poi[key]),
    ];
    hits.add(
      PlaceHit(
        name: name,
        address: parts.isEmpty ? null : parts.toSet().join(', '),
        latitude: latitude,
        longitude: longitude,
        provider: 'amap',
        providerPlaceId: cleanText(poi['id']) ?? '$lng,$lat:$name',
      ),
    );
  }
  return hits;
}

/// Approximate GCJ-02 to WGS84 conversion (error well under 10 m).
/// Points outside mainland China are returned unchanged.
@visibleForTesting
(double, double) gcj02ToWgs84(double lat, double lng) {
  if (_outOfChina(lat, lng)) return (lat, lng);
  const a = 6378245.0;
  const ee = 0.00669342162296594323;
  var dLat = _transformLat(lng - 105.0, lat - 35.0);
  var dLng = _transformLng(lng - 105.0, lat - 35.0);
  final radLat = lat / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * math.pi);
  dLng = (dLng * 180.0) / (a / sqrtMagic * math.cos(radLat) * math.pi);
  return (lat - dLat, lng - dLng);
}

bool _outOfChina(double lat, double lng) =>
    lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271;

double _transformLat(double x, double y) {
  var ret =
      -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret +=
      (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (160.0 * math.sin(y / 12.0 * math.pi) +
          320 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLng(double x, double y) {
  var ret =
      300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  ret +=
      (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (150.0 * math.sin(x / 12.0 * math.pi) +
          300.0 * math.sin(x / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return ret;
}
