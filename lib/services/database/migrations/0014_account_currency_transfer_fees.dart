// ignore_for_file: file_names

import 'package:sqflite/sqflite.dart';

import '../../../model/bank_account.dart';
import '../../../model/transaction.dart';
import '../migration_base.dart';

class AccountCurrencyAndTransferFees extends Migration {
  AccountCurrencyAndTransferFees()
    : super(
        version: 14,
        description:
            'Per-account display currency, transfer fees and received amount',
      );

  @override
  Future<void> up(Database db) async {
    // ISO code; NULL means the app's main currency.
    await db.execute('''
      ALTER TABLE `$bankAccountTable`
      ADD COLUMN `${BankAccountFields.currency}` TEXT
    ''');
    // Fee paid by the sending account, in its currency. Never received.
    await db.execute('''
      ALTER TABLE `$transactionTable`
      ADD COLUMN `${TransactionFields.fee}` REAL
    ''');
    // Percentage the fee was entered as, kept so editing shows it again.
    await db.execute('''
      ALTER TABLE `$transactionTable`
      ADD COLUMN `${TransactionFields.feePercent}` REAL
    ''');
    // Amount credited to the receiving account, in its currency.
    // NULL means the receiver got exactly `amount`.
    await db.execute('''
      ALTER TABLE `$transactionTable`
      ADD COLUMN `${TransactionFields.amountTransfer}` REAL
    ''');
  }
}
