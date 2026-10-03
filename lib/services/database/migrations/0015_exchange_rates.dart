// ignore_for_file: file_names

import 'package:sqflite/sqflite.dart';

import '../migration_base.dart';

const String exchangeRateTable = 'exchangeRate';

class AddExchangeRates extends Migration {
  AddExchangeRates()
    : super(
        version: 15,
        description: 'Daily exchange rates for showing amounts in the main currency',
      );

  @override
  Future<void> up(Database db) async {
    // One row per day and pair: 1 `base` = `rate` `quote`, as published that
    // day. Only filled when the user allows fetching rates.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS `$exchangeRateTable`(
        `date` TEXT NOT NULL,
        `base` TEXT NOT NULL,
        `quote` TEXT NOT NULL,
        `rate` REAL NOT NULL,
        PRIMARY KEY (`date`, `base`, `quote`)
      )
    ''');
  }
}
