// ignore_for_file: file_names

import 'package:sqflite/sqflite.dart';

import '../../../model/bank_account.dart';
import '../migration_base.dart';

class AddAccountAlwaysBlurred extends Migration {
  AddAccountAlwaysBlurred()
    : super(
        version: 16,
        description: 'Accounts whose balance stays hidden outside settings',
      );

  @override
  Future<void> up(Database db) async {
    await db.execute('''
      ALTER TABLE `$bankAccountTable`
      ADD COLUMN `${BankAccountFields.alwaysBlurred}` INTEGER NOT NULL DEFAULT 0
    ''');
  }
}
