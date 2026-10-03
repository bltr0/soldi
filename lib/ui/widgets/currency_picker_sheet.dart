import 'package:flutter/material.dart';

import '../../model/currency_catalog.dart';
import '../device.dart';
import '../theme/dashboard_visual_theme.dart';

/// What the user picked in [showCurrencyPicker]. A null [code] means
/// "use the app's main currency".
class CurrencyChoice {
  const CurrencyChoice(this.code);

  final String? code;
}

/// Searchable list of every currency in [CurrencyCatalog].
///
/// Returns null when dismissed. [mainLabel] describes the app's main
/// currency, offered first as the default.
Future<CurrencyChoice?> showCurrencyPicker(
  BuildContext context, {
  required String? selected,
  required String mainLabel,
}) {
  return showModalBottomSheet<CurrencyChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _CurrencyPicker(
        selected: selected,
        mainLabel: mainLabel,
        scrollController: scrollController,
      ),
    ),
  );
}

class _CurrencyPicker extends StatefulWidget {
  const _CurrencyPicker({
    required this.selected,
    required this.mainLabel,
    required this.scrollController,
  });

  final String? selected;
  final String mainLabel;
  final ScrollController scrollController;

  @override
  State<_CurrencyPicker> createState() => _CurrencyPickerState();
}

class _CurrencyPickerState extends State<_CurrencyPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final results = CurrencyCatalog.search(_query);
    final showDefault = _query.trim().isEmpty;

    Widget tile({
      required String leading,
      required String title,
      String? subtitle,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: selected
              ? visual.accent
              : visual.textPrimary.withValues(alpha: 0.08),
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(Sizes.xs),
              child: Text(
                leading,
                style: textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : visual.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          title,
          style: textTheme.titleSmall?.copyWith(
            color: visual.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: visual.textSecondary,
                ),
              ),
        trailing: selected
            ? Icon(Icons.check_rounded, color: visual.accent)
            : null,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Sizes.lg,
            0,
            Sizes.lg,
            Sizes.sm,
          ),
          child: TextField(
            autofocus: false,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search by name or code (e.g. KRW)',
              filled: true,
              fillColor: visual.textPrimary.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: results.length + (showDefault ? 1 : 0),
            itemBuilder: (context, index) {
              if (showDefault && index == 0) {
                return tile(
                  leading: '•',
                  title: 'App currency',
                  subtitle: widget.mainLabel,
                  selected: widget.selected == null,
                  onTap: () =>
                      Navigator.of(context).pop(const CurrencyChoice(null)),
                );
              }
              final currency = results[index - (showDefault ? 1 : 0)];
              return tile(
                leading: currency.symbol,
                title: currency.name,
                subtitle: currency.code,
                selected: widget.selected == currency.code,
                onTap: () =>
                    Navigator.of(context).pop(CurrencyChoice(currency.code)),
              );
            },
          ),
        ),
      ],
    );
  }
}
