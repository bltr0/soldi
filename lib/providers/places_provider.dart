import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/place.dart';
import '../services/database/repositories/place_repository.dart';
import 'main_converter_provider.dart';

part 'places_provider.g.dart';

@Riverpod(keepAlive: true)
class SelectedPlace extends _$SelectedPlace {
  @override
  Place? build() => null;

  void setPlace(Place? place) => state = place;
}

@Riverpod(keepAlive: true)
Future<List<Place>> savedPlaces(Ref ref) {
  return ref.read(placeRepositoryProvider).selectAll();
}

@Riverpod(keepAlive: true)
Future<List<PlaceSpend>> placeSpending(Ref ref) async {
  final converter = await ref.watch(mainConverterProvider.future);
  return ref
      .read(placeRepositoryProvider)
      .spending(toMain: converter.amount);
}
