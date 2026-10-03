import 'package:flutter/material.dart';
import "package:flutter_riverpod/flutter_riverpod.dart";

import '../../../../constants/constants.dart';
import '../../../../ui/widgets/rounded_icon.dart';
import '../../../../model/transaction.dart';
import '../../../../providers/transactions_provider.dart';
import 'amount_widget.dart';
import '../../../../ui/device.dart';
import 'account_selector.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/segmented_pill.dart';

class AmountSection extends ConsumerStatefulWidget {
  const AmountSection(this.amountController, {super.key});

  final TextEditingController amountController;

  @override
  ConsumerState<AmountSection> createState() => _AmountSectionState();
}

class _AmountSectionState extends ConsumerState<AmountSection> {
  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(selectedTransactionTypeProvider);

    final visual = context.dashboardTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sizes.md),
      child: Column(
        children: [
          const SizedBox(height: Sizes.md),
          if (selectedType == TransactionType.adjustment)
            Container(
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visual.textPrimary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Balance adjustment",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            SegmentedPill<TransactionType>(
              height: 40,
              selected: selectedType,
              options: const {
                TransactionType.income: 'Income',
                TransactionType.expense: 'Expense',
                TransactionType.transfer: 'Transfer',
              },
              onChanged: (type) {
                ref
                    .read(selectedTransactionTypeProvider.notifier)
                    .setType(type);
                ref.invalidate(bankAccountTransferProvider);
              },
            ),
          if (selectedType == TransactionType.transfer)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sizes.lg,
                Sizes.sm,
                Sizes.lg,
                0,
              ),
              child: SizedBox(
                height: Sizes.xxl * 2,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: Sizes.sm),
                          Text(
                            "FROM:",
                            style: Theme.of(context).textTheme.labelMedium!
                                .copyWith(
                                  color: visual.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                          ),
                          const SizedBox(height: Sizes.xxs * 0.5),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                showModalBottomSheet(
                                  context: context,
                                  clipBehavior: Clip.antiAliasWithSaveLayer,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(
                                        Sizes.borderRadius,
                                      ),
                                      topRight: Radius.circular(
                                        Sizes.borderRadius,
                                      ),
                                    ),
                                  ),
                                  builder: (_) => DraggableScrollableSheet(
                                    expand: false,
                                    minChildSize: 0.5,
                                    initialChildSize: 0.7,
                                    maxChildSize: 0.9,
                                    builder: (_, controller) => AccountSelector(
                                      // from
                                      scrollController: controller,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: visual.raisedSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: visual.glassBorder),
                                ),
                                padding: const EdgeInsets.all(Sizes.xxs),
                                child: Row(
                                  children: [
                                    RoundedIcon(
                                      icon:
                                          ref
                                                  .watch(
                                                    selectedBankAccountProvider,
                                                  )
                                                  ?.symbol !=
                                              null
                                          ? accountIconList[ref
                                                .watch(
                                                  selectedBankAccountProvider,
                                                )!
                                                .symbol]
                                          : null,
                                      backgroundColor:
                                          ref
                                                  .watch(
                                                    selectedBankAccountProvider,
                                                  )
                                                  ?.color !=
                                              null
                                          ? accountColorListTheme[ref
                                                .watch(
                                                  selectedBankAccountProvider,
                                                )!
                                                .color]
                                          : null,
                                      size: 16,
                                      padding: const EdgeInsets.all(Sizes.xs),
                                    ),
                                    const Spacer(),
                                    Text(
                                      ref
                                              .watch(
                                                selectedBankAccountProvider,
                                              )
                                              ?.name ??
                                          "Select Account",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            color: visual.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => ref
                          .read(transactionsProvider.notifier)
                          .switchAccount(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: VerticalDivider(
                              width: 1,
                              color: visual.hairline,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: Sizes.xxs * 0.5,
                              horizontal: Sizes.xl,
                            ),
                            child: Icon(
                              Icons.change_circle,
                              size: 32,
                              color: visual.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: VerticalDivider(
                              width: 1,
                              color: visual.hairline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: Sizes.sm),
                          Text(
                            "TO:",
                            style: Theme.of(context).textTheme.labelMedium!
                                .copyWith(
                                  color: visual.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                          ),
                          const SizedBox(height: Sizes.xxs * 0.5),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                showModalBottomSheet(
                                  context: context,
                                  clipBehavior: Clip.antiAliasWithSaveLayer,
                                  isScrollControlled: true,
                                  useSafeArea: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(
                                        Sizes.borderRadius,
                                      ),
                                      topRight: Radius.circular(
                                        Sizes.borderRadius,
                                      ),
                                    ),
                                  ),
                                  builder: (_) => DraggableScrollableSheet(
                                    expand: false,
                                    minChildSize: 0.5,
                                    initialChildSize: 0.7,
                                    maxChildSize: 0.9,
                                    builder: (_, controller) => AccountSelector(
                                      // to
                                      scrollController: controller,
                                      transfer: true,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: visual.raisedSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: visual.glassBorder),
                                ),
                                padding: const EdgeInsets.all(Sizes.xs),
                                child: Row(
                                  children: [
                                    RoundedIcon(
                                      icon:
                                          accountIconList[ref
                                              .watch(
                                                bankAccountTransferProvider,
                                              )
                                              ?.symbol],
                                      backgroundColor:
                                          ref.watch(
                                                bankAccountTransferProvider,
                                              ) !=
                                              null
                                          ? accountColorListTheme[ref
                                                .watch(
                                                  bankAccountTransferProvider,
                                                )!
                                                .color]
                                          : null,
                                      size: 16,
                                      padding: const EdgeInsets.all(Sizes.xs),
                                    ),
                                    const Spacer(),
                                    Text(
                                      ref
                                              .watch(
                                                bankAccountTransferProvider,
                                              )
                                              ?.name ??
                                          "Select account",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            color: visual.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          AmountWidget(widget.amountController),
        ],
      ),
    );
  }
}
