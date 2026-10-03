import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/database/repositories/account_repository.dart';
import '../services/database/repositories/exchange_rate_repository.dart';
import '../services/fx/frankfurter_client.dart';
import '../services/fx/fx_table.dart';
import 'currency_provider.dart';
import 'settings_provider.dart';

part 'fx_provider.g.dart';

/// Where exchange rates may come from.
enum FxSource {
  /// The user has not been asked yet.
  unset,

  /// Nothing leaves the device; only rates implied by the user's own
  /// cross-currency transfers are used.
  offline,

  /// Daily rates are fetched from Frankfurter, at most once a day, when the
  /// app is opened.
  frankfurter,
}

const _sourceKey = 'fx_source';
const _lastSyncKey = 'fx_last_sync';

@Riverpod(keepAlive: true)
class FxSourceSetting extends _$FxSourceSetting {
  @override
  FxSource build() {
    final prefs = ref.watch(sharedPrefProvider);
    return switch (prefs.getString(_sourceKey)) {
      'offline' => FxSource.offline,
      'frankfurter' => FxSource.frankfurter,
      _ => FxSource.unset,
    };
  }

  Future<void> set(FxSource source) async {
    final prefs = ref.read(sharedPrefProvider);
    await prefs.setString(_sourceKey, source.name);
    if (source != FxSource.frankfurter) await prefs.remove(_lastSyncKey);
    state = source;
    if (source == FxSource.frankfurter) {
      await ref.read(fxSyncProvider.notifier).sync(force: true);
    }
  }
}

/// All known rates, ready for lookups. Rebuilt when rates are fetched, the
/// main currency changes or transactions change.
@Riverpod(keepAlive: true)
Future<FxTable> fxTable(Ref ref) async {
  final main = ref.watch(currencyStateProvider).code;
  final repository = ref.read(exchangeRateRepositoryProvider);
  final stored = await repository.all();
  final transfers = await repository.transferRates();
  return FxTable(mainCode: main, stored: stored, transfers: transfers);
}

/// Fetches missing daily rates. Runs when the app opens and at most once a
/// day, only if the user chose Frankfurter; never in the background.
@Riverpod(keepAlive: true)
class FxSync extends _$FxSync {
  bool _running = false;

  @override
  void build() {}

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Fetches rates now. Without [force], does nothing if it already ran today.
  Future<void> sync({bool force = false}) async {
    if (_running) return;
    if (ref.read(fxSourceSettingProvider) != FxSource.frankfurter) return;
    final prefs = ref.read(sharedPrefProvider);
    final today = _today();
    // Keyed by main currency too: changing it needs rates for new pairs.
    final stamp = '$today:${ref.read(currencyStateProvider).code}';
    if (!force && prefs.getString(_lastSyncKey) == stamp) return;

    _running = true;
    try {
      final main = ref.read(currencyStateProvider).code;
      final accounts = await ref.read(accountRepositoryProvider).selectAll();
      final codes = {
        for (final account in accounts)
          if (account.deletedAt == null &&
              account.currency != null &&
              account.currency != main)
            account.currency!,
      };
      final repository = ref.read(exchangeRateRepositoryProvider);
      final client = FrankfurterClient();
      var complete = true;
      var fetchedAny = false;
      final now = DateTime.now();
      for (final code in codes) {
        final latest = await repository.latestDate(code, main);
        DateTime from;
        if (latest != null) {
          from = DateTime.parse(latest);
        } else {
          final earliest = await repository.earliestTransaction(code);
          // A few days before, so the first transaction has a prior rate.
          from = (earliest ?? now).subtract(const Duration(days: 7));
        }
        final rates = await client.series(
          base: code,
          quote: main,
          from: from,
          to: now,
        );
        if (rates.isEmpty) {
          complete = false;
          continue;
        }
        await repository.upsert(rates);
        fetchedAny = true;
      }
      if (complete) await prefs.setString(_lastSyncKey, stamp);
      if (fetchedAny) ref.invalidate(fxTableProvider);
    } finally {
      _running = false;
    }
  }
}
