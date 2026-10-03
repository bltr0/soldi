import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ui/device.dart';
import '../../../../ui/extensions.dart';
import '../linear_progress_bar.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/blur_widget.dart';
import '../../../../ui/widgets/default_container.dart';
import '../../../../providers/accounts_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../model/bank_account.dart';
import '../card_label.dart';
import '../../../../ui/widgets/main_equivalent.dart';

class AccountsCard extends ConsumerWidget {
  const AccountsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountList = ref.watch(activeAccountsProvider);
    final currencyState = ref.watch(currencyStateProvider);
    final visual = context.dashboardTheme;

    return Column(
      children: [
        const CardLabel(label: "Accounts", subtitle: "Share of your balance"),
        const SizedBox(height: Sizes.md),
        DefaultContainer(
          margin: EdgeInsets.zero,
          child: accountList.when(
            data: (accounts) => ListView.separated(
              itemCount: accounts.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.vertical,
              separatorBuilder: (context, i) =>
                  const SizedBox(height: Sizes.xs),
              itemBuilder: (context, i) {
                double total = accounts.isNotEmpty
                    ? accounts
                          .map((account) => account.total!.toDouble())
                          .reduce(
                            (first, second) => first > second ? first : second,
                          )
                    : 0.0;
                BankAccount account = accounts[i];
                return SizedBox(
                  height: Sizes.xl * 2,
                  child: Column(
                    spacing: 4,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: visual.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          BlurWidget(
                            sigma: 12,
                            child: Text(
                              "${account.total?.toCurrency(account.currencyCode(currencyState.code))} ${account.currencySymbol(currencyState.symbol)}",
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: visual.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                              MainEquivalent(
                                amount: account.total ?? 0,
                                code: account.currencyCode(currencyState.code),
                                date: DateTime.now(),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: visual.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      LinearProgressBar(
                        type: BarType.account,
                        amount: account.total!.toDouble(),
                        total: total,
                        colorIndex: account.color,
                      ),
                    ],
                  ),
                );
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => Text('Error: $e'),
          ),
        ),
      ],
    );
  }
}
