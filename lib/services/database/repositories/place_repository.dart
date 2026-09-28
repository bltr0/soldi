import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../model/place.dart';
import '../../../model/transaction.dart';
import '../sossoldi_database.dart';

part 'place_repository.g.dart';

@Riverpod(keepAlive: true)
PlaceRepository placeRepository(Ref ref) {
  return PlaceRepository(database: ref.watch(databaseProvider));
}

class PlaceRepository {
  PlaceRepository({required SossoldiDatabase database}) : _database = database;

  final SossoldiDatabase _database;

  Future<Place?> selectById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      placeTable,
      where: '${PlaceFields.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Place.fromJson(rows.first);
  }

  Future<List<Place>> selectAll() async {
    final db = await _database.database;
    final rows = await db.query(
      placeTable,
      orderBy: '${PlaceFields.name} COLLATE NOCASE',
    );
    return [for (final row in rows) Place.fromJson(row)];
  }

  /// Changes the label only. Coordinates stay as they were saved.
  Future<Place> rename(Place place, String name) async {
    final db = await _database.database;
    final now = DateTime.now();
    await db.update(
      placeTable,
      {PlaceFields.name: name, PlaceFields.updatedAt: now.toIso8601String()},
      where: '${PlaceFields.id} = ?',
      whereArgs: [place.id],
    );
    return place.copy(name: name, updatedAt: now);
  }

  /// Reuses a place already saved from the same search result.
  Future<Place> saveHit(PlaceHit hit) async {
    final db = await _database.database;
    final existing = await db.query(
      placeTable,
      where:
          '${PlaceFields.provider} = ? AND ${PlaceFields.providerPlaceId} = ?',
      whereArgs: [hit.provider, hit.providerPlaceId],
      limit: 1,
    );
    if (existing.isNotEmpty) return Place.fromJson(existing.first);

    final now = DateTime.now();
    final place = Place(
      name: hit.name,
      address: hit.address,
      latitude: hit.latitude,
      longitude: hit.longitude,
      provider: hit.provider,
      providerPlaceId: hit.providerPlaceId,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert(placeTable, place.toJson());
    return place.copy(id: id);
  }

  /// Your share of expenses at each place, largest first.
  Future<List<PlaceSpend>> spending() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT p.*,
        SUM(
          t.${TransactionFields.amount} * 1.0 / CASE
            WHEN IFNULL(t.${TransactionFields.peopleConcerned}, 1) < 1 THEN 1
            ELSE t.${TransactionFields.peopleConcerned}
          END
        ) AS spent,
        COUNT(t.${TransactionFields.id}) AS payments
      FROM `$placeTable` p
      JOIN `$transactionTable` t
        ON t.${TransactionFields.idPlace} = p.${PlaceFields.id}
      WHERE t.${TransactionFields.type} = '${TransactionType.expense.code}'
        AND IFNULL(t.${TransactionFields.note}, '') != 'Reconciliation'
      GROUP BY p.${PlaceFields.id}
      ORDER BY spent DESC
    ''');
    return [
      for (final row in rows)
        PlaceSpend(
          place: Place.fromJson(row),
          spent: row['spent'] as num? ?? 0,
          payments: (row['payments'] as num?)?.toInt() ?? 0,
        ),
    ];
  }

  Future<List<Transaction>> expensesAt(int placeId) async {
    final db = await _database.database;
    final rows = await db.query(
      transactionTable,
      where:
          '${TransactionFields.idPlace} = ? AND ${TransactionFields.type} = ?',
      whereArgs: [placeId, TransactionType.expense.code],
      orderBy: '${TransactionFields.date} DESC',
    );
    return [
      for (final row in rows)
        if (row[TransactionFields.note] != 'Reconciliation')
          Transaction.fromJson(row),
    ];
  }
}
