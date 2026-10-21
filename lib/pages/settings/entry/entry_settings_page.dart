import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/entry_settings_provider.dart';
import '../../../ui/device.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/settings_tiles.dart';

/// How adding a transaction flows (what opens after the amount, the order
/// of the details, the calendar's first weekday) and how account rows look.
class EntrySettingsPage extends ConsumerWidget {
  const EntrySettingsPage({super.key});

  static IconData _icon(EntryField field) => switch (field) {
    EntryField.description => Icons.notes_rounded,
    EntryField.date => Icons.calendar_month_rounded,
    EntryField.account => Icons.account_balance_wallet_rounded,
    EntryField.category => Icons.category_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(entrySettingsProvider);
    final notifier = ref.read(entrySettingsProvider.notifier);
    final visual = context.dashboardTheme;

    final sequence = [
      'Amount keypad',
      if (settings.calendarAfterAmount) 'calendar',
      if (settings.descriptionAfterAmount) 'description keyboard',
    ].join(' → ');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Transaction entry'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Sizes.lg,
          Sizes.lg,
          Sizes.lg,
          MediaQuery.paddingOf(context).bottom + Sizes.xl,
        ),
        children: [
          SettingsGroup(
            title: 'After the amount',
            footer:
                'On a new transaction: $sequence. After that, nothing opens '
                'by itself; closing the calendar ends the sequence.',
            children: [
              SettingsSwitchTile(
                icon: Icons.calendar_month_rounded,
                title: 'Open the calendar',
                subtitle: 'To confirm or change the day',
                value: settings.calendarAfterAmount,
                onChanged: (value) => notifier.update(
                  settings.copyWith(calendarAfterAmount: value),
                ),
              ),
              SettingsSwitchTile(
                icon: Icons.keyboard_rounded,
                title: 'Then open the description keyboard',
                value: settings.descriptionAfterAmount,
                onChanged: (value) => notifier.update(
                  settings.copyWith(descriptionAfterAmount: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Details order',
            footer:
                'Drag to reorder. Rows that do not apply (category on a '
                'transfer, for example) are hidden.',
            children: [
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) {
                  final order = [...settings.order];
                  order.insert(to, order.removeAt(from));
                  notifier.update(settings.copyWith(order: order));
                },
                children: [
                  for (final (i, field) in settings.order.indexed)
                    ReorderableDragStartListener(
                      key: ValueKey(field),
                      index: i,
                      child: SettingsTile(
                        icon: _icon(field),
                        title: field.label,
                        trailing: Icon(
                          Icons.drag_handle_rounded,
                          color: visual.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              SettingsTile(
                icon: Icons.restart_alt_rounded,
                title: 'Default order',
                subtitle: 'Description, date, account, category',
                onTap: () => notifier.update(
                  settings.copyWith(order: EntrySettings.defaultOrder),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Account history',
            footer:
                'How rows look on an account page. Expenses keep the usual '
                'layout.',
            children: [
              SettingsSwitchTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Center transfers',
                subtitle: 'Shown apart from income and expenses',
                value: settings.centeredTransfers,
                onChanged: (value) => notifier.update(
                  settings.copyWith(centeredTransfers: value),
                ),
              ),
              SettingsSwitchTile(
                icon: Icons.flip_rounded,
                title: 'Mirror money coming in',
                subtitle: 'Aligned right, opposite to expenses',
                value: settings.mirroredInflows,
                onChanged: (value) =>
                    notifier.update(settings.copyWith(mirroredInflows: value)),
              ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Calendar',
            children: [
              for (final start in WeekStart.values)
                SettingsTile(
                  icon: start == settings.weekStart
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  title: 'Weeks start on ${start.label}',
                  onTap: () =>
                      notifier.update(settings.copyWith(weekStart: start)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
