import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Rows of the details card on the new/edit transaction page.
enum EntryField {
  description('Description'),
  date('Date'),
  account('Account'),
  category('Category');

  const EntryField(this.label);

  final String label;
}

/// Day the calendar's weeks start on, as `DateTime.weekday % 7`
/// (0 = Sunday), or the phone's language default.
enum WeekStart {
  monday('Monday', 1),
  sunday('Sunday', 0),
  saturday('Saturday', 6),
  system('Phone language', null);

  const WeekStart(this.label, this.dayIndex);

  final String label;
  final int? dayIndex;
}

/// How the new transaction page walks the user through it.
class EntrySettings {
  const EntrySettings({
    this.calendarAfterAmount = true,
    this.descriptionAfterAmount = true,
    this.order = defaultOrder,
    this.weekStart = WeekStart.monday,
    this.centeredTransfers = true,
    this.mirroredInflows = true,
  });

  static const defaultOrder = [
    EntryField.description,
    EntryField.date,
    EntryField.account,
    EntryField.category,
  ];

  /// Opens the calendar once the amount is confirmed.
  final bool calendarAfterAmount;

  /// Then opens the description keyboard (after the calendar when both).
  final bool descriptionAfterAmount;

  final List<EntryField> order;
  final WeekStart weekStart;

  /// Account ledgers draw transfers centered, apart from income and expenses.
  final bool centeredTransfers;

  /// Account ledgers align money coming in to the right, so it
  /// reads opposite to expenses.
  final bool mirroredInflows;

  EntrySettings copyWith({
    bool? calendarAfterAmount,
    bool? descriptionAfterAmount,
    List<EntryField>? order,
    WeekStart? weekStart,
    bool? centeredTransfers,
    bool? mirroredInflows,
  }) => EntrySettings(
    calendarAfterAmount: calendarAfterAmount ?? this.calendarAfterAmount,
    descriptionAfterAmount:
        descriptionAfterAmount ?? this.descriptionAfterAmount,
    order: order ?? this.order,
    weekStart: weekStart ?? this.weekStart,
    centeredTransfers: centeredTransfers ?? this.centeredTransfers,
    mirroredInflows: mirroredInflows ?? this.mirroredInflows,
  );
}

class EntrySettingsNotifier extends Notifier<EntrySettings> {
  static const _calendarKey = 'entry_calendar_after_amount';
  static const _descriptionKey = 'entry_description_after_amount';
  static const _orderKey = 'entry_field_order';
  static const _weekStartKey = 'calendar_week_start';
  static const _centeredTransfersKey = 'ledger_centered_transfers';
  static const _mirroredInflowsKey = 'ledger_mirrored_inflows';

  @override
  EntrySettings build() {
    final prefs = ref.watch(sharedPrefProvider);
    final names = EntryField.values.asNameMap();
    final stored = [
      for (final name in prefs.getStringList(_orderKey) ?? const <String>[])
        ?names[name],
    ];
    // Keeps fields added by later versions, at the end.
    final order = stored.isEmpty
        ? EntrySettings.defaultOrder
        : [...stored, ...EntryField.values.where((f) => !stored.contains(f))];
    return EntrySettings(
      calendarAfterAmount: prefs.getBool(_calendarKey) ?? true,
      descriptionAfterAmount: prefs.getBool(_descriptionKey) ?? true,
      order: order,
      weekStart:
          WeekStart.values.asNameMap()[prefs.getString(_weekStartKey)] ??
          WeekStart.monday,
      centeredTransfers: prefs.getBool(_centeredTransfersKey) ?? true,
      mirroredInflows: prefs.getBool(_mirroredInflowsKey) ?? true,
    );
  }

  Future<void> update(EntrySettings next) async {
    final prefs = ref.read(sharedPrefProvider);
    await prefs.setBool(_calendarKey, next.calendarAfterAmount);
    await prefs.setBool(_descriptionKey, next.descriptionAfterAmount);
    await prefs.setStringList(_orderKey, [for (final f in next.order) f.name]);
    await prefs.setString(_weekStartKey, next.weekStart.name);
    await prefs.setBool(_centeredTransfersKey, next.centeredTransfers);
    await prefs.setBool(_mirroredInflowsKey, next.mirroredInflows);
    state = next;
  }
}

final entrySettingsProvider =
    NotifierProvider<EntrySettingsNotifier, EntrySettings>(
      EntrySettingsNotifier.new,
    );
