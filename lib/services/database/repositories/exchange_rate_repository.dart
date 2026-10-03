import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../model/bank_account.dart';
import '../../../model/transaction.dart';
import '../migrations/0015_exchange_rates.dart';
import '../sossoldi_database.dart';

part 'exchange_rate_repository.g.dart';

@riverpod
ExchangeRateRepository exchangeRateRepository(Ref ref) {
  return ExchangeRateRepository(database: ref.watch(databaseProvider));
}

/// A rate published for [date] (`yyyy-MM-dd`): 1 [base] = [rate] [quote].
class StoredRate {
  const StoredRate(this.date, this.base, this.quote, this.rate);

  final String date;
  final String base;
  final String quote;
  final double rate;
}

/// A transfer between two currencies: [amount] left the sender and
/// [received] reached the receiver, which implies a rate.
class TransferRate {
  const TransferRate({
    required this.date,
    required this.from,
    required this.to,
    required this.amount,
    required this.received,
  });

  final DateTime date;

  /// Currency codes; null means the app's main currency.
  final String? from;
  final String? to;
  final num amount;
  final num received;
}

class ExchangeRateRepository {
  ExchangeRateRepository({required SossoldiDatabase database})
    : _sossoldiDB = database;

  final SossoldiDatabase _sossoldiDB;

  Future<List<StoredRate>> all() async {
    final db = await _sossoldiDB.database;
    final rows = await db.query(exchangeRateTable, orderBy: 'date ASC');
    return [
      for (final row in rows)
        StoredRate(
          row['date'] as String,
          row['base'] as String,
          row['quote'] as String,
          (row['rate'] as num).toDouble(),
        ),
    ];
  }

  Future<void> upsert(Iterable<StoredRate> rates) async {
    final db = await _sossoldiDB.database;
    final batch = db.batch();
    for (final rate in rates) {
      batch.insert(exchangeRateTable, {
        'date': rate.date,
        'base': rate.base,
        'quote': rate.quote,
        'rate': rate.rate,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Latest stored day (`yyyy-MM-dd`) for the pair, if any.
  Future<String?> latestDate(String base, String quote) async {
    final db = await _sossoldiDB.database;
    final rows = await db.rawQuery(
      'SELECT MAX(date) as d FROM $exchangeRateTable WHERE base = ? AND quote = ?',
      [base, quote],
    );
    return rows.isEmpty ? null : rows.first['d'] as String?;
  }

  /// Earliest transaction day touching an account held in [currency].
  Future<DateTime?> earliestTransaction(String currency) async {
    final db = await _sossoldiDB.database;
    final rows = await db.rawQuery(
      '''
      SELECT MIN(t.${TransactionFields.date}) as d
      FROM "$transactionTable" t
      JOIN $bankAccountTable b
        ON b.${BankAccountFields.id} IN (
          t.${TransactionFields.idBankAccount},
          t.${TransactionFields.idBankAccountTransfer})
      WHERE b.${BankAccountFields.currency} = ?
    ''',
      [currency],
    );
    final value = rows.isEmpty ? null : rows.first['d'] as String?;
    return value == null ? null : DateTime.tryParse(value);
  }

  /// Transfers whose received amount differs from the sent one.
  Future<List<TransferRate>> transferRates() async {
    final db = await _sossoldiDB.database;
    final rows = await db.rawQuery('''
      SELECT t.${TransactionFields.date} as date,
             t.${TransactionFields.amount} as amount,
             t.${TransactionFields.amountTransfer} as received,
             b1.${BankAccountFields.currency} as fromCurrency,
             b2.${BankAccountFields.currency} as toCurrency
      FROM "$transactionTable" t
      JOIN $bankAccountTable b1
        ON t.${TransactionFields.idBankAccount} = b1.${BankAccountFields.id}
      JOIN $bankAccountTable b2
        ON t.${TransactionFields.idBankAccountTransfer} = b2.${BankAccountFields.id}
      WHERE t.${TransactionFields.type} = 'TRSF'
        AND t.${TransactionFields.amountTransfer} IS NOT NULL
        AND t.${TransactionFields.amount} > 0
        AND t.${TransactionFields.amountTransfer} > 0
    ''');
    return [
      for (final row in rows)
        if (DateTime.tryParse(row['date'] as String) != null)
          TransferRate(
            date: DateTime.parse(row['date'] as String),
            from: row['fromCurrency'] as String?,
            to: row['toCurrency'] as String?,
            amount: row['amount'] as num,
            received: row['received'] as num,
          ),
    ];
  }
}
