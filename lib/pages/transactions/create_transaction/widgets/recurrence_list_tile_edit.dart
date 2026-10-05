import 'package:flutter/material.dart';
import "package:flutter_riverpod/flutter_riverpod.dart";

import '../../../../providers/transactions_provider.dart';
import '../../../../ui/device.dart';
import '../../../../ui/extensions.dart';
import '../../../../ui/widgets/settings_tiles.dart';
import 'recurrence_list_tile.dart';
import 'recurrence_selector.dart';

class RecurrenceListTileEdit extends ConsumerWidget {
  const RecurrenceListTileEdit({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endDate = ref.watch(endDateProvider);
    return SettingsTile(
      icon: Icons.autorenew_rounded,
      title: 'Repeat',
      below: Row(
        children: [
          Expanded(
            child: RecurrenceOptionButton(
              label: 'Every',
              value: ref.watch(intervalProvider).label,
              onTap: () => showRecurrenceSelector(context),
            ),
          ),
          const SizedBox(width: Sizes.sm),
          Expanded(
            child: RecurrenceOptionButton(
              label: 'Until',
              value: endDate?.formatEDMY() ?? 'Never',
              onTap: () => showEndDateSelector(context),
            ),
          ),
        ],
      ),
    );
  }
}
