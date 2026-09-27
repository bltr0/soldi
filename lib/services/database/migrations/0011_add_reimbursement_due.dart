// ignore_for_file: file_names

import 'package:sqflite/sqflite.dart';

import '../../../model/transaction.dart';
import '../migration_base.dart';

class AddReimbursementDue extends Migration {
  AddReimbursementDue()
    : super(
        version: 11,
        description: 'Track expenses other people still owe you',
      );

  @override
  Future<void> up(Database db) async {
    await db.execute('''
      ALTER TABLE `$transactionTable`
      ADD COLUMN `${TransactionFields.reimbursementDue}`
      INTEGER NOT NULL DEFAULT 0
      CHECK (`${TransactionFields.reimbursementDue}` IN (0, 1))
    ''');
  }
}
