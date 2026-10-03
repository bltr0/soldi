import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/constants.dart';
import '../../model/bank_account.dart';
import '../../model/transaction.dart';
import '../../providers/accounts_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../ui/device.dart';
import '../../ui/extensions.dart';
import '../../ui/snack_bars/transactions_snack_bars.dart';
import '../../ui/theme/dashboard_visual_theme.dart';
import '../../ui/widgets/animated_amount.dart';
import '../../ui/widgets/atmospheric_background.dart';
import '../../ui/widgets/blur_widget.dart';
import '../../ui/widgets/section_header.dart';
import '../../ui/widgets/segmented_pill.dart';
import '../../ui/widgets/tonal_glass_surface.dart';
import 'widgets/ledger_day_group.dart';
import 'widgets/reconcile_dialog.dart';

enum _TypeFilter { all, income, expense, transfer, adjustment }

enum _PeriodFilter { all, month, quarter, year }

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _searchController = TextEditingController();
  _TypeFilter _type = _TypeFilter.all;
  _PeriodFilter _period = _PeriodFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(LedgerEntry entry, DateTime? since) {
    final t = entry.transaction;
    if (since != null && t.date.isBefore(since)) return false;
    final typeOk = switch (_type) {
      _TypeFilter.all => true,
      _TypeFilter.adjustment => t.isBalanceReset,
      _TypeFilter.income =>
        !t.isBalanceReset && t.type == TransactionType.income,
      _TypeFilter.expense =>
        !t.isBalanceReset && t.type == TransactionType.expense,
      _TypeFilter.transfer => t.type == TransactionType.transfer,
    };
    if (!typeOk) return false;
    if (_query.isEmpty) return true;
    final haystack = [
      t.note,
      t.categoryName,
      t.bankAccountName,
      t.bankAccountTransferName,
      t.amount.toCurrency(),
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(_query);
  }

  DateTime? get _since {
    final now = DateTime.now();
    return switch (_period) {
      _PeriodFilter.all => null,
      _PeriodFilter.month => DateTime(now.year, now.month),
      _PeriodFilter.quarter => DateTime(now.year, now.month - 2),
      _PeriodFilter.year => DateTime(now.year),
    };
  }

  /// Groups the ledger by day (newest first), keeping the real end-of-day
  /// balance even when filters hide some of that day's transactions.
  List<LedgerDay> _days(List<LedgerEntry> ledger) {
    final since = _since;
    final byDay = <DateTime, List<LedgerEntry>>{};
    final endBalance = <DateTime, num>{};
    for (final entry in ledger) {
      final d = DateUtils.dateOnly(entry.transaction.date);
      endBalance[d] = entry.balanceAfter;
      if (_matches(entry, since)) (byDay[d] ??= []).add(entry);
    }
    return [
      for (final day in byDay.keys.sorted((a, b) => b.compareTo(a)))
        LedgerDay(
          date: day,
          entries: byDay[day]!.reversed.toList(),
          endBalance: endBalance[day]!,
        ),
    ];
  }

  Future<void> _openReconcile(
    BankAccount account,
    List<LedgerEntry> ledger,
  ) async {
    final result = await showReconcileDialog(
      context,
      account: account,
      ledger: ledger,
    );
    if (result == null) return;
    await ref
        .read(accountsProvider.notifier)
        .reconcileAccount(
          account: account,
          newBalance: result.balance,
          date: result.date,
        );
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final selected = ref.watch(selectedAccountProvider);
    final accounts = ref.watch(accountsProvider).value;
    final account =
        accounts?.firstWhereOrNull((a) => a.id == selected?.id) ?? selected;

    ref.listen(
      duplicatedTransactionProvider,
      (prev, curr) => showDuplicatedTransactionSnackBar(
        context,
        transaction: curr,
        ref: ref,
      ),
    );

    return AtmosphericBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          foregroundColor: visual.textPrimary,
          iconTheme: IconThemeData(color: visual.textPrimary),
          title: Text(
            account?.name ?? '',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: visual.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        body: account?.id == null
            ? const SizedBox.shrink()
            : _buildBody(context, account!),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BankAccount account) {
    final visual = context.dashboardTheme;
    final ledgerAsync = ref.watch(accountLedgerProvider(account.id!));
    final ledger = ledgerAsync.value;
    final bottom = MediaQuery.paddingOf(context).bottom + Sizes.xl;

    if (ledger == null) {
      return Center(
        child: ledgerAsync.hasError
            ? Text(
                'Transactions could not be loaded.',
                style: TextStyle(color: visual.textSecondary),
              )
            : CircularProgressIndicator(color: visual.accent),
      );
    }

    final days = _days(ledger);
    final visible = days.expand((d) => d.entries).toList();
    final visibleDeltas = visible
        .where((e) => !e.transaction.isBalanceReset)
        .map((e) => e.delta);
    final moneyIn = visibleDeltas.where((d) => d > 0).sum;
    final moneyOut = visibleDeltas.where((d) => d < 0).sum;
    final balance = ledger.isEmpty
        ? account.startingValue
        : ledger.last.balanceAfter;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.lg,
                Sizes.sm,
                Sizes.lg,
                0,
              ),
              sliver: SliverList.list(
                children: [
                  _AccountHero(
                    account: account,
                    balance: balance,
                    moneyIn: moneyIn,
                    moneyOut: moneyOut,
                    onReconcile: () => _openReconcile(account, ledger),
                  ),
                  const SizedBox(height: Sizes.lg),
                  _buildFilters(context),
                  const SizedBox(height: Sizes.xl),
                  SectionHeader(
                    title: 'Transactions',
                    subtitle: 'Daily change and balance at end of day',
                    trailing: Text(
                      '${visible.length} ${visible.length == 1 ? 'item' : 'items'}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: visual.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: Sizes.md),
                ],
              ),
            ),
            if (days.isEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(Sizes.lg, 0, Sizes.lg, bottom),
                sliver: SliverToBoxAdapter(
                  child: TonalGlassSurface(
                    padding: const EdgeInsets.all(Sizes.xl),
                    child: Text(
                      ledger.isEmpty
                          ? 'No transactions on this account yet.'
                          : 'No transactions match these filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: visual.textSecondary),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(Sizes.lg, 0, Sizes.lg, bottom),
                sliver: SliverList.separated(
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Sizes.lg),
                  itemBuilder: (context, index) =>
                      LedgerDayGroup(day: days[index], accountId: account.id!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final visual = context.dashboardTheme;
    return TonalGlassSurface(
      padding: const EdgeInsets.all(Sizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            style: TextStyle(color: visual.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search description, category, amount',
              hintStyle: TextStyle(color: visual.textSecondary),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: visual.textSecondary,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: visual.textSecondary,
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                      }),
                    ),
              filled: true,
              fillColor: visual.textPrimary.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: Sizes.md),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (filter, label, icon) in const [
                  (_TypeFilter.all, 'All', Icons.all_inclusive_rounded),
                  (_TypeFilter.income, 'Income', Icons.south_west_rounded),
                  (_TypeFilter.expense, 'Expenses', Icons.north_east_rounded),
                  (_TypeFilter.transfer, 'Transfers', Icons.swap_horiz_rounded),
                  (_TypeFilter.adjustment, 'Adjustments', Icons.sync_rounded),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: Sizes.sm),
                    child: _FilterChip(
                      label: label,
                      icon: icon,
                      selected: _type == filter,
                      onTap: () => setState(() => _type = filter),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Sizes.md),
          SegmentedPill<_PeriodFilter>(
            height: 40,
            options: const {
              _PeriodFilter.all: 'All time',
              _PeriodFilter.month: 'Month',
              _PeriodFilter.quarter: '3 months',
              _PeriodFilter.year: 'Year',
            },
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
        ],
      ),
    );
  }
}

class _AccountHero extends ConsumerWidget {
  const _AccountHero({
    required this.account,
    required this.balance,
    required this.moneyIn,
    required this.moneyOut,
    required this.onReconcile,
  });

  final BankAccount account;
  final num balance;
  final num moneyIn;
  final num moneyOut;
  final VoidCallback onReconcile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final symbol = account.currencySymbol(
      ref.watch(currencyStateProvider).symbol,
    );
    final accent =
        accountColorListTheme[account.color.clamp(
          0,
          accountColorListTheme.length - 1,
        )];
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: visual.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
    );

    return TonalGlassSurface(
      tone: GlassTone.hero,
      radius: 30,
      padding: const EdgeInsets.all(Sizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Sizes.sm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  accountIconList[account.symbol] ??
                      Icons.account_balance_wallet_outlined,
                  color: accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: Sizes.md),
              Expanded(child: Text('Current balance', style: labelStyle)),
              SectionAction(
                label: 'Set balance',
                icon: Icons.tune_rounded,
                onTap: onReconcile,
              ),
            ],
          ),
          const SizedBox(height: Sizes.lg),
          BlurWidget(
            sigma: 18,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedAmount(
                value: balance,
                suffix: ' $symbol',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: visual.textPrimary,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 0.95,
                  letterSpacing: -1.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: Sizes.lg),
          Row(
            children: [
              Expanded(
                child: _FlowStat(
                  label: 'In',
                  value: moneyIn,
                  symbol: symbol,
                  color: visual.positive,
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: Sizes.md),
              Expanded(
                child: _FlowStat(
                  label: 'Out',
                  value: moneyOut,
                  symbol: symbol,
                  color: visual.negative,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowStat extends StatelessWidget {
  const _FlowStat({
    required this.label,
    required this.value,
    required this.symbol,
    required this.color,
    required this.icon,
  });

  final String label;
  final num value;
  final String symbol;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.md,
        vertical: Sizes.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Sizes.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: visual.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: Sizes.sm),
          Expanded(
            child: BlurWidget(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${value.toCurrency()} $symbol',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final foreground = selected ? visual.accent : visual.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? visual.accent.withValues(alpha: 0.14)
            : visual.textPrimary.withValues(alpha: 0.05),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? visual.accent.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: Sizes.xs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
