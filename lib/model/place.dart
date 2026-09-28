import 'base_entity.dart';

const String placeTable = 'place';

class PlaceFields extends BaseEntityFields {
  static String id = BaseEntityFields.getId;
  static String name = 'name';
  static String address = 'address';
  static String latitude = 'latitude';
  static String longitude = 'longitude';
  static String provider = 'provider';
  static String providerPlaceId = 'providerPlaceId';
  static String createdAt = BaseEntityFields.getCreatedAt;
  static String updatedAt = BaseEntityFields.getUpdatedAt;

  static final List<String> allFields = [
    BaseEntityFields.id,
    name,
    address,
    latitude,
    longitude,
    provider,
    providerPlaceId,
    BaseEntityFields.createdAt,
    BaseEntityFields.updatedAt,
  ];
}

class Place extends BaseEntity {
  final String name;
  final String? address;
  final double latitude;
  final double longitude;

  /// Search service that found this place. The beta uses `osm`.
  final String provider;
  final String providerPlaceId;

  const Place({
    super.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.provider,
    required this.providerPlaceId,
    super.createdAt,
    super.updatedAt,
  });

  Place copy({int? id, String? name, DateTime? updatedAt}) => Place(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address,
    latitude: latitude,
    longitude: longitude,
    provider: provider,
    providerPlaceId: providerPlaceId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static Place fromJson(Map<String, Object?> json) => Place(
    id: json[PlaceFields.id] as int?,
    name: json[PlaceFields.name] as String,
    address: json[PlaceFields.address] as String?,
    latitude: (json[PlaceFields.latitude] as num).toDouble(),
    longitude: (json[PlaceFields.longitude] as num).toDouble(),
    provider: json[PlaceFields.provider] as String,
    providerPlaceId: json[PlaceFields.providerPlaceId] as String,
    createdAt: DateTime.parse(json[BaseEntityFields.createdAt] as String),
    updatedAt: DateTime.parse(json[BaseEntityFields.updatedAt] as String),
  );

  Map<String, Object?> toJson() => {
    PlaceFields.id: id,
    PlaceFields.name: name,
    PlaceFields.address: address,
    PlaceFields.latitude: latitude,
    PlaceFields.longitude: longitude,
    PlaceFields.provider: provider,
    PlaceFields.providerPlaceId: providerPlaceId,
    BaseEntityFields.createdAt:
        createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    BaseEntityFields.updatedAt: DateTime.now().toIso8601String(),
  };
}

/// A search hit that has not been saved yet.
class PlaceHit {
  const PlaceHit({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.provider,
    required this.providerPlaceId,
  });

  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String provider;
  final String providerPlaceId;
}

class PlaceSpend {
  const PlaceSpend({
    required this.place,
    required this.spent,
    required this.payments,
  });

  final Place place;

  /// Sum of your share of each expense at this place.
  final num spent;
  final int payments;
}
