import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../providers/authentication_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/fx_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/database/repositories/currency_repository.dart';
import '../../../services/security/app_lock.dart';
import '../../../ui/device.dart';
import '../../../ui/widgets/pin_pad.dart';
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
    final lockMode = ref.watch(appLockModeProvider);

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
                icon: isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
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
              SettingsTile(
                icon: lockMode == AppLockMode.none
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                title: 'App lock',
                subtitle: switch (lockMode) {
                  AppLockMode.none => 'Anyone holding your phone can open it',
                  AppLockMode.device =>
                    'Fingerprint, face or your phone\'s screen lock',
                  AppLockMode.pin => 'A PIN only used by Sossoldi',
                },
                below: SegmentedPill<AppLockMode>(
                  options: const {
                    AppLockMode.none: 'Off',
                    AppLockMode.device: 'Device',
                    AppLockMode.pin: 'PIN',
                  },
                  selected: lockMode,
                  onChanged: (mode) => _changeLock(context, ref, mode),
                ),
              ),
              if (lockMode == AppLockMode.pin)
                SettingsTile(
                  icon: Icons.pin_rounded,
                  title: 'Change PIN',
                  onTap: () => _changeLock(context, ref, AppLockMode.pin),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changeLock(
    BuildContext context,
    WidgetRef ref,
    AppLockMode mode,
  ) async {
    final notifier = ref.read(appLockModeProvider.notifier);
    switch (mode) {
      case AppLockMode.none:
        await notifier.set(mode);
      case AppLockMode.pin:
        final pin = await showPinSetup(context);
        if (pin != null) await notifier.setPin(pin);
      case AppLockMode.device:
        final auth = LocalAuthentication();
        var ok = false;
        try {
          ok =
              await auth.isDeviceSupported() &&
              await auth.authenticate(
                localizedReason: 'Confirm to lock Sossoldi with this device',
              );
        } catch (_) {}
        if (ok) {
          await notifier.set(mode);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device unlock is not available or was cancelled'),
            ),
          );
        }
    }
  }
}
