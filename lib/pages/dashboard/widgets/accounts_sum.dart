import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/constants.dart';
import '../../../model/bank_account.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';

class AccountsSum extends ConsumerWidget {
  const AccountsSum({required this.account, this.width, super.key});

  final BankAccount account;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyStateProvider);
    final visual = context.dashboardTheme;
    final accent =
        accountColorListTheme[account.color.clamp(
          0,
          accountColorListTheme.length - 1,
        )];

    return SizedBox(
      width: width,
      height: 72,
      child: TonalGlassSurface(
        onTap: () async {
          await ref
              .read(accountsProvider.notifier)
              .refreshAccount(account)
              .whenComplete(() {
                if (context.mounted) {
                  Navigator.of(context).pushNamed('/account');
                }
              });
        },
        semanticLabel: '${account.name} account',
        radius: 14,
        color: visual.raisedSurface,
        borderColor: accent.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(
          horizontal: Sizes.md,
          vertical: Sizes.sm,
        ),
        boxShadow: const [],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: visual.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            BlurWidget(
              sigma: 16,
              child: Text(
                '${(account.total ?? 0).toCurrency()}${currency.symbol}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
