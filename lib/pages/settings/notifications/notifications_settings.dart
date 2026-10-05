import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_provider.dart';
import '../../../services/notifications/notifications_service.dart';
import '../../../ui/device.dart';
import '../../../ui/widgets/segmented_pill.dart';
import '../../../ui/widgets/settings_tiles.dart';

class NotificationsSettings extends ConsumerWidget {
  const NotificationsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationsProvider, (_, _) {});
    final isTrscReminderEnabled = ref.watch(transactionReminderSwitchProvider);
    final trscReminderCadence = ref.watch(transactionReminderCadenceProvider);
    final isTrscAddedReminderEnabled = ref.watch(
      transactionRecAddedSwitchProvider,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Notifications'),
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
            title: 'Reminders',
            children: [
              SettingsSwitchTile(
                icon: Icons.edit_notifications_rounded,
                title: 'Add transactions reminder',
                subtitle: 'A nudge to log what you spent',
                value: isTrscReminderEnabled,
                onChanged: (value) async {
                  await NotificationService().requestNotificationPermissions();
                  ref
                      .read(notificationsProvider.notifier)
                      .updateNotificationReminder(active: value);
                },
                below: isTrscReminderEnabled
                    ? SegmentedPill<NotificationReminderType>(
                        options: {
                          for (final type in NotificationReminderType.values)
                            if (type != NotificationReminderType.none)
                              type:
                                  '${type.name[0].toUpperCase()}${type.name.substring(1)}',
                        },
                        selected:
                            trscReminderCadence == NotificationReminderType.none
                            ? null
                            : trscReminderCadence,
                        onChanged: (type) => ref
                            .read(notificationsProvider.notifier)
                            .updateNotificationReminder(type: type),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: Sizes.xl),
          SettingsGroup(
            title: 'Recurring transactions',
            children: [
              SettingsSwitchTile(
                icon: Icons.event_repeat_rounded,
                title: 'Recurring transaction added',
                subtitle: 'Know when a recurring payment is recorded',
                value: isTrscAddedReminderEnabled,
                onChanged: (value) => ref
                    .read(notificationsProvider.notifier)
                    .updateNotificationRecurring(active: value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
