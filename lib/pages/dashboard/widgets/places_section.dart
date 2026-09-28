import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../model/place.dart';
import '../../../model/transaction.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/places_provider.dart';
import '../../../services/database/repositories/place_repository.dart';
import '../../../ui/device.dart';
import '../../../ui/extensions.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/blur_widget.dart';
import '../../../ui/widgets/tonal_glass_surface.dart';
import '../../transactions/create_transaction/widgets/place_search_sheet.dart';

class PlacesSection extends ConsumerStatefulWidget {
  const PlacesSection({super.key});

  @override
  ConsumerState<PlacesSection> createState() => _PlacesSectionState();
}

class _PlacesSectionState extends ConsumerState<PlacesSection> {
  final _search = TextEditingController();
  Place? _selected;
  List<Transaction>? _payments;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(Place place) {
    setState(() {
      _selected = place;
      _payments = null;
      _search.clear();
    });
    _load(place);
  }

  Future<void> _load(Place place) async {
    final id = place.id;
    if (id == null) return;
    final payments = await ref.read(placeRepositoryProvider).expensesAt(id);
    if (!mounted || _selected?.id != id) return;
    setState(() => _payments = payments);
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final saved = ref.watch(savedPlacesProvider);
    final spending = ref.watch(placeSpendingProvider);
    final symbol = ref.watch(currencyStateProvider).symbol;

    ref.listen(savedPlacesProvider, (_, next) {
      final id = _selected?.id;
      if (id == null) return;
      next.whenData((places) {
        for (final place in places) {
          if (place.id == id) {
            if (place.name != _selected!.name && mounted) {
              setState(() => _selected = place);
            }
            return;
          }
        }
      });
    });
    ref.listen(placeSpendingProvider, (_, _) {
      final place = _selected;
      if (place != null) _load(place);
    });

    final query = _search.text.trim().toLowerCase();
    final matches = <Place>[];
    if (query.isNotEmpty) {
      for (final place in saved.value ?? const <Place>[]) {
        final address = place.address?.toLowerCase() ?? '';
        if (place.name.toLowerCase().contains(query) ||
            address.contains(query)) {
          matches.add(place);
        }
        if (matches.length == 6) break;
      }
    }

    PlaceSpend? spend;
    for (final item in spending.value ?? const <PlaceSpend>[]) {
      if (item.place.id == _selected?.id) {
        spend = item;
        break;
      }
    }
    final paymentCount = spend?.payments ?? 0;
    final spent = spend?.spent ?? 0;
    final average = paymentCount == 0 ? 0 : spent / paymentCount;

    return Padding(
      padding: const EdgeInsets.only(top: Sizes.lg),
      child: TonalGlassSurface(
        radius: 28,
        padding: const EdgeInsets.all(Sizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: Sizes.sm),
              child: Text(
                'Places',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: visual.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'Beta · pick a saved place',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: visual.textSecondary),
            ),
            const SizedBox(height: Sizes.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: visual.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _selected?.name ?? 'Search your places',
                      hintStyle: TextStyle(
                        color: _selected == null
                            ? visual.textSecondary
                            : visual.textPrimary,
                        fontWeight: _selected == null
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: visual.textSecondary,
                      ),
                      filled: true,
                      fillColor: visual.textPrimary.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add a place',
                  onPressed: () async {
                    final choice = await showPlaceSearchSheet(context);
                    if (choice == null ||
                        !choice.apply ||
                        choice.place == null) {
                      return;
                    }
                    _select(choice.place!);
                  },
                  icon: Icon(Icons.add_rounded, color: visual.textPrimary),
                ),
              ],
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: Sizes.sm),
              if (matches.isEmpty)
                Text(
                  'No saved place matches that.',
                  style: TextStyle(color: visual.textSecondary),
                )
              else
                for (final place in matches)
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Sizes.sm,
                    ),
                    title: Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: visual.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: place.address == null
                        ? null
                        : Text(
                            place.address!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: visual.textSecondary),
                          ),
                    onTap: () => _select(place),
                  ),
            ],
            if (saved.hasError)
              TextButton.icon(
                onPressed: () => ref.invalidate(savedPlacesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'Reload places',
                  style: TextStyle(color: visual.textSecondary),
                ),
              )
            else if ((saved.value ?? const <Place>[]).isEmpty && query.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Sizes.md, left: Sizes.sm),
                child: Text(
                  'Save a place from a payment, or add one here. You can rename it. The location stays fixed.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: visual.textSecondary),
                ),
              ),
            if (_selected != null && query.isEmpty) ...[
              const SizedBox(height: Sizes.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selected!.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: visual.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (_selected!.address != null)
                          Text(
                            _selected!.address!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: visual.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rename',
                    onPressed: () async {
                      final updated = await promptRenamePlace(
                        context,
                        ref,
                        _selected!,
                      );
                      if (updated != null && mounted) {
                        setState(() => _selected = updated);
                      }
                    },
                    icon: Icon(
                      Icons.edit_outlined,
                      color: visual.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sizes.md),
              Row(
                children: [
                  _Stat(value: '$paymentCount', label: 'Payments'),
                  _Stat(
                    value: '${spent.toCurrency()}$symbol',
                    label: 'Spent',
                    blur: true,
                  ),
                  _Stat(
                    value: '${average.toCurrency()}$symbol',
                    label: 'Per payment',
                    blur: true,
                  ),
                ],
              ),
              if (_payments != null && _payments!.isNotEmpty) ...[
                const SizedBox(height: Sizes.md),
                for (final payment in _payments!.take(8))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      payment.note?.trim().isNotEmpty == true
                          ? payment.note!.trim()
                          : 'Payment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: visual.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('d MMM y').format(payment.date),
                      style: TextStyle(color: visual.textSecondary),
                    ),
                    trailing: BlurWidget(
                      child: Text(
                        '${payment.personalShare.toCurrency()}$symbol',
                        style: TextStyle(
                          color: visual.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ] else if (paymentCount == 0)
                Padding(
                  padding: const EdgeInsets.only(top: Sizes.md),
                  child: Text(
                    'No payments at this place yet.',
                    style: TextStyle(color: visual.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.blur = false});

  final String value;
  final String label;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final amount = Text(
      value,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: visual.textPrimary,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          blur ? BlurWidget(child: amount) : amount,
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: visual.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
