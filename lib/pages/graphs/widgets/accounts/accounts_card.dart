import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../constants/constants.dart';
import '../../../../model/bank_account.dart';
import '../../../../providers/accounts_provider.dart';
import '../../../../providers/currency_provider.dart';
import '../../../../providers/main_converter_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/extensions.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/blur_widget.dart';
import '../../../../ui/widgets/default_container.dart';
import '../card_label.dart';

/// Each account's balance and its share of the net worth: one bar split by
/// account above a list where every account, however small, has a row.
class AccountsCard extends ConsumerWidget {
  const AccountsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountList = ref.watch(activeAccountsProvider);
    final converter = ref.watch(mainConverterProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CardLabel(label: "Accounts", subtitle: "Share of your net worth"),
        const SizedBox(height: Sizes.md),
        DefaultContainer(
          margin: EdgeInsets.zero,
          child: accountList.when(
            data: (accounts) {
              double inMain(BankAccount a) =>
                  converter?.balance(a) ?? (a.total ?? 0).toDouble();
              final sorted = [...accounts]
                ..sort((a, b) => inMain(b).compareTo(inMain(a)));
              final netWorth = sorted
                  .where((a) => a.countNetWorth)
                  .fold<double>(0, (sum, a) => sum + inMain(a));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ShareBar(
                    accounts: [
                      for (final a in sorted)
                        if (a.countNetWorth && inMain(a) > 0) a,
                    ],
                    value: inMain,
                  ),
                  const SizedBox(height: Sizes.md),
                  for (final (i, account) in sorted.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: Sizes.lg,
                        color: context.dashboardTheme.hairline,
                      ),
                    _AccountRow(
                      account: account,
                      inMain: inMain(account),
                      converted:
                          converter?.fx.hasRate(
                            account.currency,
                            DateTime.now(),
                          ) ??
                          false,
                      share: account.countNetWorth && netWorth != 0
                          ? inMain(account) / netWorth * 100
                          : null,
                    ),
                  ],
                ],
              );
            },
            loading: () => const SizedBox(height: 120),
            error: (e, s) => Text('Error: $e'),
          ),
        ),
      ],
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.accounts, required this.value});

  final List<BankAccount> accounts;
  final double Function(BankAccount) value;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final total = accounts.fold<double>(0, (sum, a) => sum + value(a));
    return BlurWidget(
      sigma: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          height: 14,
          child: Row(
            children: [
              if (accounts.isEmpty || total <= 0)
                Expanded(
                  child: ColoredBox(
                    color: visual.textPrimary.withValues(alpha: 0.06),
                  ),
                ),
              for (final (i, account) in accounts.indexed) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: (value(account) / total * 10000).round().clamp(
                    1,
                    10000,
                  ),
                  child: ColoredBox(
                    // An always-blurred account must not reveal its size by
                    // colour, so it gets a neutral segment.
                    color: account.alwaysBlurred
                        ? visual.textSecondary.withValues(alpha: 0.35)
                        : accountColorListTheme[account.color],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({
    required this.account,
    required this.inMain,
    required this.share,
    required this.converted,
  });

  final BankAccount account;
  final double inMain;
  final bool converted;

  /// Percent of the net worth, or null when the account is not counted.
  final double? share;

  static String _percent(double value) {
    if (value != 0 && value.abs() < 0.1) return value < 0 ? '>−0.1%' : '<0.1%';
    return '${value.toStringAsFixed(value.abs() < 10 ? 1 : 0)}%';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final main = ref.watch(currencyStateProvider);
    final code = account.currencyCode(main.code);
    final isForeign = code != main.code && converted;
    final share = this.share;
    final blurAlways = account.alwaysBlurred;

    final amountStyle = textTheme.titleSmall?.copyWith(
      color: visual.textPrimary,
      fontWeight: FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final secondaryStyle = textTheme.labelSmall?.copyWith(
      color: visual.textSecondary,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accountColorListTheme[account.color],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            accountIconList[account.symbol] ?? Icons.account_balance_wallet,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: Sizes.md),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (share == null)
                Text('Not in net worth', style: secondaryStyle)
              else
                BlurWidget(
                  always: blurAlways,
                  sigma: 6,
                  child: Text(
                    '${_percent(share)} of net worth',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondaryStyle,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: Sizes.sm),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BlurWidget(
                always: blurAlways,
                sigma: 10,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${(account.total ?? 0).toCurrency(code)} ${account.currencySymbol(main.symbol)}',
                    style: amountStyle,
                  ),
                ),
              ),
              if (isForeign)
                BlurWidget(
                  always: blurAlways,
                  sigma: 8,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '≈ ${inMain.toCurrency(main.code)} ${main.symbol}',
                      style: secondaryStyle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
