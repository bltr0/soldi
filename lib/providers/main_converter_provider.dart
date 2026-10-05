import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/bank_account.dart';
import '../model/transaction.dart';
import '../services/database/repositories/account_repository.dart';
import '../services/fx/fx_table.dart';
import 'accounts_provider.dart';
import 'fx_provider.dart';

/// Turns amounts held in any account currency into the main currency.
///
/// Transactions are converted at the rate of their own day, never today's,
/// so past totals don't drift as rates move. Anything adding up amounts
/// from several accounts (totals, charts, percentages) must go through this,
/// or 40,000 KRW would count as 40,000 EUR.
class MainConverter {
  MainConverter(this.fx, this._currencies);

  final FxTable fx;

  /// Account id to currency code; null means the main currency.
  final Map<int, String?> _currencies;

  String? currencyOf(int accountId) => _currencies[accountId];

  /// [value] (default: the transaction's amount), held in the transaction's
  /// account, in the main currency on the transaction's day.
  double transaction(Transaction t, [num? value]) => fx
      .toMain(value ?? t.amount, _currencies[t.idBankAccount], t.date)
      .toDouble();

  /// [value] held in [accountId], in the main currency on [date].
  double amount(num value, int accountId, DateTime date) =>
      fx.toMain(value, _currencies[accountId], date).toDouble();

  /// An account's current balance in the main currency, at today's rate.
  double balance(BankAccount account) => fx
      .toMain(account.total ?? 0, account.currency, DateTime.now())
      .toDouble();
}

final mainConverterProvider = FutureProvider<MainConverter>((ref) async {
  final fx = await ref.watch(fxTableProvider.future);
  // Rebuild when accounts change; read every account, deleted ones included,
  // since their transactions still show up.
  await ref.watch(accountsProvider.future);
  final accounts = await ref.read(accountRepositoryProvider).selectAll();
  return MainConverter(fx, {
    for (final account in accounts)
      if (account.id != null) account.id!: account.currency,
  });
});
