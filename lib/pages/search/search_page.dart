import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme/dashboard_visual_theme.dart';
import '../../ui/widgets/picker_sheet.dart';
import '../../ui/widgets/settings_tiles.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../services/database/repositories/transactions_repository.dart';
import '../../ui/extensions.dart';
import '../../ui/widgets/transactions_list.dart';
import '../../model/transaction.dart';
import '../../ui/device.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPage();
}

class _SearchPage extends ConsumerState<SearchPage> {
  late List<String> suggetions = [""];
  String? labelFilter;

  @override
  void initState() {
    super.initState();
    ref
        .read(transactionsRepositoryProvider)
        .getAllLabels()
        .then((List<String> value) => suggetions.addAll(value));
  }

  @override
  Widget build(BuildContext context) {
    final filterType = ref.watch(typeFilterProvider);
    final accountList = ref.watch(accountsProvider);
    final filterAccountList = ref.watch(filterAccountProvider);
    final searchTransactions = ref.watch(searchTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Search"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(Sizes.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.dashboardTheme.textPrimary.withValues(
                  alpha: 0.06,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: Sizes.sm),
                  hintText: "Search",
                ),
                child: Autocomplete(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return suggetions.where((String option) {
                      return option.contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (option) {
                    setState(() => labelFilter = option);
                    ref.read(filterLabelProvider.notifier).setLabel(option);
                  },
                ),
              ),
            ),
            const SizedBox(height: Sizes.md),
            const PickerSectionLabel("Type"),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: TransactionType.values.map((type) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sizes.sm),
                    child: TogglePill(
                      label: type.name.capitalize(),
                      selected: filterType[type.code] ?? false,
                      onTap: () {
                        ref.read(typeFilterProvider.notifier).setFilter({
                          ...filterType,
                          type.code: filterType[type.code] != null
                              ? !filterType[type.code]!
                              : false,
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: Sizes.md),
            const PickerSectionLabel("Accounts"),
            SizedBox(
              height: 60,
              child: accountList.when(
                data: (accounts) {
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    children: accounts.map((account) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Sizes.sm,
                        ),
                        child: TogglePill(
                          label: account.name,
                          selected: filterAccountList[account.id] ?? false,
                          onTap: () {
                            ref
                                .read(filterAccountProvider.notifier)
                                .setAccounts({
                                  ...ref.read(filterAccountProvider),
                                  account.id!:
                                      ref.read(
                                            filterAccountProvider,
                                          )[account.id] !=
                                          null
                                      ? !ref.read(
                                          filterAccountProvider,
                                        )[account.id]!
                                      : false,
                                });
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox(),
                error: (err, stack) => Text('Error: $err'),
              ),
            ),
            Expanded(
              child: searchTransactions.when(
                data: (data) {
                  if (data.isNotEmpty) {
                    return SingleChildScrollView(
                      child: TransactionsList(
                        margin: EdgeInsets.zero,
                        transactions: data,
                      ),
                    );
                  } else {
                    return const Center(
                      child: Text("Search for a transaction"),
                    );
                  }
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
