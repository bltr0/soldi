import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/fx_provider.dart';
import '../device.dart';
import '../theme/dashboard_visual_theme.dart';

/// Asks whether exchange rates may be fetched from Frankfurter, and stores
/// the answer. Does nothing if the user already chose. Until they do, no
/// amount is converted.
Future<void> askFxSourceIfUnset(BuildContext context, WidgetRef ref) async {
  if (ref.read(fxSourceSettingProvider) != FxSource.unset) return;
  final choice = await showDialog<FxSource>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _FxSourceDialog(),
  );
  if (choice == null) return;
  await ref.read(fxSourceSettingProvider.notifier).set(choice);
}

class _FxSourceDialog extends StatelessWidget {
  const _FxSourceDialog();

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(
      color: visual.textSecondary,
      height: 1.35,
    );

    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: Sizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: visual.accent),
          const SizedBox(width: Sizes.sm),
          Expanded(child: Text(text, style: bodyStyle)),
        ],
      ),
    );

    return Dialog(
      backgroundColor: visual.solidSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: visual.hairline),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Sizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: visual.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.currency_exchange_rounded,
                  color: visual.accent,
                ),
              ),
              const SizedBox(height: Sizes.lg),
              Text(
                'Convert other currencies?',
                style: textTheme.titleLarge?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: Sizes.sm),
              Text(
                'Accounts held in another currency can be shown in your main '
                'one too, using the rate of the day each transaction happened.',
                style: bodyStyle,
              ),
              point(
                Icons.cloud_download_outlined,
                'Online: daily rates from Frankfurter (frankfurter.dev), '
                'fetched once a day when you open the app. Only currency '
                'codes and dates are sent, never amounts or accounts.',
              ),
              point(
                Icons.cloud_off_outlined,
                'Offline: nothing is sent. Only the rates implied by your own '
                'cross-currency transfers are used.',
              ),
              const SizedBox(height: Sizes.sm),
              Text(
                'You can change this anytime in General settings.',
                style: textTheme.bodySmall?.copyWith(
                  color: visual.textSecondary,
                ),
              ),
              const SizedBox(height: Sizes.xl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, FxSource.offline),
                      style: TextButton.styleFrom(
                        foregroundColor: visual.textPrimary,
                        minimumSize: const Size.fromHeight(50),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Stay offline'),
                    ),
                  ),
                  const SizedBox(width: Sizes.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, FxSource.frankfurter),
                      style: FilledButton.styleFrom(
                        backgroundColor: visual.navigationSelected,
                        foregroundColor: visual.navigationFill.withValues(
                          alpha: 1,
                        ),
                        minimumSize: const Size.fromHeight(50),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Use online rates'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
