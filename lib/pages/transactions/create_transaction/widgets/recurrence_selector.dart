import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../model/recurring_transaction.dart';
import '../../../../providers/transactions_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/widgets/picker_sheet.dart';

class RecurrenceSelector extends ConsumerWidget {
  const RecurrenceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(intervalProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Sizes.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PickerSheetHeader(title: 'Repeat every'),
          for (final recurrence in Recurrence.values)
            PickerRow(
              title: recurrence.label,
              selected: recurrence == selected,
              onTap: () {
                ref.read(intervalProvider.notifier).setValue(recurrence);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

Future<void> showRecurrenceSelector(BuildContext context) =>
    showPickerSheet<void>(
      context,
      scrollable: false,
      builder: (_, _) => const RecurrenceSelector(),
    );
