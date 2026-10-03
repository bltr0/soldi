import 'package:collection/collection.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/bank_account.dart';
import '../model/transaction.dart';
import '../services/database/repositories/account_repository.dart';
import '../services/database/repositories/recurring_transactions_repository.dart';
import 'dashboard_provider.dart';
import 'recurring_transactions_provider.dart';
import 'transactions_provider.dart';

part 'accounts_provider.g.dart';

@Riverpod(keepAlive: true)
class MainAccount extends _$MainAccount {
  @override
  BankAccount? build() => null;

  void setAccount(BankAccount? account) => state = account;
}

@Riverpod(keepAlive: true)
class SelectedAccount extends _$SelectedAccount {
  @override
  BankAccount? build() => null;

  void setAccount(BankAccount? account) => state = account;
}

@Riverpod(keepAlive: true)
class FilterAccount extends _$FilterAccount {
  @override
  Map<int, bool> build() {
    final accounts = ref.watch(accountsProvider).value;
    if (accounts != null) {
      return {for (var account in accounts) account.id!: false};
    }
    return {};
  }

  void setAccounts(Map<int, bool> accountsFilter) => state = accountsFilter;
}

@Riverpod(keepAlive: true)
class Accounts extends _$Accounts {
  @override
  Future<List<BankAccount>> build() async {
    final accounts = await _getAccounts();
    ref.read(mainAccountProvider.notifier).state = accounts.firstWhereOrNull(
      (account) => account.mainAccount,
    );
    return accounts;
  }

  Future<List<BankAccount>> _getAccounts() async {
    final accounts = await ref.read(accountRepositoryProvider).selectAll();
    return accounts;
  }

  Future<void> addAccount({
    required String name,
    required String icon,
    required int color,
    bool active = true,
    bool countNetWorth = true,
    bool mainAccount = false,
    num startingValue = 0,
    String? currency,
  }) async {
    BankAccount account = BankAccount(
      name: name,
      symbol: icon,
      color: color,
      startingValue: startingValue,
      active: active,
      countNetWorth: countNetWorth,
      mainAccount: mainAccount,
      order: 0,
      currency: currency,
    );

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(accountRepositoryProvider).insert(account);
      return _getAccounts();
    });
  }

  Future<void> updateAccount({
    String? name,
    String? icon,
    int? color,
    num? balance,
    bool? mainAccount,
    bool? countNetWorth,
    bool active = true,
    bool updateCurrency = false,
    String? currency,
  }) async {
    BankAccount account = ref
        .read(selectedAccountProvider)!
        .copy(
          name: name,
          symbol: icon,
          color: color,
          active: active,
          countNetWorth: countNetWorth,
          mainAccount: mainAccount,
        );
    if (updateCurrency) account = account.copy(currency: currency);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (balance != null) {
        await _reconcileAccount(account: account, newBalance: balance);
      }
      await ref.read(accountRepositoryProvider).updateItem(account);

      if (account.mainAccount) {
        ref.read(mainAccountProvider.notifier).state = account;
      }
      ref.invalidate(dashboardProvider);

      return _getAccounts();
    });
  }

  /// Makes the balance of [account] at the end of [date] (today when omitted)
  /// equal [newBalance] by inserting an adjustment on that day.
  Future<void> reconcileAccount({
    required BankAccount account,
    required num newBalance,
    DateTime? date,
  }) async {
    await _reconcileAccount(
      account: account,
      newBalance: newBalance,
      date: date,
    );
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _getAccounts();
    });
  }

  Future<void> _reconcileAccount({
    required BankAccount account,
    required num newBalance,
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final day = date ?? now;
    final isToday = DateUtils.isSameDay(day, now);
    final at = isToday
        ? now
        : DateTime(day.year, day.month, day.day, 23, 59, 59);
    final current = await ref
        .read(accountRepositoryProvider)
        .balanceAt(account.id!, at);
    final difference = newBalance - current;
    if (difference.abs() >= 0.005) {
      await ref
          .read(transactionsProvider.notifier)
          .create(
            difference,
            'Reconciliation',
            account: account,
            type: TransactionType.adjustment,
            date: at,
          );
    }
  }

  Future<void> refreshAccount(BankAccount account) async {
    ref.invalidate(transactionsProvider);
    ref.invalidate(recurringTransactionsProvider);
    ref.read(selectedAccountProvider.notifier).state = account;
    ref.invalidate(accountLedgerProvider(account.id!));
  }

  Future<void> deactivateAccount(BankAccount account) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(accountRepositoryProvider).deactivateById(account.id!);
      if (account.mainAccount) ref.invalidate(mainAccountProvider);
      return _getAccounts();
    });
  }

  Future<void> removeAccount(BankAccount account) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // delete recurring transactions tied to this account
      if (account.id != null) {
        await ref
            .read(recurringTransactionRepositoryProvider)
            .deleteByAccount(account.id!);
      }

      await ref.read(accountRepositoryProvider).deleteById(account);
      if (account.mainAccount) ref.invalidate(mainAccountProvider);
      ref.invalidate(recurringTransactionsProvider);
      return _getAccounts();
    });
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    final currentList = state.value;
    if (currentList == null) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final newList = List<BankAccount>.from(currentList);
    final item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);

    state = AsyncData(newList);

    await AsyncValue.guard(() async {
      await ref.read(accountRepositoryProvider).updateOrders(newList);
    });
  }

  void reset() {
    ref.invalidate(selectedAccountProvider);
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.transaction,
    required this.delta,
    required this.balanceAfter,
  });

  final Transaction transaction;

  /// Signed effect of the transaction on the ledger's account.
  final num delta;
  final num balanceAfter;
}

/// All transactions of an account, oldest first, with the running balance
/// after each one.
@riverpod
Future<List<LedgerEntry>> accountLedger(Ref ref, int accountId) async {
  final accounts = await ref.watch(accountsProvider.future);
  final account = accounts.firstWhereOrNull((a) => a.id == accountId);
  final rows = await ref
      .read(accountRepositoryProvider)
      .accountLedger(accountId);
  var balance = account?.startingValue ?? 0;
  final entries = <LedgerEntry>[];
  for (final row in rows) {
    final transaction = Transaction.fromJson(row);
    final delta = transaction.deltaFor(accountId);
    balance += delta;
    entries.add(
      LedgerEntry(
        transaction: transaction,
        delta: delta,
        balanceAfter: balance,
      ),
    );
  }
  return entries;
}

@Riverpod(keepAlive: true)
Future<List<BankAccount>> activeAccounts(Ref ref) async {
  final accounts = ref.watch(accountsProvider).value ?? [];
  return accounts.where((account) => account.deletedAt == null).toList();
}

@riverpod
Future<List<BankAccount>> frequentAccounts(Ref ref) async {
  return await ref.read(accountRepositoryProvider).selectFrequentAccounts();
}
