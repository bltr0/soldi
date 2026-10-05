import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../model/budget.dart';
import '../../../model/category_transaction.dart';
import '../../../model/transaction.dart';
import '../sossoldi_database.dart';

part 'budget_repository.g.dart';

@riverpod
BudgetRepository budgetRepository(Ref ref) {
  return BudgetRepository(database: ref.watch(databaseProvider));
}

class BudgetRepository {
  BudgetRepository({required SossoldiDatabase database})
    : _sossoldiDB = database;

  final SossoldiDatabase _sossoldiDB;

  Future<Budget> insert(Budget item) async {
    final db = await _sossoldiDB.database;
    final id = await db.insert(budgetTable, item.toJson());
    return item.copy(id: id);
  }

  Future<Budget> insertOrUpdate(Budget item) async {
    final db = await _sossoldiDB.database;

    final exists = await checkIfExists(item);
    int itemId = item.id ?? 0;

    if (exists) {
      await db.update(
        budgetTable,
        {BudgetFields.amountLimit: item.amountLimit, BudgetFields.active: 1},
        where: '${BudgetFields.idCategory} = ?',
        whereArgs: [item.idCategory],
      );
    } else {
      itemId = await db.insert(budgetTable, item.toJson());
    }

    return item.copy(id: itemId);
  }

  Future<bool> checkIfExists(Budget item) async {
    final db = await _sossoldiDB.database;

    try {
      final exists = await db.rawQuery(
        "SELECT * FROM $budgetTable WHERE ${BudgetFields.idCategory} = ${item.idCategory}",
      );
      if (exists.isNotEmpty) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Budget> selectById(int id) async {
    final db = await _sossoldiDB.database;

    final maps = await db.query(
      budgetTable,
      columns: BudgetFields.allFields,
      where: '${BudgetFields.id} = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Budget.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  Future<List<Budget>> selectAll() async {
    final db = await _sossoldiDB.database;
    final orderByASC = '${BudgetFields.createdAt} ASC';
    final result = await db.rawQuery(
      'SELECT bt.*, ct.name FROM $budgetTable as bt LEFT JOIN $categoryTransactionTable as ct ON bt.${BudgetFields.idCategory} = ct.${CategoryTransactionFields.id} ORDER BY $orderByASC',
    );
    return result.map((json) => Budget.fromJson(json)).toList();
  }

  Future<List<Budget>> selectAllActive() async {
    final db = await _sossoldiDB.database;
    final orderByASC = '${BudgetFields.createdAt} ASC';
    final result = await db.rawQuery(
      'SELECT bt.*, ct.name FROM $budgetTable as bt LEFT JOIN $categoryTransactionTable as ct ON bt.${BudgetFields.idCategory} = ct.${CategoryTransactionFields.id} WHERE bt.${BudgetFields.active} = 1 ORDER BY $orderByASC',
    );
    return result.map((json) => Budget.fromJson(json)).toList();
  }

  /// This month's spending against each active budget. [toMain] converts
  /// each expense, held in its account's currency, into the main currency
  /// at its own day's rate, so accounts in other currencies add up right.
  Future<List<BudgetStats>> selectMonthlyBudgetsStats({
    num Function(num amount, int accountId, DateTime date)? toMain,
  }) async {
    final db = await _sossoldiDB.database;
    final rows = await db.rawQuery(
      "SELECT bt.${BudgetFields.idCategory} as category, t.${TransactionFields.amount} as amount, t.${TransactionFields.date} as date, t.${TransactionFields.idBankAccount} as account FROM $budgetTable as bt JOIN '$transactionTable' as t ON t.${TransactionFields.idCategory} = bt.${BudgetFields.idCategory} WHERE bt.${BudgetFields.active} = 1 AND strftime('%m', t.date) = strftime('%m', 'now') AND strftime('%Y', t.date) = strftime('%Y', 'now');",
    );

    final spent = <int, num>{};
    for (final row in rows) {
      final category = row['category'] as int;
      final amount = row['amount'] as num? ?? 0;
      final date = DateTime.tryParse(row['date'] as String? ?? '');
      final account = row['account'] as int?;
      spent[category] =
          (spent[category] ?? 0) +
          (toMain == null || date == null || account == null
              ? amount
              : toMain(amount, account, date));
    }

    final allBudgets = await selectAllActive();
    return [
      for (final budget in allBudgets)
        BudgetStats(
          idCategory: budget.idCategory,
          name: budget.name,
          spent: spent[budget.idCategory] ?? 0,
          amountLimit: budget.amountLimit,
        ),
    ];
  }

  Future<int> updateItem(Budget item) async {
    final db = await _sossoldiDB.database;

    // You can use `rawUpdate` to write the query in SQL
    return db.update(
      budgetTable,
      item.toJson(update: true),
      where: '${BudgetFields.id} = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteById(int id) async {
    final db = await _sossoldiDB.database;

    return await db.delete(
      budgetTable,
      where: '${BudgetFields.id} = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteByCategory(int id) async {
    final db = await _sossoldiDB.database;

    return await db.delete(
      budgetTable,
      where: '${BudgetFields.idCategory} = ?',
      whereArgs: [id],
    );
  }
}
