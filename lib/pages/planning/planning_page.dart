import 'package:flutter/material.dart';
import '../../ui/device.dart';
import '../../ui/widgets/section_header.dart';
import 'manage_budget_page.dart';
import 'widget/budget_card.dart';
import 'widget/recurring_payments_list.dart';

class PlanningPage extends StatelessWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = Sizes.responsiveInsets(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        insets,
        MediaQuery.paddingOf(context).top + Sizes.lg,
        insets,
        MediaQuery.paddingOf(context).bottom + Sizes.xl,
      ),
      children: [
        SectionHeader(
          title: "Monthly budget",
          subtitle: "Limits for this month",
          trailing: SectionAction(
            label: "Manage",
            icon: Icons.edit_rounded,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(Sizes.borderRadiusLarge),
                    topRight: Radius.circular(Sizes.borderRadiusLarge),
                  ),
                ),
                elevation: 10,
                builder: (BuildContext context) {
                  return const FractionallySizedBox(
                    heightFactor: 0.9,
                    child: ManageBudgetPage(),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: Sizes.md),
        const BudgetCard(),
        const SizedBox(height: Sizes.xl),
        const SectionHeader(
          title: "Recurring payments",
          subtitle: "Scheduled incomes and expenses",
        ),
        const SizedBox(height: Sizes.md),
        const RecurringPaymentSection(),
      ],
    );
  }
}
