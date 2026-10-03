import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fx_provider.dart';

/// Asks whether exchange rates may be fetched from Frankfurter, and stores
/// the answer. Does nothing if the user already chose.
Future<void> askFxSourceIfUnset(BuildContext context, WidgetRef ref) async {
  if (ref.read(fxSourceSettingProvider) != FxSource.unset) return;
  final choice = await showDialog<FxSource>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Show other currencies in your main one?'),
      content: const SingleChildScrollView(
        child: Text(
          'This account uses a different currency than the app. To show its '
          'balance and transactions in your main currency too, Sossoldi can '
          'download daily exchange rates from Frankfurter (frankfurter.dev).\n\n'
          '• Only the currency codes and dates are sent, never your amounts '
          'or accounts.\n'
          '• Rates are fetched once a day when you open the app, never in '
          'the background.\n'
          '• Or stay completely offline: nothing is sent, and conversions use '
          'only the rates from your own cross-currency transfers.\n\n'
          'You can change this later in Settings.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, FxSource.offline),
          child: const Text('Stay offline'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, FxSource.frankfurter),
          child: const Text('Use Frankfurter rates'),
        ),
      ],
    ),
  );
  await ref
      .read(fxSourceSettingProvider.notifier)
      .set(choice ?? FxSource.offline);
}
