// ignore_for_file: file_names

import 'package:sqflite/sqflite.dart';

import '../../../model/place.dart';
import '../migration_base.dart';

class AddPlaceCityCountry extends Migration {
  AddPlaceCityCountry()
    : super(version: 13, description: 'Remember city and country on a place');

  @override
  Future<void> up(Database db) async {
    await db.execute('''
      ALTER TABLE `$placeTable`
      ADD COLUMN `${PlaceFields.city}` TEXT
    ''');
    await db.execute('''
      ALTER TABLE `$placeTable`
      ADD COLUMN `${PlaceFields.country}` TEXT
    ''');
  }
}
