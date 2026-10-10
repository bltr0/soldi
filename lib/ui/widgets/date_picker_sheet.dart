import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';

import '../device.dart';
import '../theme/dashboard_visual_theme.dart';
import 'accent_button.dart';
import 'picker_sheet.dart';
import 'settings_tiles.dart';

/// Picks a day in the app's sheet style. Swipe between months, tap the month
/// title to jump to a month or year, or use the Today / Yesterday shortcuts.
/// Returns the chosen day at midnight, or null when dismissed.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Pick a date',
}) {
  return showPickerSheet<DateTime>(
    context,
    scrollable: false,
    builder: (_, _) => _DatePickerSheet(
      title: title,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _value = DateUtils.dateOnly(widget.initialDate);
  late DateTime _month = _value;

  bool _inRange(DateTime day) =>
      !day.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
      !day.isAfter(DateUtils.dateOnly(widget.lastDate));

  void _jump(DateTime day) => setState(() {
    _value = day;
    _month = day;
  });

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final dayStyle = textTheme.bodyLarge?.copyWith(
      color: visual.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final selectedStyle = dayStyle?.copyWith(
      color: visual.navigationFill.withValues(alpha: 1),
      fontWeight: FontWeight.w800,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, Sizes.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerSheetHeader(title: widget.title),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
            child: Row(
              children: [
                if (_inRange(today))
                  TogglePill(
                    label: 'Today',
                    selected: _value == today,
                    onTap: () => _jump(today),
                  ),
                const SizedBox(width: Sizes.sm),
                if (_inRange(yesterday))
                  TogglePill(
                    label: 'Yesterday',
                    selected: _value == yesterday,
                    onTap: () => _jump(yesterday),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Sizes.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.sm),
            child: CalendarDatePicker2(
              key: ValueKey(_month.year * 100 + _month.month),
              value: [_value],
              displayedMonthDate: _month,
              onDisplayedMonthChanged: (month) => _month = month,
              onValueChanged: (dates) {
                if (dates.isNotEmpty) {
                  setState(() => _value = DateUtils.dateOnly(dates.first));
                }
              },
              config: CalendarDatePicker2Config(
                calendarType: CalendarDatePicker2Type.single,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                currentDate: today,
                firstDayOfWeek: MaterialLocalizations.of(
                  context,
                ).firstDayOfWeekIndex,
                centerAlignModePicker: true,
                dynamicCalendarRows: true,
                controlsTextStyle: textTheme.titleMedium?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
                weekdayLabelTextStyle: textTheme.labelMedium?.copyWith(
                  color: visual.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
                dayTextStyle: dayStyle,
                todayTextStyle: dayStyle?.copyWith(
                  color: visual.accent,
                  fontWeight: FontWeight.w800,
                ),
                selectedDayTextStyle: selectedStyle,
                selectedDayHighlightColor: visual.navigationSelected,
                disabledDayTextStyle: dayStyle?.copyWith(
                  color: visual.textSecondary.withValues(alpha: 0.4),
                ),
                dayBorderRadius: BorderRadius.circular(14),
                monthTextStyle: dayStyle,
                selectedMonthTextStyle: selectedStyle,
                monthBorderRadius: BorderRadius.circular(999),
                yearTextStyle: dayStyle,
                selectedYearTextStyle: selectedStyle,
                yearBorderRadius: BorderRadius.circular(999),
                lastMonthIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: visual.textPrimary,
                ),
                nextMonthIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: visual.textPrimary,
                ),
                customModePickerIcon: Icon(
                  Icons.expand_more_rounded,
                  color: visual.textSecondary,
                ),
                daySplashColor: visual.accent.withValues(alpha: 0.12),
                hideMonthPickerDividers: true,
                hideYearPickerDividers: true,
              ),
            ),
          ),
          const SizedBox(height: Sizes.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.lg),
            child: AccentButton(
              label: 'Done',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(_value),
            ),
          ),
        ],
      ),
    );
  }
}
