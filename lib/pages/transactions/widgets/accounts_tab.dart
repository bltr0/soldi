import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../constants/constants.dart';
import '../../../ui/widgets/default_container.dart';
import '../../../ui/widgets/transaction_type_button.dart';
import '../../../model/bank_account.dart';
import '../../../model/transaction.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/main_converter_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../ui/device.dart';
import 'accounts_pie_chart.dart';
import 'panel_list_tile.dart';

class AccountsTab extends ConsumerWidget {
  const AccountsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final transactions = ref.watch(transactionsProvider);
    final transactionType = ref.watch(selectedTransactionTypeProvider);
    final converter = ref.watch(mainConverterProvider).value;

    // Each account with its transactions and its total, in the main
    // currency at each transaction's own rate so accounts can be compared.
    Map<int, List<Transaction>> accountToTransactionsIncome = {},
        accountToTransactionsExpense = {};
    Map<int, double> accountToAmountIncome = {}, accountToAmountExpense = {};
    double totalIncome = 0, totalExpense = 0;
    var unconvertedIncome = false, unconvertedExpense = false;

    for (Transaction transaction in transactions.value ?? []) {
      final accountId = transaction.idBankAccount;
      if (transaction.isBalanceReset) {
        (accountToTransactionsIncome[accountId] ??= []).add(transaction);
        (accountToTransactionsExpense[accountId] ??= []).add(transaction);
        accountToAmountIncome.putIfAbsent(accountId, () => 0);
        accountToAmountExpense.putIfAbsent(accountId, () => 0);
        continue;
      }
      final amount =
          converter?.transaction(transaction) ?? transaction.amount.toDouble();
      if (transaction.type == TransactionType.income) {
        (accountToTransactionsIncome[accountId] ??= []).add(transaction);
        totalIncome += amount;
        unconvertedIncome |= converter?.unconverted(transaction) ?? false;
        accountToAmountIncome[accountId] =
            (accountToAmountIncome[accountId] ?? 0) + amount;
      } else if (transaction.type == TransactionType.expense) {
        (accountToTransactionsExpense[accountId] ??= []).add(transaction);
        totalExpense -= amount;
        unconvertedExpense |= converter?.unconverted(transaction) ?? false;
        accountToAmountExpense[accountId] =
            (accountToAmountExpense[accountId] ?? 0) - amount;
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: Sizes.lg,
        bottom: MediaQuery.paddingOf(context).bottom + Sizes.xl,
      ),
      child: DefaultContainer(
        margin: EdgeInsets.symmetric(
          horizontal: Sizes.responsiveInsets(context),
        ),
        child: Column(
          spacing: Sizes.lg,
          children: [
            const TransactionTypeButton(),
            accounts.when(
              data: (data) {
                List<BankAccount> accountIncomeList = data
                    .where(
                      (account) =>
                          accountToAmountIncome.containsKey(account.id),
                    )
                    .toList();
                List<BankAccount> accountExpenseList = data
                    .where(
                      (account) =>
                          accountToAmountExpense.containsKey(account.id),
                    )
                    .toList();
                return transactionType == TransactionType.income
                    ? accountIncomeList.isEmpty
                          ? const SizedBox(
                              height: 400,
                              child: Center(
                                child: Text("No incomes for selected month"),
                              ),
                            )
                          : AccountSection(
                              accountList: accountIncomeList,
                              amounts: accountToAmountIncome,
                              total: totalIncome,
                              unconverted: unconvertedIncome,
                              transactions: accountToTransactionsIncome,
                            )
                    : accountExpenseList.isEmpty
                    ? const SizedBox(
                        height: 400,
                        child: Center(
                          child: Text("No expenses for selected month"),
                        ),
                      )
                    : AccountSection(
                        accountList: accountExpenseList,
                        amounts: accountToAmountExpense,
                        total: totalExpense,
                        unconverted: unconvertedExpense,
                        transactions: accountToTransactionsExpense,
                      );
              },
              error: (error, stackTrace) =>
                  Center(child: Text(error.toString())),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountSection extends StatelessWidget {
  const AccountSection({
    required this.accountList,
    required this.amounts,
    required this.total,
    required this.transactions,
    this.unconverted = false,
    super.key,
  });

  final bool unconverted;
  final List<BankAccount> accountList;
  final Map<int, double> amounts;
  final double total;
  final Map<int, List<Transaction>> transactions;

  @override
  Widget build(BuildContext context) {
    // Accounts with an amount first, so a pie slice and its tile share the
    // same index when one is tapped.
    final accountList = [
      ...this.accountList.where((a) => (amounts[a.id] ?? 0) != 0),
      ...this.accountList.where((a) => (amounts[a.id] ?? 0) == 0),
    ];
    final pieAccounts = [
      for (final account in accountList)
        if ((amounts[account.id] ?? 0) != 0) account,
    ];
    return Column(
      spacing: Sizes.lg,
      children: [
        if (pieAccounts.isNotEmpty)
          AccountsPieChart(
            accounts: pieAccounts,
            amounts: amounts,
            total: total,
            unconverted: unconverted,
          ),
        ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: accountList.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: Sizes.sm),
          itemBuilder: (context, index) {
            BankAccount account = accountList[index];
            return PanelListTile(
              name: account.name,
              color: accountColorList[account.color],
              icon: accountIconList[account.symbol],
              transactions: transactions[account.id] ?? [],
              amount: amounts[account.id] ?? 0,
              percent: total == 0
                  ? 0
                  : (amounts[account.id] ?? 0) / total * 100,
              index: index,
            );
          },
        ),
      ],
    );
  }
}
