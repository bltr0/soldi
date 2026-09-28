import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../model/place.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/places_provider.dart';
import '../../../services/database/repositories/place_repository.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';

class PlacesSection extends ConsumerWidget {
  const PlacesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spending = ref.watch(placeSpendingProvider);
    final visual = context.dashboardTheme;
    return Padding(
      padding: const EdgeInsets.only(top: Sizes.lg),
      child: TonalGlassSurface(
        radius: 28,
        padding: const EdgeInsets.all(Sizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: Sizes.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Places',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: visual.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Beta · your share of what you spent there',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: visual.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sizes.md),
            spending.when(
              data: (items) {
                if (items.isEmpty) {
                  return Text(
                    'Add a place on a payment. Search uses OpenStreetMap.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: visual.textSecondary,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: Sizes.sm),
                      _PlaceTile(spend: items[i]),
                    ],
                  ],
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: visual.accent),
              ),
              error: (_, _) => TextButton.icon(
                onPressed: () => ref.invalidate(placeSpendingProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'Reload places',
                  style: TextStyle(color: visual.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceTile extends ConsumerWidget {
  const _PlaceTile({required this.spend});

  final PlaceSpend spend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = context.dashboardTheme;
    final symbol = ref.watch(currencyStateProvider).symbol;
    final place = spend.place;
    final payments =
        '${spend.payments} ${spend.payments == 1 ? 'payment' : 'payments'}';

    return TonalGlassSurface(
      onTap: () => _openPayments(context, ref, place),
      radius: 14,
      color: visual.raisedSurface,
      borderColor: visual.glassBorder,
      padding: const EdgeInsets.symmetric(
        horizontal: Sizes.md,
        vertical: Sizes.sm,
      ),
      boxShadow: const [],
      semanticLabel: '${place.name}, $payments',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: visual.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  place.address ?? payments,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: visual.textSecondary),
                ),
                if (place.address != null)
                  Text(
                    payments,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: visual.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          BlurWidget(
            child: Text(
              '${spend.spent.toCurrency()}$symbol',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: visual.textPrimary,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPayments(
    BuildContext context,
    WidgetRef ref,
    Place place,
  ) async {
    final payments = await ref
        .read(placeRepositoryProvider)
        .expensesAt(place.id!);
    if (!context.mounted) return;
    final symbol = ref.read(currencyStateProvider).symbol;
    final visual = context.dashboardTheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(Sizes.lg, 0, Sizes.lg, Sizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                place.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (place.address != null)
                Text(
                  place.address!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: visual.textSecondary),
                ),
              Text(
                '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: visual.textSecondary),
              ),
              const SizedBox(height: Sizes.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: payments.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: visual.hairline),
                  itemBuilder: (context, index) {
                    final payment = payments[index];
                    final title = payment.note?.trim().isNotEmpty == true
                        ? payment.note!.trim()
                        : 'Payment';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        title,
                        style: TextStyle(
                          color: visual.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('d MMM y').format(payment.date),
                        style: TextStyle(color: visual.textSecondary),
                      ),
                      trailing: Text(
                        '${payment.personalShare.toCurrency()}$symbol',
                        style: TextStyle(
                          color: visual.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
