import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/categories_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/transactions_provider.dart';
import '../../ui/device.dart';
import '../../ui/snack_bars/transactions_snack_bars.dart';
import 'widgets/account_section.dart';
import 'widgets/dashboard_balance_hero.dart';
import 'widgets/due_section.dart';
import 'widgets/organize_section.dart';
import 'widgets/places_section.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(categoriesProvider);
    final snapshot = ref.watch(dashboardProvider);

    ref.listen(
      duplicatedTransactionProvider,
      (prev, curr) => showDuplicatedTransactionSnackBar(
        context,
        transaction: curr,
        ref: ref,
      ),
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            Sizes.responsiveInsets(context),
            MediaQuery.paddingOf(context).top + Sizes.lg,
            Sizes.responsiveInsets(context),
            MediaQuery.paddingOf(context).bottom + Sizes.xl,
          ),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardBalanceHero(snapshot: snapshot),
                    const SizedBox(height: Sizes.lg),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 900) {
                          return const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: AccountSection()),
                              SizedBox(width: Sizes.lg),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    DueSection(
                                      margin: EdgeInsets.only(bottom: Sizes.lg),
                                    ),
                                    OrganizeSection(),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }
                        return const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AccountSection(),
                            DueSection(),
                            SizedBox(height: Sizes.lg),
                            OrganizeSection(),
                          ],
                        );
                      },
                    ),
<<<<<<< Updated upstream
<<<<<<< Updated upstream
=======
                    const SizedBox(height: Sizes.lg),
>>>>>>> Stashed changes
=======
                    const SizedBox(height: Sizes.lg),
>>>>>>> Stashed changes
                    const PlacesSection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
