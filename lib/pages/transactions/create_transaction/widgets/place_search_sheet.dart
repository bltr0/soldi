import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../model/place.dart';
import '../../../../providers/places_provider.dart';
import '../../../../services/database/repositories/place_repository.dart';
import '../../../../services/places/place_search.dart';
import '../../../../services/places/place_search_provider.dart';
import '../../../../services/places/place_search_settings_store.dart';
import '../../../../ui/device.dart';
import '../../../../ui/widgets/accent_button.dart';
import '../../../../ui/widgets/place_provider_badge.dart';
import '../../../../ui/widgets/settings_tiles.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';

typedef PlaceSearchChoice = ({bool apply, Place? place});

/// Renames a saved place. The stored coordinates are left unchanged.
Future<Place?> promptRenamePlace(
  BuildContext context,
  WidgetRef ref,
  Place place,
) async {
  final visual = context.dashboardTheme;
  final controller = TextEditingController(text: place.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Rename place',
                  style: textTheme.titleLarge?.copyWith(
                    color: visual.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Sizes.sm),
                Text(
                  'The map location stays put: '
                  '${place.latitude.toStringAsFixed(5)}, '
                  '${place.longitude.toStringAsFixed(5)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: visual.textSecondary,
                  ),
                ),
                const SizedBox(height: Sizes.lg),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) => Navigator.of(context).pop(value),
                  style: textTheme.titleSmall?.copyWith(
                    color: visual.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: placeFieldDecoration(context, hint: 'Name'),
                ),
                const SizedBox(height: Sizes.xl),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: Sizes.md),
                    Expanded(
                      child: AccentButton(
                        label: 'Save',
                        icon: Icons.check_rounded,
                        onPressed: () =>
                            Navigator.of(context).pop(controller.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  controller.dispose();
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == place.name) return null;
  final updated = await ref
      .read(placeRepositoryProvider)
      .rename(place, trimmed);
  ref.invalidate(savedPlacesProvider);
  ref.invalidate(placeSpendingProvider);
  final selected = ref.read(selectedPlaceProvider);
  if (selected?.id == updated.id) {
    ref.read(selectedPlaceProvider.notifier).setPlace(updated);
  }
  return updated;
}

/// Filled, borderless field used across the place panels.
InputDecoration placeFieldDecoration(
  BuildContext context, {
  required String hint,
  IconData? icon,
}) {
  final visual = context.dashboardTheme;
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: visual.textSecondary),
    prefixIcon: icon == null ? null : Icon(icon, color: visual.textSecondary),
    filled: true,
    fillColor: visual.textPrimary.withValues(alpha: 0.06),
    contentPadding: const EdgeInsets.all(Sizes.md),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );
}

Future<PlaceSearchChoice?> showPlaceSearchSheet(
  BuildContext context, {
  bool canClear = false,
}) {
  return showModalBottomSheet<PlaceSearchChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.dashboardTheme.solidSurface,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => PlaceSearchSheet(canClear: canClear),
  );
}

class PlaceSearchSheet extends ConsumerStatefulWidget {
  const PlaceSearchSheet({this.canClear = false, super.key});

  final bool canClear;

  @override
  ConsumerState<PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<PlaceSearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceHit> _hits = const [];
  bool _loading = false;
  bool _saving = false;
  String? _error;
  PlaceSearchSettings _searchSettings = const PlaceSearchSettings();

  /// Service picked in the panel's filter; defaults to the settings choice.
  PlaceSearchProvider? _filter;

  PlaceSearchProvider get _active => _filter ?? _searchSettings.effective;

  String get _serviceLabel => _active.label;

  List<PlaceSearchProvider> get _available => [
    for (final provider in PlaceSearchProvider.values)
      if (_searchSettings.isConfigured(provider)) provider,
  ];

  void _selectProvider(PlaceSearchProvider provider) {
    if (provider == _active) return;
    setState(() {
      _filter = provider;
      _hits = const [];
    });
    _search(_controller.text);
  }

