import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/accounts_provider.dart';
import '../providers/currency_provider.dart';

/// Looks up the display currency of an account during a build.
///
/// Accounts without their own currency use the app's main currency.
/// Display only: nothing here converts amounts.
extension AccountCurrencyRef on WidgetRef {
  /// Symbol to show next to amounts held in [accountId].
  String accountSymbol(int? accountId) {
    final main = watch(currencyStateProvider).symbol;
    if (accountId == null) return main;
    final account = watch(
      accountsProvider,
    ).value?.firstWhereOrNull((a) => a.id == accountId);
    return account?.currencySymbol(main) ?? main;
  }

  /// ISO code of the currency of [accountId].
  String accountCode(int? accountId) {
    final main = watch(currencyStateProvider).code;
    if (accountId == null) return main;
    final account = watch(
      accountsProvider,
    ).value?.firstWhereOrNull((a) => a.id == accountId);
    return account?.currencyCode(main) ?? main;
  }
}
