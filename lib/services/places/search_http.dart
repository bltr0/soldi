import 'dart:convert';

import 'package:http/http.dart' as http;

import 'place_search_provider.dart';

const placeSearchTimeout = Duration(seconds: 8);

/// Decodes a JSON object reply, or explains why the service refused.
Map<String, dynamic> decodeSearchReply(String service, http.Response response) {
  if (response.statusCode == 401 || response.statusCode == 403) {
    throw PlaceSearchException('$service rejected the API key');
  }
  if (response.statusCode != 200) {
    throw PlaceSearchException('$service returned ${response.statusCode}');
  }
  final body = jsonDecode(utf8.decode(response.bodyBytes));
  if (body is! Map<String, dynamic>) {
    throw PlaceSearchException('$service sent an unexpected reply');
  }
  return body;
}

String? cleanText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
