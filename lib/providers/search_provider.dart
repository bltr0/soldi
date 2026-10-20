import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/transaction.dart';
import '../services/database/repositories/transactions_repository.dart';
import 'settings_provider.dart';
import 'transactions_provider.dart';

part 'search_provider.g.dart';

/// Preset windows for the search date filter; [custom] uses explicit days.
enum SearchPeriod {
  all('All time'),
  thisMonth('This month'),
  lastMonth('Last month'),
  last30('Last 30 days'),
  last90('Last 3 months'),
  thisYear('This year'),
  lastYear('Last year'),
  custom('Custom');

  const SearchPeriod(this.label);

  final String label;
}

class SearchFilters {
  const SearchFilters({
    this.text = '',
    this.types = const {},
    this.accountIds = const {},
    this.categoryIds = const {},
    this.period = SearchPeriod.all,
    this.customFrom,
    this.customTo,
    this.minAmount,
    this.maxAmount,
  });

  final String text;
  final Set<TransactionType> types;
  final Set<int> accountIds;
  final Set<int> categoryIds;
  final SearchPeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;
  final num? minAmount;
  final num? maxAmount;

  /// Anything besides the text narrows the search.
  bool get hasFilters =>
      types.isNotEmpty ||
      accountIds.isNotEmpty ||
      categoryIds.isNotEmpty ||
      period != SearchPeriod.all ||
      minAmount != null ||
      maxAmount != null;

  bool get isEmpty => text.trim().isEmpty && !hasFilters;

  /// First and last day covered by [period], either may be open.
  (DateTime?, DateTime?) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      SearchPeriod.all => (null, null),
      SearchPeriod.thisMonth => (DateTime(now.year, now.month), today),
      SearchPeriod.lastMonth => (
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month, 0),
      ),
      SearchPeriod.last30 => (today.subtract(const Duration(days: 30)), today),
      SearchPeriod.last90 => (today.subtract(const Duration(days: 90)), today),
      SearchPeriod.thisYear => (DateTime(now.year), today),
      SearchPeriod.lastYear => (
        DateTime(now.year - 1),
        DateTime(now.year - 1, 12, 31),
      ),
      SearchPeriod.custom => (customFrom, customTo),
    };
  }

  SearchFilters copyWith({
    String? text,
    Set<TransactionType>? types,
    Set<int>? accountIds,
    Set<int>? categoryIds,
    SearchPeriod? period,
    DateTime? customFrom,
    DateTime? customTo,
    num? Function()? minAmount,
    num? Function()? maxAmount,
  }) => SearchFilters(
    text: text ?? this.text,
    types: types ?? this.types,
    accountIds: accountIds ?? this.accountIds,
    categoryIds: categoryIds ?? this.categoryIds,
    period: period ?? this.period,
    customFrom: customFrom ?? this.customFrom,
    customTo: customTo ?? this.customTo,
    minAmount: minAmount != null ? minAmount() : this.minAmount,
    maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
  );
}

/// What the search page is looking for; reset each time the page opens.
@riverpod
class SearchFiltersNotifier extends _$SearchFiltersNotifier {
  @override
  SearchFilters build() => const SearchFilters();

  void update(SearchFilters Function(SearchFilters) change) =>
      state = change(state);

  /// Keeps the text, drops every filter.
  void clearFilters() => state = SearchFilters(text: state.text);
}

/// Matches for [searchFiltersProvider], refreshed when transactions change
/// (e.g. one edited from the results).
@riverpod
Future<List<Transaction>> searchResults(Ref ref) async {
  final filters = ref.watch(searchFiltersProvider);
  ref.watch(transactionsProvider);
  if (filters.isEmpty) return const [];
  final (from, to) = filters.range;
  return ref
      .read(transactionsRepositoryProvider)
      .search(
        text: filters.text,
        types: filters.types,
        accountIds: filters.accountIds,
        categoryIds: filters.categoryIds,
        from: from,
        to: to,
        minAmount: filters.minAmount,
        maxAmount: filters.maxAmount,
      );
}

const _recentKey = 'search_recent';

/// Last searched words, newest first, offered when the field is empty.
@Riverpod(keepAlive: true)
class RecentSearches extends _$RecentSearches {
  static const _max = 8;

  @override
  List<String> build() =>
      ref.watch(sharedPrefProvider).getStringList(_recentKey) ?? const [];

  Future<void> add(String text) async {
    final value = text.trim();
    if (value.length < 2) return;
    state = [
      value,
      ...state.where((s) => s.toLowerCase() != value.toLowerCase()),
    ].take(_max).toList();
    await ref.read(sharedPrefProvider).setStringList(_recentKey, state);
  }

  Future<void> remove(String text) async {
    state = state.where((s) => s != text).toList();
    await ref.read(sharedPrefProvider).setStringList(_recentKey, state);
  }
}
