import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../model/place.dart';
import 'place_search_provider.dart';

/// Searches the public Photon service, which reads OpenStreetMap.
///
/// The public host is meant for light use. A personal beta fits that.
/// Amounts are never sent.
Future<List<PlaceHit>> searchPhotonPlaces(
  String query, {
  String languageCode = 'en',
}) async {
  final trimmed = query.trim();
  if (trimmed.length < 2) return const [];

  final uri = Uri.https('photon.komoot.io', '/api/', {
    'q': trimmed,
    'limit': '6',
    'lang': languageCode,
  });
  final response = await http
      .get(uri, headers: const {'User-Agent': 'Sossoldi place search beta'})
      .timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) {
    throw PlaceSearchException('Place search returned ${response.statusCode}');
  }

  final body = jsonDecode(response.body);
  if (body is! Map<String, dynamic>) return const [];
  final features = body['features'];
  if (features is! List) return const [];

  final hits = <PlaceHit>[];
  for (final feature in features) {
    final hit = _hitFromFeature(feature);
    if (hit != null) hits.add(hit);
  }
  return hits;
}

PlaceHit? _hitFromFeature(Object? feature) {
  if (feature is! Map) return null;
  final geometry = feature['geometry'];
  final properties = feature['properties'];
  if (geometry is! Map || properties is! Map) return null;
  final coordinates = geometry['coordinates'];
  if (coordinates is! List || coordinates.length < 2) return null;
  final longitude = (coordinates[0] as num?)?.toDouble();
  final latitude = (coordinates[1] as num?)?.toDouble();
  if (latitude == null || longitude == null) return null;

  final name = _label(properties);
  if (name == null) return null;

  final osmId = properties['osm_id'];
  final osmType = properties['osm_type']?.toString() ?? 'X';
  final providerPlaceId = osmId == null
      ? '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}:$name'
      : '$osmType$osmId';

  return PlaceHit(
    name: name,
    address: _address(properties, name),
    latitude: latitude,
    longitude: longitude,
    provider: 'osm',
    providerPlaceId: providerPlaceId,
  );
}

String? _label(Map properties) {
  final name = properties['name']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  final street = _streetLine(properties);
  if (street != null) return street;
  final city = properties['city']?.toString().trim();
  if (city != null && city.isNotEmpty) return city;
  return null;
}

String? _address(Map properties, String name) {
  final parts = <String>[];
  final street = _streetLine(properties);
  if (street != null && street != name) parts.add(street);
  for (final key in ['postcode', 'city', 'state', 'country']) {
    final value = properties[key]?.toString().trim();
    if (value == null ||
        value.isEmpty ||
        value == name ||
        parts.contains(value)) {
      continue;
    }
    parts.add(value);
  }
  if (parts.isEmpty) return null;
  return parts.join(', ');
}

String? _streetLine(Map properties) {
  final street = properties['street']?.toString().trim();
  final number = properties['housenumber']?.toString().trim();
  if ((street == null || street.isEmpty) &&
      (number == null || number.isEmpty)) {
    return null;
  }
  return [
    number,
    street,
  ].whereType<String>().where((p) => p.isNotEmpty).join(' ');
}
