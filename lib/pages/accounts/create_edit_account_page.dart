import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/constants.dart';
import '../../model/currency_catalog.dart';
import '../../providers/accounts_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/fx_provider.dart';
import '../../ui/device.dart';
import '../../ui/extensions.dart';
import '../../ui/formatters/decimal_text_input_formatter.dart';
import '../../ui/theme/dashboard_visual_theme.dart';
import '../../ui/widgets/accent_button.dart';
import '../../ui/widgets/currency_picker_sheet.dart';
import '../../ui/widgets/fx_source_dialog.dart';
import '../../ui/widgets/settings_tiles.dart';
import '../../ui/widgets/tonal_glass_surface.dart';
import 'widgets/confirm_account_deletion_dialog.dart';

class CreateEditAccountPage extends ConsumerStatefulWidget {
  const CreateEditAccountPage({super.key});

  @override
  ConsumerState<CreateEditAccountPage> createState() =>
      _CreateEditAccountPage();
}

class _CreateEditAccountPage extends ConsumerState<CreateEditAccountPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();
  String accountIcon = accountIconList.keys.first;
  int accountColor = 0;
  bool countNetWorth = true;
  bool mainAccount = false;
  bool alwaysBlurred = false;

  /// ISO code of the account's own currency; null uses the app currency.
  String? accountCurrency;

  @override
  void initState() {
    final selectedAccount = ref.read(selectedAccountProvider);
    if (selectedAccount != null) {
      nameController.text = selectedAccount.name;
      balanceController.text =
          selectedAccount.total?.toCurrency(
            selectedAccount.currencyCode(ref.read(currencyStateProvider).code),
          ) ??
          "";
      accountIcon = selectedAccount.symbol;
      accountColor = selectedAccount.color;
      countNetWorth = selectedAccount.countNetWorth;
      mainAccount = selectedAccount.mainAccount;
      alwaysBlurred = selectedAccount.alwaysBlurred;
      accountCurrency = selectedAccount.currency;
    }
    super.initState();
  }

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final selectedAccount = ref.read(selectedAccountProvider);
    final currencyState = ref.read(currencyStateProvider);
    if (selectedAccount != null) {
      await ref
          .read(accountsProvider.notifier)
          .updateAccount(
            name: nameController.text,
            icon: accountIcon,
            color: accountColor,
            balance: balanceController.text.toNum(),
            countNetWorth: countNetWorth,
            mainAccount: mainAccount,
            updateCurrency: true,
            currency: accountCurrency,
            alwaysBlurred: alwaysBlurred,
          );
    } else {
      await ref
          .read(accountsProvider.notifier)
          .addAccount(
            name: nameController.text,
            icon: accountIcon,
            color: accountColor,
            countNetWorth: countNetWorth,
            mainAccount: mainAccount,
            startingValue: balanceController.text.toNum(),
            currency: accountCurrency,
            alwaysBlurred: alwaysBlurred,
          );
    }
    if (accountCurrency != null && accountCurrency != currencyState.code) {
      unawaited(ref.read(fxSyncProvider.notifier).sync(force: true));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickCurrency() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final currencyState = ref.read(currencyStateProvider);
    final choice = await showCurrencyPicker(
      context,
      selected: accountCurrency,
      mainLabel:
          "${currencyState.name} (${currencyState.code} ${currencyState.symbol})",
    );
    if (choice == null || !mounted) return;
    setState(() => accountCurrency = choice.code);
    if (choice.code != null && choice.code != currencyState.code) {
      await askFxSourceIfUnset(context, ref);
    }
  }

  void _confirmDelete() {
    final selectedAccount = ref.read(selectedAccountProvider)!;
    showDialog(
      context: context,
      builder: (context) => ConfirmAccountDeletionDialog(
        account: selectedAccount,
        onPressed: () => ref
            .read(accountsProvider.notifier)
            .removeAccount(selectedAccount)
            .whenComplete(() {
              if (context.mounted) {
                Navigator.popUntil(
                  context,
                  ModalRoute.withName('/account-list'),
                );
              }
            }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAccount = ref.watch(selectedAccountProvider);
    final currencyState = ref.watch(currencyStateProvider);
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final accountCurrencyInfo = CurrencyCatalog.byCode(accountCurrency);
    final balanceSymbol = accountCurrency == null
        ? currencyState.symbol
        : CurrencyCatalog.symbolFor(accountCurrency!);
    final accent =
        accountColorListTheme[accountColor.clamp(
          0,
          accountColorListTheme.length - 1,
        )];
    final isNew = selectedAccount == null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isNew ? 'New account' : 'Edit account'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Sizes.lg,
            Sizes.sm,
            Sizes.lg,
            Sizes.md,
          ),
          child: AccentButton(
            label: isNew ? 'Create account' : 'Save changes',
            icon: isNew ? Icons.add_rounded : Icons.check_rounded,
            onPressed: _save,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Sizes.lg,
          Sizes.lg,
          Sizes.lg,
          Sizes.xl,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          TonalGlassSurface(
            tone: GlassTone.hero,
            radius: 28,
            pressScale: 1,
            padding: const EdgeInsets.all(Sizes.lg),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    accountIconList[accountIcon],
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: Sizes.md),
                Expanded(
                  child: TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    style: textTheme.titleLarge?.copyWith(
                      color: visual.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Account name',
                      hintStyle: TextStyle(color: visual.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Look',
            children: [
              Padding(
                padding: const EdgeInsets.all(Sizes.md),
                child: Wrap(
                  spacing: Sizes.sm,
                  runSpacing: Sizes.sm,
                  children: [
                    for (final entry in accountIconList.entries)
                      _Choice(
                        selected: entry.key == accountIcon,
                        color: accent,
                        onTap: () => setState(() => accountIcon = entry.key),
                        child: Icon(
                          entry.value,
                          size: 20,
                          color: entry.key == accountIcon
                              ? Colors.white
                              : visual.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Sizes.md),
                child: Wrap(
                  spacing: Sizes.sm,
                  runSpacing: Sizes.sm,
                  children: [
                    for (final (index, color) in accountColorListTheme.indexed)
                      _Choice(
                        selected: index == accountColor,
                        color: color,
                        fill: color,
                        onTap: () => setState(() => accountColor = index),
                        child: index == accountColor
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Money',
            footer: isNew
                ? null
                : 'Changing the balance records an adjustment for today.',
            children: [
              SettingsTile(
                icon: Icons.account_balance_wallet_rounded,
                title: isNew ? 'Initial balance' : 'Current balance',
                trailing: SizedBox(
                  width: 150,
                  child: TextField(
                    controller: balanceController,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      DecimalTextInputFormatter(
                        decimalDigits: CurrencyCatalog.decimalsFor(
                          accountCurrency ?? currencyState.code,
                        ),
                      ),
                    ],
                    style: textTheme.titleMedium?.copyWith(
                      color: visual.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '0',
                      hintStyle: TextStyle(color: visual.textSecondary),
                      suffixText: ' $balanceSymbol',
                      suffixStyle: TextStyle(color: visual.textSecondary),
                    ),
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.payments_rounded,
                title: 'Currency',
                subtitle: accountCurrency == null
                    ? 'Main currency'
                    : accountCurrencyInfo?.name ?? accountCurrency,
                trailing: SettingsValue(
                  accountCurrency == null
                      ? '${currencyState.code} ${currencyState.symbol}'
                      : '$accountCurrency $balanceSymbol',
                ),
                onTap: _pickCurrency,
              ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Options',
            children: [
              SettingsSwitchTile(
                icon: Icons.star_rounded,
                title: 'Main account',
                subtitle: 'Picked by default for new transactions',
                value: mainAccount,
                onChanged: (value) => setState(() => mainAccount = value),
              ),
              SettingsSwitchTile(
                icon: Icons.donut_large_rounded,
                title: 'Counts for net worth',
                value: countNetWorth,
                onChanged: (value) => setState(() => countNetWorth = value),
              ),
              SettingsSwitchTile(
                icon: Icons.visibility_off_rounded,
                title: 'Always blurred',
                subtitle:
                    'Hide this balance everywhere except here, even when '
                    'amounts are shown',
                value: alwaysBlurred,
                onChanged: (value) => setState(() => alwaysBlurred = value),
              ),
            ],
          ),
          if (!isNew) ...[
            const SizedBox(height: Sizes.xl),
            Center(
              child: TextButton.icon(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: visual.negative,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sizes.lg,
                    vertical: Sizes.md,
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete account'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.child,
    this.fill,
  });

  final bool selected;
  final Color color;
  final Color? fill;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                fill ??
                (selected ? color : visual.textPrimary.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected && fill != null
                  ? visual.textPrimary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
