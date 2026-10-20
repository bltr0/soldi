import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/constants.dart';
import '../../model/transaction.dart';
import '../../providers/accounts_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/main_converter_provider.dart';
import '../../providers/search_provider.dart';
import '../../ui/device.dart';
import '../../ui/extensions.dart';
import '../../ui/formatters/decimal_text_input_formatter.dart';
import '../../ui/theme/dashboard_visual_theme.dart';
import '../../ui/widgets/accent_button.dart';
import '../../ui/widgets/blur_widget.dart';
import '../../ui/widgets/picker_sheet.dart';
import '../../ui/widgets/settings_tiles.dart';
import '../../ui/widgets/transactions_list.dart';

/// Finds transactions by any word (note, category, account, place) or
/// amount, narrowed by period, type, account, category and amount range.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref
          .read(searchFiltersProvider.notifier)
          .update((f) => f.copyWith(text: value));
    });
  }

  void _setText(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _debounce?.cancel();
    setState(() {});
    ref
        .read(searchFiltersProvider.notifier)
        .update((f) => f.copyWith(text: value));
  }

  /// Remembers the text once it found something worth coming back to.
  void _remember() {
    final text = _controller.text;
    if (ref.read(searchResultsProvider).value?.isNotEmpty ?? false) {
      ref.read(recentSearchesProvider.notifier).add(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final filters = ref.watch(searchFiltersProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            _remember();
            Navigator.pop(context);
          },
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Sizes.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: visual.textPrimary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) => _remember(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Note, category, account, place, 12.50…',
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _setText(''),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(filters: filters),
          Expanded(
            child: filters.isEmpty
                ? _Idle(onPick: _setText)
                : results.when(
                    data: (data) => data.isEmpty
                        ? _NoMatch(filters: filters)
                        : ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              Sizes.lg,
                              Sizes.sm,
                              Sizes.lg,
                              MediaQuery.paddingOf(context).bottom + Sizes.xl,
                            ),
                            children: [
                              _Summary(transactions: data),
                              const SizedBox(height: Sizes.lg),
                              TransactionsList(
                                margin: EdgeInsets.zero,
                                transactions: data,
                              ),
                            ],
                          ),
                    loading: () => Center(
                      child: CircularProgressIndicator(color: visual.accent),
                    ),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One pill per filter; tapping opens its sheet, filled pills are active.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filters});

  final SearchFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final currency = ref.watch(currencyStateProvider);

    String many(Set<int> ids, String none, String Function(int) name) =>
        switch (ids.length) {
          0 => none,
          1 => name(ids.first),
          _ => '$none · ${ids.length}',
        };

    final (from, to) = filters.range;
    final periodLabel = filters.period == SearchPeriod.custom && from != null
        ? '${from.formatDMY()} – ${(to ?? from).formatDMY()}'
        : filters.period == SearchPeriod.all
        ? 'Any date'
        : filters.period.label;

    final amountLabel = switch ((filters.minAmount, filters.maxAmount)) {
      (null, null) => 'Amount',
      (final min?, null) => '≥ ${min.toCurrency(currency.code)}',
      (null, final max?) => '≤ ${max.toCurrency(currency.code)}',
      (final min?, final max?) =>
        '${min.toCurrency(currency.code)} – ${max.toCurrency(currency.code)}',
    };

    final pills = <Widget>[
      _FilterPill(
        icon: Icons.calendar_today_rounded,
        label: periodLabel,
        active: filters.period != SearchPeriod.all,
        onTap: () => _pickPeriod(context, ref),
      ),
      _FilterPill(
        icon: Icons.swap_vert_rounded,
        label: switch (filters.types.length) {
          0 => 'Type',
          1 => filters.types.first.name.capitalize(),
          _ => 'Type · ${filters.types.length}',
        },
        active: filters.types.isNotEmpty,
        onTap: () => _pickTypes(context, ref),
      ),
      _FilterPill(
        icon: Icons.account_balance_wallet_rounded,
        label: many(
          filters.accountIds,
          'Account',
          (id) => accounts.where((a) => a.id == id).firstOrNull?.name ?? '?',
        ),
        active: filters.accountIds.isNotEmpty,
        onTap: () => _pickAccounts(context, ref),
      ),
      _FilterPill(
        icon: Icons.category_rounded,
        label: many(
          filters.categoryIds,
          'Category',
          (id) => categories.where((c) => c.id == id).firstOrNull?.name ?? '?',
        ),
        active: filters.categoryIds.isNotEmpty,
        onTap: () => _pickCategories(context, ref),
      ),
      _FilterPill(
        icon: Icons.euro_rounded,
        label: amountLabel,
        active: filters.minAmount != null || filters.maxAmount != null,
        onTap: () => _pickAmount(context, ref),
      ),
    ];

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
        children: [
          if (filters.hasFilters)
            Padding(
              padding: const EdgeInsets.only(right: Sizes.sm),
              child: TogglePill(
                label: 'Clear',
                selected: false,
                leading: const Icon(Icons.filter_alt_off_rounded, size: 16),
                onTap: ref.read(searchFiltersProvider.notifier).clearFilters,
              ),
            ),
          for (final pill in pills)
            Padding(
              padding: const EdgeInsets.only(right: Sizes.sm),
              child: pill,
            ),
        ],
      ),
    );
  }

  void _update(WidgetRef ref, SearchFilters Function(SearchFilters) change) =>
      ref.read(searchFiltersProvider.notifier).update(change);

  Future<void> _pickPeriod(BuildContext context, WidgetRef ref) async {
    final choice = await showPickerSheet<SearchPeriod>(
      context,
      scrollable: false,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PickerSheetHeader(title: 'Period'),
          for (final period in SearchPeriod.values)
            PickerRow(
              title: period.label == 'All time' ? 'Any date' : period.label,
              selected: ref.read(searchFiltersProvider).period == period,
              onTap: () => Navigator.pop(context, period),
            ),
          const SizedBox(height: Sizes.md),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice != SearchPeriod.custom) {
      _update(ref, (f) => f.copyWith(period: choice));
      return;
    }
    final now = DateTime.now();
    final current = ref.read(searchFiltersProvider);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 5),
      initialDateRange: current.customFrom != null && current.customTo != null
          ? DateTimeRange(start: current.customFrom!, end: current.customTo!)
          : null,
    );
    if (range == null) return;
    _update(
      ref,
      (f) => f.copyWith(
        period: SearchPeriod.custom,
        customFrom: range.start,
        customTo: range.end,
      ),
    );
  }

  Future<void> _pickTypes(BuildContext context, WidgetRef ref) =>
      showPickerSheet<void>(
        context,
        scrollable: false,
        builder: (context, _) => Consumer(
          builder: (context, ref, _) {
            final selected = ref.watch(searchFiltersProvider).types;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PickerSheetHeader(
                  title: 'Type',
                  subtitle: 'None selected shows every type',
                ),
                for (final type in TransactionType.values)
                  PickerRow(
                    title: type.name.capitalize(),
                    selected: selected.contains(type),
                    onTap: () => _update(
                      ref,
                      (f) => f.copyWith(types: _toggle(f.types, type)),
                    ),
                  ),
                const SizedBox(height: Sizes.md),
              ],
            );
          },
        ),
      );

  Future<void> _pickAccounts(BuildContext context, WidgetRef ref) =>
      showPickerSheet<void>(
        context,
        builder: (context, controller) => Consumer(
          builder: (context, ref, _) {
            final selected = ref.watch(searchFiltersProvider).accountIds;
            final accounts = ref.watch(accountsProvider).value ?? const [];
            return ListView(
              controller: controller,
              children: [
                const PickerSheetHeader(
                  title: 'Accounts',
                  subtitle: 'Transfers match either side',
                ),
                for (final account in accounts)
                  PickerRow(
                    leading: PickerIcon(
                      icon: accountIconList[account.symbol],
                      color: accountColorListTheme[account.color],
                    ),
                    title: account.name,
                    selected: selected.contains(account.id),
                    onTap: () => _update(
                      ref,
                      (f) => f.copyWith(
                        accountIds: _toggle(f.accountIds, account.id!),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );

  Future<void> _pickCategories(BuildContext context, WidgetRef ref) =>
      showPickerSheet<void>(
        context,
        builder: (context, controller) => Consumer(
          builder: (context, ref, _) {
            final selected = ref.watch(searchFiltersProvider).categoryIds;
            final all = ref.watch(categoriesProvider).value ?? const [];
            final parents = all.where((c) => c.parent == null).toList();
            return ListView(
              controller: controller,
              children: [
                const PickerSheetHeader(
                  title: 'Categories',
                  subtitle: 'A category includes its subcategories',
                ),
                for (final parent in parents) ...[
                  for (final category in [
                    parent,
                    ...all.where((c) => c.parent == parent.id),
                  ])
                    PickerRow(
                      indent: category.parent == null ? 0 : Sizes.xl,
                      leading: PickerIcon(
                        icon: iconList[category.symbol],
                        color: categoryColorListTheme[category.color],
                      ),
                      title: category.name,
                      subtitle: category.parent == null
                          ? category.type.name.capitalize()
                          : null,
                      selected: selected.contains(category.id),
                      onTap: () => _update(
                        ref,
                        (f) => f.copyWith(
                          categoryIds: _toggle(f.categoryIds, category.id!),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      );

  Future<void> _pickAmount(BuildContext context, WidgetRef ref) =>
      showPickerSheet<void>(
        context,
        scrollable: false,
        builder: (context, _) => _AmountSheet(
          initial: ref.read(searchFiltersProvider),
          onApply: (min, max) => _update(
            ref,
            (f) => f.copyWith(minAmount: () => min, maxAmount: () => max),
          ),
        ),
      );

  static Set<T> _toggle<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return TogglePill(
      label: label,
      selected: active,
      leading: Icon(
        icon,
        size: 16,
        color: active
            ? visual.navigationFill.withValues(alpha: 1)
            : visual.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.initial, required this.onApply});

  final SearchFilters initial;
  final void Function(num? min, num? max) onApply;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final _min = TextEditingController(
    text: widget.initial.minAmount?.toString() ?? '',
  );
  late final _max = TextEditingController(
    text: widget.initial.maxAmount?.toString() ?? '',
  );

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  num? _parse(TextEditingController c) =>
      num.tryParse(c.text.trim().replaceAll(',', '.'));

  Widget _field(TextEditingController controller, String label) => Expanded(
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [DecimalTextInputFormatter(decimalDigits: 2)],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PickerSheetHeader(
            title: 'Amount',
            subtitle: 'In each account\'s own currency, sign ignored',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
            child: Row(
              children: [
                _field(_min, 'At least'),
                const SizedBox(width: Sizes.md),
                _field(_max, 'At most'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Sizes.lg),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    widget.onApply(null, null);
                    Navigator.pop(context);
                  },
                  child: const Text('Any amount'),
                ),
                const Spacer(),
                AccentButton(
                  label: 'Apply',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    widget.onApply(_parse(_min), _parse(_max));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Count and money in/out of the matches, in the main currency.
class _Summary extends ConsumerWidget {
  const _Summary({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = ref.watch(currencyStateProvider);
    final converter = ref.watch(mainConverterProvider).value;

    var income = 0.0, expense = 0.0;
    for (final t in transactions) {
      if (t.isBalanceReset) continue;
      final value = converter?.transaction(t) ?? t.amount.toDouble();
      switch (t.type) {
        case TransactionType.income:
          income += value;
        case TransactionType.expense:
          expense += value;
        case TransactionType.transfer || TransactionType.adjustment:
          break;
      }
    }
    final net = income - expense;
    String money(num v) => '${v.toCurrency(currency.code)} ${currency.symbol}';

    Widget stat(String label, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: visual.textSecondary),
          ),
          const SizedBox(height: Sizes.xxs),
          BlurWidget(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(Sizes.lg),
      decoration: BoxDecoration(
        color: visual.solidSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: visual.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transactions.length >= 500
                ? 'First 500 results'
                : '${transactions.length} '
                      'result${transactions.length == 1 ? '' : 's'}',
            style: textTheme.titleSmall?.copyWith(
              color: visual.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sizes.md),
          Row(
            children: [
              stat('In', money(income), visual.positive),
              stat('Out', money(-expense), visual.negative),
              stat(
                'Net',
                money(net),
                net < 0 ? visual.negative : visual.positive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Before anything is typed: recent searches and what can be searched.
class _Idle extends ConsumerWidget {
  const _Idle({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final recent = ref.watch(recentSearchesProvider);
    final hint = textTheme.bodyMedium?.copyWith(color: visual.textSecondary);

    return ListView(
      padding: const EdgeInsets.all(Sizes.lg),
      children: [
        if (recent.isNotEmpty) ...[
          const PickerSectionLabel('Recent'),
          const SizedBox(height: Sizes.sm),
          Wrap(
            spacing: Sizes.sm,
            runSpacing: Sizes.sm,
            children: [
              for (final text in recent)
                InputChip(
                  label: Text(text),
                  onPressed: () => onPick(text),
                  onDeleted: () =>
                      ref.read(recentSearchesProvider.notifier).remove(text),
                ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
        ],
        const PickerSectionLabel('You can search for'),
        const SizedBox(height: Sizes.sm),
        for (final (icon, text) in [
          (Icons.notes_rounded, 'Words in a note'),
          (Icons.category_rounded, 'A category or subcategory name'),
          (Icons.account_balance_wallet_rounded, 'An account name'),
          (Icons.place_rounded, 'A place name or address'),
          (Icons.pin_rounded, 'An amount: 12 finds 12.00 to 12.99'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sizes.xs),
            child: Row(
              children: [
                Icon(icon, size: 18, color: visual.textSecondary),
                const SizedBox(width: Sizes.md),
                Expanded(child: Text(text, style: hint)),
              ],
            ),
          ),
        const SizedBox(height: Sizes.sm),
        Text(
          'Several words must all match. Or skip typing and use the filters '
          'above, e.g. every expense over 100 last month.',
          style: textTheme.bodySmall?.copyWith(color: visual.textSecondary),
        ),
      ],
    );
  }
}

class _NoMatch extends ConsumerWidget {
  const _NoMatch({required this.filters});

  final SearchFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: visual.textSecondary,
            ),
            const SizedBox(height: Sizes.md),
            Text(
              'No matching transaction',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: visual.textPrimary),
            ),
            if (filters.hasFilters) ...[
              const SizedBox(height: Sizes.md),
              TextButton.icon(
                onPressed: ref
                    .read(searchFiltersProvider.notifier)
                    .clearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Search without filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
