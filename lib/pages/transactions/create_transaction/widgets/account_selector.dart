import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../constants/constants.dart';
import '../../../../model/bank_account.dart';
import '../../../../providers/accounts_provider.dart';
import '../../../../providers/transactions_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/widgets/picker_sheet.dart';

class AccountSelector extends ConsumerWidget {
  const AccountSelector({
    required this.scrollController,
    this.transfer = false,
    super.key,
  });

  final ScrollController? scrollController;
  final bool transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsList = ref.watch(activeAccountsProvider);
    final frequentAccounts = ref.watch(frequentAccountsProvider);
    final fromAccount = ref.watch(selectedBankAccountProvider);
    final toAccount = ref.watch(bankAccountTransferProvider);

    bool enabled(BankAccount account) => transfer
        ? account.id != fromAccount?.id
        : account.id != toAccount?.id;

    void pick(BankAccount account) {
      if (transfer) {
        ref.read(bankAccountTransferProvider.notifier).setAccount(account);
      } else {
        ref.read(selectedBankAccountProvider.notifier).setAccount(account);
      }
      Navigator.pop(context);
    }

    final selectedId = transfer ? toAccount?.id : fromAccount?.id;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: Sizes.xl),
      children: [
        PickerSheetHeader(
          title: transfer ? 'To account' : 'Account',
          onAdd: () {
            ref.invalidate(selectedAccountProvider);
            Navigator.of(context).pushNamed('/add-account');
          },
        ),
        ...frequentAccounts.maybeWhen(
          data: (accounts) => accounts.isEmpty
              ? const <Widget>[]
              : [
                  const PickerSectionLabel('Frequent'),
                  SizedBox(
                    height: 76,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sizes.sm,
                      ),
                      children: [
                        for (final account in accounts.take(6))
                          PickerChip(
                            label: account.name,
                            icon: accountIconList[account.symbol],
                            color: accountColorListTheme[account.color],
                            enabled: enabled(account),
                            onTap: () => pick(account),
                          ),
                      ],
                    ),
                  ),
                ],
          orElse: () => const <Widget>[],
        ),
        const PickerSectionLabel('All accounts'),
        ...accountsList.when(
          data: (accounts) => [
            for (final account in accounts)
              PickerRow(
                leading: PickerIcon(
                  icon: accountIconList[account.symbol],
                  color: accountColorListTheme[account.color],
                ),
                title: account.name,
                subtitle: account.currency,
                selected: account.id == selectedId,
                enabled: enabled(account),
                onTap: () => pick(account),
              ),
          ],
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(Sizes.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (err, _) => [Center(child: Text('Error: $err'))],
        ),
      ],
    );
  }
}

/// Opens [AccountSelector] for the paying account, or the receiving one of a
/// transfer.
Future<void> showAccountSelector(BuildContext context, {bool transfer = false}) =>
    showPickerSheet<void>(
      context,
      builder: (_, controller) =>
          AccountSelector(scrollController: controller, transfer: transfer),
    );
