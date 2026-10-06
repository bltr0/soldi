import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/transactions_provider.dart';
import '../../ui/device.dart';
import '../../ui/snack_bars/transactions_snack_bars.dart';
import '../../ui/widgets/segmented_pill.dart';
import 'widgets/accounts_tab.dart';
import 'widgets/add_transaction_card.dart';
import 'widgets/categories_tab.dart';
import 'widgets/list_tab.dart';
import 'widgets/month_selector.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage>
    with TickerProviderStateMixin {
  static const List<Tab> myTabs = <Tab>[
    Tab(text: "List", height: 35),
    Tab(text: "Categories", height: 35),
    Tab(text: "Accounts", height: 35),
  ];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: myTabs.length);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      ref.invalidate(selectedListIndexProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      duplicatedTransactionProvider,
      (prev, curr) => showDuplicatedTransactionSnackBar(
        context,
        transaction: curr,
        ref: ref,
      ),
    );
    final transactionsExistsAsync = ref.watch(transactionsExistsProvider);

    return transactionsExistsAsync.when(
      data: (transactionsExists) {
        if (!transactionsExists) return const AddTransactionCard();
        final insets = Sizes.responsiveInsets(context);
        return SizedBox.expand(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  insets,
                  MediaQuery.paddingOf(context).top + Sizes.lg,
                  insets,
                  0,
                ),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) => SegmentedPill<int>(
                        options: {
                          for (var i = 0; i < myTabs.length; i++)
                            i: myTabs[i].text!,
                        },
                        selected: _tabController.index,
                        onChanged: _tabController.animateTo,
                      ),
                    ),
                    const SizedBox(height: Sizes.md),
                    const MonthSelector(type: MonthSelectorType.advanced),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [ListTab(), CategoriesTab(), AccountsTab()],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          "An error occurred: $error",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
