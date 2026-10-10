import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'place_search_provider.dart';

const _kSettingsKey = 'place_search_settings_v1';

/// The chosen place search service and the keys pasted for each one.
class PlaceSearchSettings {
  const PlaceSearchSettings({
    this.selected = PlaceSearchProvider.osm,
    this.keys = const {},
  });

  final PlaceSearchProvider selected;

  /// Key values per provider, in the order of [PlaceSearchProvider.keyFields].
  final Map<PlaceSearchProvider, List<String>> keys;

  List<String> keysFor(PlaceSearchProvider provider) =>
      keys[provider] ?? const [];

  bool isConfigured(PlaceSearchProvider provider) {
    final values = keysFor(provider);
    return provider.keyFields.length <= values.length &&
        values
            .take(provider.keyFields.length)
            .every((v) => v.trim().isNotEmpty);
  }

  /// The service a search really uses. A provider without keys falls back
  /// to OpenStreetMap so place search always works.
  PlaceSearchProvider get effective =>
      isConfigured(selected) ? selected : PlaceSearchProvider.osm;

  PlaceSearchSettings copyWith({
    PlaceSearchProvider? selected,
    Map<PlaceSearchProvider, List<String>>? keys,
  }) => PlaceSearchSettings(
    selected: selected ?? this.selected,
    keys: keys ?? this.keys,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'selected': selected.id,
    'keys': {for (final e in keys.entries) e.key.id: e.value},
  };

  static PlaceSearchSettings fromJson(Map<String, dynamic> json) {
    final keys = <PlaceSearchProvider, List<String>>{};
    final rawKeys = json['keys'];
    if (rawKeys is Map) {
      for (final entry in rawKeys.entries) {
        final provider = PlaceSearchProvider.fromId(entry.key.toString());
        final values = entry.value;
        if (provider == null || values is! List) continue;
        keys[provider] = [for (final v in values) v.toString()];
      }
    }
    return PlaceSearchSettings(
      selected:
          PlaceSearchProvider.fromId(json['selected']?.toString()) ??
          PlaceSearchProvider.osm,
      keys: keys,
    );
  }
}

/// Encrypted persistence for place search keys. Keys never leave the device
/// except in requests to the service they belong to.
class PlaceSearchSettingsStore {
  const PlaceSearchSettingsStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  Future<PlaceSearchSettings> read() async {
    try {
      final encoded = await _storage.read(key: _kSettingsKey);
      if (encoded == null) return const PlaceSearchSettings();
      return PlaceSearchSettings.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } catch (_) {
      return const PlaceSearchSettings();
    }
  }

  Future<void> write(PlaceSearchSettings settings) =>
      _storage.write(key: _kSettingsKey, value: jsonEncode(settings.toJson()));
}