  @override
  void initState() {
    super.initState();
    const PlaceSearchSettingsStore().read().then((settings) {
      if (mounted) setState(() => _searchSettings = settings);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _hits = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final language = Localizations.localeOf(context).languageCode;
      final provider = _active;
      final hits = await searchPlaces(
        query,
        _searchSettings,
        provider: provider,
        languageCode: language,
      );
      if (!mounted || _controller.text.trim() != query) return;
      if (_active != provider) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is PlaceSearchException
            ? '$error'
            : '$_serviceLabel search is unavailable right now.';
      });
    }
  }

  Future<void> _choose(PlaceHit hit) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final place = await ref.read(placeRepositoryProvider).saveHit(hit);
      ref.invalidate(savedPlacesProvider);
      if (!mounted) return;
      Navigator.of(context).pop((apply: true, place: place));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'That place could not be saved.';
      });
    }
  }

  Widget _results(DashboardVisualTheme visual) {
    final saved = ref.watch(savedPlacesProvider).value ?? const <Place>[];
    final query = _controller.text.trim().toLowerCase();
    final mine = [
      for (final place in saved)
        if (query.isEmpty ||
            place.name.toLowerCase().contains(query) ||
            (place.address?.toLowerCase().contains(query) ?? false))
          place,
    ];
    final showMap = query.length >= 2;

    if (mine.isEmpty && !showMap && !_loading && _error == null) {
      return Center(
        child: Text(
          'Search $_serviceLabel to save a place, then pick it from this list.',
          textAlign: TextAlign.center,
          style: TextStyle(color: visual.textSecondary),
        ),
      );
    }

    return ListView(
      children: [
        if (mine.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: Sizes.sm, bottom: Sizes.xs),
            child: _SectionLabel('Your places'),
          ),
        for (final place in mine)
          _PlaceRow(
            provider: PlaceSearchProvider.fromId(place.provider),
            name: place.name,
            address: place.address,
            onTap: () => Navigator.of(context).pop((apply: true, place: place)),
            trailing: IconButton(
              tooltip: 'Rename',
              onPressed: () async {
                final updated = await promptRenamePlace(context, ref, place);
                if (!mounted || updated == null) return;
                setState(() {});
              },
              icon: Icon(Icons.edit_rounded, color: visual.textSecondary),
            ),
          ),
        if (showMap) ...[
          Padding(
            padding: const EdgeInsets.only(top: Sizes.md, bottom: Sizes.xs),
            child: _SectionLabel(_serviceLabel),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(Sizes.md),
              child: Center(
                child: CircularProgressIndicator(color: visual.accent),
              ),
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(color: visual.textSecondary))
          else if (_hits.isEmpty)
            Text(
              'No map result for that search.',
              style: TextStyle(color: visual.textSecondary),
            )
          else
            for (final hit in _hits)
              _PlaceRow(
                provider: PlaceSearchProvider.fromId(hit.provider),
                name: hit.name,
                address: hit.address,
                onTap: _saving ? null : () => _choose(hit),
              ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sizes.lg,
        Sizes.sm,
        Sizes.lg,
        bottom + Sizes.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Place',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: visual.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (_available.length > 1) ...[
            const SizedBox(height: Sizes.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final provider in _available)
                    Padding(
                      padding: const EdgeInsets.only(right: Sizes.xs),
                      child: TogglePill(
                        leading: PlaceProviderBadge(
                          provider: provider,
                          size: 18,
                        ),
                        label: provider.label,
                        selected: provider == _active,
                        onTap: () => _selectProvider(provider),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Sizes.sm),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _search,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            style: TextStyle(color: visual.textPrimary),
            decoration: placeFieldDecoration(
              context,
              hint: 'Your places, or a new $_serviceLabel search',
              icon: Icons.search_rounded,
            ),
          ),
          if (widget.canClear) ...[
            const SizedBox(height: Sizes.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TogglePill(
                label: 'Remove place',
                selected: false,
                onTap: () =>
                    Navigator.of(context).pop((apply: true, place: null)),
              ),
            ),
          ],
          const SizedBox(height: Sizes.sm),
          SizedBox(height: 320, child: _results(visual)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: context.dashboardTheme.textSecondary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// One place in the panel: source logo, name, address.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.provider,
    required this.name,
    required this.address,
    required this.onTap,
    this.trailing,
  });

  final PlaceSearchProvider? provider;
  final String name;
  final String? address;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sizes.sm),
        child: Row(
          children: [
            PlaceProviderBadge(provider: provider, size: 36),
            const SizedBox(width: Sizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: visual.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (address != null)
                    Text(
                      address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: visual.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
