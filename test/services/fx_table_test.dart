import 'package:flutter_test/flutter_test.dart';
import 'package:sossoldi/model/currency_catalog.dart';
import 'package:sossoldi/services/database/repositories/exchange_rate_repository.dart';
import 'package:sossoldi/services/fx/fx_table.dart';

void main() {
  test('uses the nearest earlier published rate and its inverse', () {
    final fx = FxTable(
      mainCode: 'EUR',
      stored: const [
        StoredRate('2025-03-03', 'KRW', 'EUR', 0.0007),
        StoredRate('2025-03-07', 'KRW', 'EUR', 0.0008),
      ],
    );
    expect(fx.rate('KRW', 'EUR', DateTime(2025, 3, 5)), 0.0007);
    expect(fx.rate('KRW', 'EUR', DateTime(2025, 3, 9)), 0.0008);
    expect(fx.rate('EUR', 'KRW', DateTime(2025, 3, 9)), closeTo(1250, 1e-9));
    expect(fx.convert(50000, 'KRW', 'EUR', DateTime(2025, 3, 9)), 40);
    expect(fx.rate('USD', 'EUR', DateTime(2025, 3, 9)), isNull);
  });

  test('falls back to rates implied by cross-currency transfers', () {
    final fx = FxTable(
      mainCode: 'EUR',
      transfers: [
        TransferRate(
          date: DateTime(2025, 1, 10),
          from: null,
          to: 'KRW',
          amount: 100,
          received: 150000,
        ),
      ],
    );
    expect(fx.convert(150000, 'KRW', 'EUR', DateTime(2025, 2, 1)), closeTo(100, 1e-9));
  });

  test('currencies without cents show no decimals', () {
    expect(CurrencyCatalog.decimalsFor('KRW'), 0);
    expect(CurrencyCatalog.decimalsFor('JPY'), 0);
    expect(CurrencyCatalog.decimalsFor('EUR'), 2);
    expect(CurrencyCatalog.decimalsFor(null), 2);
  });
}
