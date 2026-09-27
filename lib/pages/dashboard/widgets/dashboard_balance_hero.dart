import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/currency_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/animated_amount.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/widgets/line_chart.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';

class DashboardBalanceHero extends ConsumerWidget {
  const DashboardBalanceHero({required this.snapshot, super.key});

  final AsyncValue<DashboardSnapshot> snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: snapshot.when(
        data: (data) => _HeroContent(
          key: const ValueKey('dashboard-hero-data'),
          snapshot: data,
        ),
        loading: () =>
            const _HeroLoading(key: ValueKey('dashboard-hero-loading')),
        error: (error, _) => _HeroError(
          key: const ValueKey('dashboard-hero-error'),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
      ),
    );
  }
}

class _HeroContent extends ConsumerWidget {
  const _HeroContent({required this.snapshot, super.key});

  static const double _chartHeight = 148;

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final currency = ref.watch(currencyStateProvider);
    final isVisible = ref.watch(visibilityAmountProvider);
    final titleStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
      color: visual.textPrimary,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      height: 0.95,
      letterSpacing: -1.8,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return TonalGlassSurface(
      tone: GlassTone.hero,
      radius: 30,
      padding: const EdgeInsets.all(Sizes.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Monthly balance',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: visual.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              _PeriodCapsule(
                label: DateFormat('MMMM yyyy').format(DateTime.now()),
              ),
            ],
          ),
          const SizedBox(height: Sizes.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  label: isVisible
                      ? 'Monthly balance ${snapshot.balance.toCurrency()} ${currency.code}'
                      : 'Monthly balance hidden',
                  excludeSemantics: true,
                  child: BlurWidget(
                    sigma: 18,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedAmount(
                        value: snapshot.balance,
                        suffix: ' ${currency.symbol}',
                        style: titleStyle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Sizes.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SideAmount(
                    label: 'Income',
                    amount: snapshot.income,
                    symbol: currency.symbol,
                    color: visual.positive,
                  ),
                  const SizedBox(height: Sizes.xs),
                  _SideAmount(
                    label: 'Expenses',
                    amount: -snapshot.expense,
                    symbol: currency.symbol,
                    color: visual.negative,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Sizes.md),
          SizedBox(
            height: _chartHeight,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: !snapshot.hasCashFlow
                  ? _EmptyChart(key: const ValueKey('empty'), visual: visual)
                  : isVisible
                  ? LineChartWidget(
                      key: const ValueKey('chart'),
                      lineData: snapshot.currentMonth,
                      line2Data: snapshot.previousMonth,
                      lineColor: visual.chartPrimary,
                      line2Color: visual.chartSecondary,
                      colorBackground: Colors.transparent,
                      ignoreBlur: true,
                      dashboardStyle: true,
                      height: _chartHeight,
                    )
                  : _PrivateChart(
                      key: const ValueKey('private'),
                      visual: visual,
                    ),
            ),
          ),
          const SizedBox(height: Sizes.sm),
          Wrap(
            spacing: Sizes.lg,
            runSpacing: Sizes.xs,
            children: [
              _LegendItem(
                color: visual.chartPrimary,
                label: 'Current month',
                solid: true,
              ),
              _LegendItem(
                color: visual.chartSecondary,
                label: 'Previous month',
                solid: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodCapsule extends StatelessWidget {
  const _PeriodCapsule({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: visual.glassFill,
        border: Border.all(color: visual.glassBorder),
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
            Icon(
              Icons.calendar_month_outlined,
              size: 17,
              color: visual.textSecondary,
            ),
            const SizedBox(width: Sizes.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: visual.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideAmount extends StatelessWidget {
  const _SideAmount({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.color,
  });

  final String label;
  final num amount;
  final String symbol;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label ${amount.toCurrency()} $symbol',
      excludeSemantics: true,
      child: BlurWidget(
        sigma: 14,
        child: AnimatedAmount(
          value: amount,
          suffix: symbol,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.solid,
  });

  final Color color;
  final String label;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: solid ? 3 : 2,
          decoration: BoxDecoration(
            color: solid ? color : null,
            border: solid ? null : Border.all(color: color),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: Sizes.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: visual.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.visual, super.key});

  final DashboardVisualTheme visual;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _HeroContent._chartHeight,
      child: Center(
        child: Text(
          'Your monthly trend will appear here',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: visual.textSecondary),
        ),
      ),
    );
  }
}

class _PrivateChart extends StatelessWidget {
  const _PrivateChart({required this.visual, super.key});

  final DashboardVisualTheme visual;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Monthly trend hidden',
      child: ExcludeSemantics(
        child: SizedBox(
          height: _HeroContent._chartHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_off_outlined,
                  color: visual.textSecondary,
                  size: 28,
                ),
                const SizedBox(height: Sizes.sm),
                Text(
                  'Trend hidden for privacy',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: visual.textSecondary,
                    fontWeight: FontWeight.w600,
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

class _HeroLoading extends StatelessWidget {
  const _HeroLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return TonalGlassSurface(
      tone: GlassTone.hero,
      radius: 30,
      padding: const EdgeInsets.all(Sizes.xl),
      child: SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(color: visual.accent)),
      ),
    );
  }
}

class _HeroError extends StatelessWidget {
  const _HeroError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return TonalGlassSurface(
      tone: GlassTone.hero,
      radius: 30,
      padding: const EdgeInsets.all(Sizes.xl),
      child: SizedBox(
        height: 240,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: visual.textSecondary,
                size: 32,
              ),
              const SizedBox(height: Sizes.sm),
              Text(
                'The monthly overview could not be loaded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: visual.textSecondary),
              ),
              const SizedBox(height: Sizes.md),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
