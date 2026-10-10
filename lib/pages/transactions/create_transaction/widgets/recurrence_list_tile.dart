import 'package:flutter/material.dart';
import "package:flutter_riverpod/flutter_riverpod.dart";

import '../../../../model/transaction.dart';
import '../../../../providers/transactions_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/extensions.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';
import '../../../../ui/widgets/picker_sheet.dart';
import '../../../../ui/widgets/settings_tiles.dart';
import 'recurrence_selector.dart';
import '../../../../ui/widgets/date_picker_sheet.dart';

class RecurrenceListTile extends ConsumerWidget {
  const RecurrenceListTile({
    super.key,
    required this.recurrencyEditingPermitted,
    required this.selectedTransaction,
  });

  final bool recurrencyEditingPermitted;
  final Transaction? selectedTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final isRecurring = ref.watch(selectedRecurringPayProvider);
    final interval = ref.watch(intervalProvider);
    final endDate = ref.watch(endDateProvider);
    final editable = selectedTransaction == null || recurrencyEditingPermitted;
    final generated =
        selectedTransaction != null && !recurrencyEditingPermitted;

    return SettingsTile(
      icon: Icons.autorenew_rounded,
      title: 'Repeat',
      subtitle: generated
          ? 'Created by a recurring payment'
          : isRecurring
          ? 'Adds this transaction automatically'
          : 'One-time transaction',
      onTap: recurrencyEditingPermitted
          ? () => ref
                .read(selectedRecurringPayProvider.notifier)
                .setValue(!isRecurring)
          : null,
      trailing: Switch.adaptive(
        value: isRecurring,
        activeTrackColor: visual.accent,
        onChanged: recurrencyEditingPermitted
            ? (value) => ref
                  .read(selectedRecurringPayProvider.notifier)
                  .setValue(value)
            : null,
      ),
      below: isRecurring
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RecurrenceOptionButton(
                        label: 'Every',
                        value: interval.label,
                        onTap: editable
                            ? () => showRecurrenceSelector(context)
                            : null,
                      ),
                    ),
                    const SizedBox(width: Sizes.sm),
                    Expanded(
                      child: RecurrenceOptionButton(
                        label: 'Until',
                        value: endDate?.formatEDMY() ?? 'Never',
                        onTap: editable
                            ? () => showEndDateSelector(context)
                            : null,
                      ),
                    ),
                  ],
                ),
                if (generated) ...[
                  const SizedBox(height: Sizes.sm),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: visual.accent,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed(
                            "/edit-recurring-transaction",
                            arguments: selectedTransaction,
                          )
                          .then((_) {
                            if (context.mounted) Navigator.of(context).pop();
                          });
                    },
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: const Text('Edit the recurring payment'),
                  ),
                ],
              ],
            )
          : null,
    );
  }
}

class RecurrenceOptionButton extends StatelessWidget {
  const RecurrenceOptionButton({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: visual.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sizes.md,
              vertical: Sizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.labelSmall?.copyWith(
                          color: visual.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: visual.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: visual.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EndDateSelector extends ConsumerWidget {
  const EndDateSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endDate = ref.watch(endDateProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sizes.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PickerSheetHeader(title: 'Stop repeating'),
          PickerRow(
            title: 'Never',
            selected: endDate == null,
            onTap: () {
              ref.read(endDateProvider.notifier).setDate(null);
              Navigator.pop(context);
            },
          ),
          PickerRow(
            title: 'On a date',
            subtitle: endDate?.formatEDMY(),
            selected: endDate != null,
            onTap: () async {
              final picked = await showAppDatePicker(
                context,
                initialDate: endDate ?? DateTime.now(),
                firstDate: DateTime(2015),
                lastDate: DateTime(2050),
              );
              if (picked == null) return;
              ref.read(endDateProvider.notifier).setDate(picked);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

Future<void> showEndDateSelector(BuildContext context) => showPickerSheet<void>(
  context,
  scrollable: false,
  builder: (_, _) => const EndDateSelector(),
);
