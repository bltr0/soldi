import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fx_provider.dart';
import '../device.dart';
import '../theme/dashboard_visual_theme.dart';

/// Underlines a total that adds some foreign amounts 1:1 because no rate is
/// known for them; tapping it explains why.
class UnconvertedAmount extends ConsumerWidget {
  const UnconvertedAmount({
    required this.unconverted,
    required this.child,
    super.key,
  });

  final bool unconverted;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!unconverted) return child;
    final visual = context.dashboardTheme;
    return Semantics(
      button: true,
      hint: 'Some amounts are not converted. Tap for details.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _explain(context, ref.read(fxSourceSettingProvider)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: visual.textSecondary, width: 1.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  void _explain(BuildContext context, FxSource source) {
    final visual = context.dashboardTheme;
    final reason = switch (source) {
      FxSource.unset =>
        'You have not chosen how exchange rates are found, so nothing is '
            'converted yet. Pick Online or Offline in General Settings.',
      FxSource.offline =>
        'Offline mode only knows rates from your own transfers between these '
            'currencies, and none covers some of these amounts.',
      FxSource.frankfurter =>
        'No published rate exists yet for the day of some of these '
            'transactions (rates are fetched once a day, and some currencies '
            'are not published).',
    };
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: visual.solidSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Icon(Icons.currency_exchange_rounded, color: visual.accent),
        title: const Text('Not fully converted'),
        content: Text(
          'This total includes amounts in other currencies counted as if they '
          'were in your main currency (1:1).\n\n$reason',
          style: TextStyle(color: visual.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          Sizes.lg,
          0,
          Sizes.lg,
          Sizes.lg,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
