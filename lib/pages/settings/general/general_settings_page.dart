import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/authentication_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/fx_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database/repositories/currency_repository.dart';
import '../../../ui/device.dart';
import '../../../ui/widgets/segmented_pill.dart';
import '../../../ui/widgets/settings_tiles.dart';
import 'widgets/currency_selector_dialog.dart';

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appThemeStateProvider).isDarkModeEnabled;
    final currency = ref.watch(currencyStateProvider);
    final fxSource = ref.watch(fxSourceSettingProvider);
    final requiresAuthentication = ref.watch(authenticationStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('General Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Sizes.lg,
          Sizes.lg,
          Sizes.lg,
          MediaQuery.paddingOf(context).bottom + Sizes.xl,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          SettingsGroup(
            title: 'Appearance',
            children: [
              SettingsTile(
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                title: 'Theme',
                below: SegmentedPill<bool>(
                  options: const {false: 'Light', true: 'Dark'},
                  selected: isDark,
                  onChanged: (dark) {
                    if (dark != isDark) {
                      ref.read(appThemeStateProvider.notifier).updateTheme();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Money',
            footer: switch (fxSource) {
              FxSource.unset =>
                'Not chosen yet: amounts in other currencies are not '
                    'converted.',
              FxSource.offline =>
                'Nothing is sent. Only rates from your own cross-currency '
                    'transfers are used.',
              FxSource.frankfurter =>
                'Daily rates from Frankfurter, fetched once a day when the '
                    'app opens. Only currency codes and dates are sent.',
            },
            children: [
              SettingsTile(
                icon: Icons.payments_rounded,
                title: 'Main currency',
                subtitle: currency.name,
                trailing: SettingsValue('${currency.code} ${currency.symbol}'),
                onTap: () => CurrencySelectorDialog.selectCurrencyDialog(
                  context,
                  currency,
                  ref.read(currencyRepositoryProvider).selectAll(),
                ),
              ),
              SettingsTile(
                icon: Icons.currency_exchange_rounded,
                title: 'Exchange rates',
                subtitle: 'Show other currencies in ${currency.code}',
                below: SegmentedPill<FxSource>(
                  options: const {
                    FxSource.offline: 'Offline',
                    FxSource.frankfurter: 'Online',
                  },
                  selected: fxSource == FxSource.unset ? null : fxSource,
                  onChanged: (source) =>
                      ref.read(fxSourceSettingProvider.notifier).set(source),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Security',
            children: [
              SettingsSwitchTile(
                icon: requiresAuthentication
                    ? Icons.lock_rounded
                    : Icons.lock_open_rounded,
                title: 'Require authentication',
                subtitle: 'Unlock the app with your device credentials',
                value: requiresAuthentication,
                onChanged: (_) => ref
                    .read(authenticationStateProvider.notifier)
                    .updateAuthentication(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
