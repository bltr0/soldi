import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/budget.dart';
import '../../../model/category_transaction.dart';
import '../../../model/transaction.dart';
import '../../../providers/budgets_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/accent_button.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';
import '../../graphs/widgets/linear_progress_bar.dart';
import '../manage_budget_page.dart';

class BudgetCard extends ConsumerWidget {
  const BudgetCard({super.key});

  void _openManager(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: ManageBudgetPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final transactionsAsync = ref.watch(monthlyTransactionsProvider);
    final categoriesAsync = ref.watch(allParentCategoriesProvider);
    final visual = context.dashboardTheme;

    return TonalGlassSurface(
      radius: 28,
      padding: const EdgeInsets.all(Sizes.lg),
      child: budgetsAsync.when(
        loading: () => _BudgetLoading(visual: visual),
        error: (_, _) => _BudgetMessage(
          visual: visual,
          text: 'Budgets could not be loaded.',
          action: 'Try again',
          onPressed: () => ref.invalidate(budgetsProvider),
        ),
        data: (budgets) {
          if (categoriesAsync.isLoading || transactionsAsync.isLoading) {
            return _BudgetLoading(visual: visual);
          }
          if (categoriesAsync.hasError || transactionsAsync.hasError) {
            return _BudgetMessage(
              visual: visual,
              text: 'This month could not be loaded.',
              action: 'Try again',
              onPressed: () {
                ref.invalidate(allParentCategoriesProvider);
                ref.invalidate(monthlyTransactionsProvider);
              },
            );
          }
          if (budgets.isEmpty) {
            return _BudgetEmpty(onCreate: () => _openManager(context));
          }
          return _BudgetBody(
            budgets: budgets,
            categories: categoriesAsync.value ?? const [],
            transactions: transactionsAsync.value ?? const [],
            onManage: () => _openManager(context),
          );
        },
      ),
    );
  }
}

class _BudgetBody extends ConsumerWidget {
  const _BudgetBody({
    required this.budgets,
    required this.categories,
    required this.transactions,
    required this.onManage,
  });

  final List<Budget> budgets;
  final List<CategoryTransaction> categories;
  final List<Transaction> transactions;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final symbol = ref.watch(currencyStateProvider).symbol;
    final code = ref.watch(currencyStateProvider).code;
    final rows = <_BudgetRow>[];
    num spentTotal = 0;
    num limitTotal = 0;

    for (final budget in budgets) {
      final category = categories.firstWhereOrNull(
        (cat) => cat.id == budget.idCategory,
      );
      if (category == null) continue;
      final spent = transactions
          .where(
            (t) =>
                t.idCategory == budget.idCategory ||
                t.categoryParent == budget.idCategory,
          )
          .fold<num>(0, (sum, t) => sum + t.personalShare);
      spentTotal += spent;
      limitTotal += budget.amountLimit;
      rows.add(_BudgetRow(budget: budget, category: category, spent: spent));
    }

    final left = limitTotal - spentTotal;
    final over = left < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${spentTotal.toCurrency(code)}$symbol',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: visual.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    over
                        ? '${left.abs().toCurrency(code)}$symbol over ${limitTotal.toCurrency(code)}$symbol'
                        : '${left.toCurrency(code)}$symbol left of ${limitTotal.toCurrency(code)}$symbol',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: over ? visual.negative : visual.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onManage, child: const Text('Edit')),
          ],
        ),
        const SizedBox(height: Sizes.md),
        LinearProgressBar(
          type: BarType.category,
          colorIndex: 0,
          amount: spentTotal,
          total: limitTotal == 0 ? 1 : limitTotal,
        ),
        const SizedBox(height: Sizes.lg),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: Sizes.md),
          _CategoryBudget(row: rows[i], symbol: symbol, code: code),
        ],
      ],
    );
  }
}

class _BudgetRow {
  const _BudgetRow({
    required this.budget,
    required this.category,
    required this.spent,
  });

  final Budget budget;
  final CategoryTransaction category;
  final num spent;
}

class _CategoryBudget extends StatelessWidget {
  const _CategoryBudget({
    required this.row,
    required this.symbol,
    required this.code,
  });

  final _BudgetRow row;
  final String symbol;
  final String code;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final spent = row.spent;
    final limit = row.budget.amountLimit;
    final tight = limit > 0 && spent >= limit * 0.9;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.budget.name ?? row.category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${spent.toCurrency(code)} / ${limit.toCurrency(code)}$symbol',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tight ? visual.negative : visual.textSecondary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: Sizes.xs),
        LinearProgressBar(
          type: BarType.category,
          colorIndex: row.category.color,
          amount: spent,
          total: limit,
        ),
      ],
    );
  }
}

class _BudgetEmpty extends StatelessWidget {
  const _BudgetEmpty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Column(
      children: [
        const SizedBox(height: Sizes.sm),
        Text(
          'No monthly limits yet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: visual.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Sizes.xs),
        Text(
          'Set a limit per category and watch this month fill in.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: visual.textSecondary),
        ),
        const SizedBox(height: Sizes.lg),
        AccentButton(label: 'Create budget', onPressed: onCreate),
        const SizedBox(height: Sizes.sm),
      ],
    );
  }
}

class _BudgetLoading extends StatelessWidget {
  const _BudgetLoading({required this.visual});

  final DashboardVisualTheme visual;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Center(child: CircularProgressIndicator(color: visual.accent)),
    );
  }
}

class _BudgetMessage extends StatelessWidget {
  const _BudgetMessage({
    required this.visual,
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final DashboardVisualTheme visual;
  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(text, style: TextStyle(color: visual.textSecondary)),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
