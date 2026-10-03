// Defines application's structure

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import '../ui/device.dart';
import '../ui/theme/dashboard_visual_theme.dart';
import '../ui/widgets/app_navigation_bar.dart';
import '../ui/widgets/atmospheric_background.dart';
import '../ui/widgets/tonal_glass_surface.dart';
import 'dashboard/dashboard_page.dart';
import 'graphs/graphs_page.dart';
import 'planning/planning_page.dart';
import 'transactions/transactions_page.dart';

class Structure extends ConsumerStatefulWidget {
  const Structure({super.key});

  @override
  ConsumerState<Structure> createState() => _StructureState();
}

class _StructureState extends ConsumerState<Structure> {
  AppDestination _selected = AppDestination.dashboard;

  Widget get _selectedPage => switch (_selected) {
    AppDestination.dashboard => const DashboardPage(),
    AppDestination.transactions => const TransactionsPage(),
    AppDestination.planning => const PlanningPage(),
    AppDestination.graphs => const GraphsPage(),
  };

  String get _selectedTitle => switch (_selected) {
    AppDestination.dashboard => 'Dashboard',
    AppDestination.transactions => 'Transactions',
    AppDestination.planning => 'Planning',
    AppDestination.graphs => 'Graphs',
  };

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(visibilityAmountProvider);
    final isDashboard = _selected == AppDestination.dashboard;

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AtmosphericBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        // Keep the body's top edge fixed for every tab. Toggling this per tab
        // moved the body by the bar's height in the same frame the cross-fade
        // started, so the outgoing page jumped while it faded.
        extendBodyBehindAppBar: false,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(_topBarHeight),
          child: _TopControls(
            title: isDashboard ? null : _selectedTitle,
            isVisible: isVisible,
            onSearch: () => Navigator.of(context).pushNamed('/search'),
            onVisibility: () => ref
                .read(visibilityAmountProvider.notifier)
                .setVisibility(!isVisible),
            onSettings: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ),
        body: AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          child: KeyedSubtree(
            key: ValueKey(_selected),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: _selectedPage,
              ),
            ),
          ),
        ),
        bottomNavigationBar: AppNavigationBar(
          selected: _selected,
          onSelect: (destination) {
            if (destination != _selected) {
              setState(() => _selected = destination);
            }
          },
          onAdd: () {
            ref.read(transactionsProvider.notifier).reset();
            Navigator.of(context).pushNamed('/add-page');
          },
        ),
      ),
    );
  }
}

const double _topBarHeight = 60;

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.title,
    required this.isVisible,
    required this.onSearch,
    required this.onVisibility,
    required this.onSettings,
  });

  /// Page title; the dashboard (null) shows the search capsule instead.
  final String? title;
  final bool isVisible;
  final VoidCallback onSearch;
  final VoidCallback onVisibility;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Sizes.responsiveInsets(context),
              Sizes.sm,
              Sizes.responsiveInsets(context),
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: duration,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, ?current],
                    ),
                    child: title == null
                        ? _searchCapsule(context)
                        : Padding(
                            key: ValueKey(title),
                            padding: const EdgeInsets.only(left: Sizes.sm),
                            child: Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: visual.textPrimary,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.9,
                                  ),
                            ),
                          ),
                  ),
                ),
                // Animate the search button in and out so the title slot
                // resizes smoothly instead of snapping by the button's width.
                AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerRight,
                  child: title == null
                      ? const SizedBox(height: 52)
                      : Padding(
                          padding: const EdgeInsets.only(left: Sizes.sm),
                          child: _DashboardAction(
                            label: 'Search transactions',
                            icon: Icons.search_rounded,
                            onTap: onSearch,
                          ),
                        ),
                ),
                const SizedBox(width: Sizes.sm),
                _DashboardAction(
                  label: isVisible ? 'Hide amounts' : 'Show amounts',
                  icon: isVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  onTap: onVisibility,
                ),
                const SizedBox(width: Sizes.sm),
                _DashboardAction(
                  label: 'Settings',
                  icon: Icons.tune_rounded,
                  onTap: onSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchCapsule(BuildContext context) {
    final visual = context.dashboardTheme;
    return TonalGlassSurface(
      key: const ValueKey('search-capsule'),
      onTap: onSearch,
      semanticLabel: 'Search transactions',
      tone: GlassTone.chrome,
      radius: 26,
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.lg,
        vertical: Sizes.md,
      ),
      boxShadow: const [],
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: visual.textPrimary, size: 25),
          const SizedBox(width: Sizes.md),
          Expanded(
            child: Text(
              'Search transactions',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: visual.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return SizedBox.square(
      dimension: 52,
      child: TonalGlassSurface(
        onTap: onTap,
        semanticLabel: label,
        tone: GlassTone.chrome,
        radius: 26,
        boxShadow: const [],
        child: Tooltip(
          message: label,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                icon,
                key: ValueKey(icon),
                color: visual.textPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
