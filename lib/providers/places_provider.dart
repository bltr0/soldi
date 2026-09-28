import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/place.dart';
import '../services/database/repositories/place_repository.dart';

part 'places_provider.g.dart';

@Riverpod(keepAlive: true)
class SelectedPlace extends _$SelectedPlace {
  @override
  Place? build() => null;

  void setPlace(Place? place) => state = place;
}

@Riverpod(keepAlive: true)
Future<List<PlaceSpend>> placeSpending(Ref ref) {
  return ref.read(placeRepositoryProvider).spending();
}
