// Satistics page.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/currency_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../ui/device.dart';
import '../../ui/extensions.dart';
import '../../ui/theme/dashboard_visual_theme.dart';
import '../../ui/widgets/animated_amount.dart';
import '../../ui/widgets/blur_widget.dart';
import '../../ui/widgets/line_chart.dart';
import '../../ui/widgets/tonal_glass_surface.dart';
import 'widgets/accounts/accounts_card.dart';
import 'widgets/categories/categories_card.dart';

class GraphsPage extends ConsumerStatefulWidget {
  const GraphsPage({super.key});

  @override
  ConsumerState<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends ConsumerState<GraphsPage> {
  @override
  Widget build(BuildContext context) {
    final insets = Sizes.responsiveInsets(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        insets,
        MediaQuery.paddingOf(context).top + Sizes.lg,
        insets,
        MediaQuery.paddingOf(context).bottom + Sizes.xl,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ref
                    .watch(statisticsProvider)
                    .when(
                      data: (_) => const _NetWorthHero(),
                      loading: () => const SizedBox(height: 360),
                      error: (error, stack) => Text('Error: $error'),
                    ),
                const SizedBox(height: Sizes.xl),
                const AccountsCard(),
                const SizedBox(height: Sizes.xl),
                const CategoriesCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NetWorthHero extends ConsumerWidget {
  const _NetWorthHero();

  static const double _chartHeight = 210;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final monthly = ref.watch(currentYearMontlyTransactionsProvider);
    final currency = ref.watch(currencyStateProvider);
    final isVisible = ref.watch(visibilityAmountProvider);

    final netWorth = monthly.isNotEmpty ? monthly.last.y : 0.0;
    final previous = monthly.length > 1 ? monthly[monthly.length - 2].y : 0.0;
    final showChange = previous.abs() >= 0.005;
    final change = showChange
        ? (monthly.last.y - previous) / previous.abs() * 100
        : 0.0;
    final changeColor = change > 0
        ? visual.positive
        : change < 0
        ? visual.negative
        : visual.textSecondary;

    return TonalGlassSurface(
      tone: GlassTone.hero,
      radius: 30,
      padding: const EdgeInsets.all(Sizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Net worth',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: visual.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (showChange) _ChangePill(change: change, color: changeColor),
            ],
          ),
          const SizedBox(height: Sizes.md),
          Semantics(
            label: isVisible
                ? 'Net worth ${netWorth.toCurrency(currency.code)} ${currency.code}'
                : 'Net worth hidden',
            excludeSemantics: true,
            child: BlurWidget(
              sigma: 18,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedAmount(
                  value: netWorth,
                  suffix: ' ${currency.symbol}',
                  code: currency.code,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: visual.textPrimary,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                    letterSpacing: -1.6,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Sizes.sm),
          Text(
            'This year, month by month',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: visual.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: Sizes.lg),
          SizedBox(
            height: _chartHeight,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              child: isVisible
                  ? LineChartWidget(
                      key: const ValueKey('chart'),
                      lineData: monthly,
                      enableGapFilling: false,
                      period: Period.year,
                      lineColor: visual.chartPrimary,
                      colorBackground: Colors.transparent,
                      dashboardStyle: true,
                      height: _chartHeight,
                    )
                  : Center(
                      key: const ValueKey('private'),
                      child: Icon(
                        Icons.visibility_off_outlined,
                        color: visual.textSecondary,
                        size: 30,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePill extends StatelessWidget {
  const _ChangePill({required this.change, required this.color});

  final double change;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = change > 0
        ? Icons.trending_up_rounded
        : change < 0
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    return Semantics(
      label: '${change.toCurrency()} percent versus last month',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Sizes.md,
            vertical: Sizes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: Sizes.xs),
              BlurWidget(
                sigma: 8,
                child: Text(
                  '${change > 0 ? '+' : ''}${change.toCurrency()}% vs last month',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
