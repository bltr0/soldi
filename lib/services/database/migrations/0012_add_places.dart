// ignore_for_file: file_names

import 'package:sqflite/sqflite.dart';

import '../../../model/place.dart';
import '../../../model/transaction.dart';
import '../migration_base.dart';

class AddPlaces extends Migration {
  AddPlaces()
    : super(version: 12, description: 'Save places and link them to expenses');

  @override
  Future<void> up(Database db) async {
    await db.execute('''
      CREATE TABLE `$placeTable`(
        `${PlaceFields.id}` INTEGER PRIMARY KEY AUTOINCREMENT,
        `${PlaceFields.name}` TEXT NOT NULL,
        `${PlaceFields.address}` TEXT,
        `${PlaceFields.latitude}` REAL NOT NULL,
        `${PlaceFields.longitude}` REAL NOT NULL,
        `${PlaceFields.provider}` TEXT NOT NULL,
        `${PlaceFields.providerPlaceId}` TEXT NOT NULL,
        `${PlaceFields.createdAt}` TEXT NOT NULL,
        `${PlaceFields.updatedAt}` TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX `place_provider_id`
      ON `$placeTable`(`${PlaceFields.provider}`, `${PlaceFields.providerPlaceId}`)
    ''');
    await db.execute('''
      ALTER TABLE `$transactionTable`
      ADD COLUMN `${TransactionFields.idPlace}` INTEGER
    ''');
    await db.execute('''
      CREATE INDEX `transaction_place`
      ON `$transactionTable`(`${TransactionFields.idPlace}`)
    ''');
  }
}
