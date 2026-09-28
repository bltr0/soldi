import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../model/place.dart';
import '../../../../providers/places_provider.dart';
import '../../../../services/database/repositories/place_repository.dart';
import '../../../../services/places/photon_search.dart';
import '../../../../ui/device.dart';
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
    builder: (context) => AlertDialog(
      title: const Text('Rename place'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The map location stays put.',
            style: TextStyle(color: visual.textSecondary),
          ),
          const SizedBox(height: Sizes.sm),
          Text(
            '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: visual.textSecondary),
          ),
          const SizedBox(height: Sizes.md),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
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

Future<PlaceSearchChoice?> showPlaceSearchSheet(
  BuildContext context, {
  bool canClear = false,
}) {
  return showModalBottomSheet<PlaceSearchChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
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
      final hits = await searchPhotonPlaces(query, languageCode: language);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Place search is unavailable right now.';
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
          'Search OpenStreetMap to save a place, then pick it from this list.',
          textAlign: TextAlign.center,
          style: TextStyle(color: visual.textSecondary),
        ),
      );
    }

    return ListView(
      children: [
        if (mine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Sizes.sm, bottom: Sizes.xs),
            child: Text(
              'Your places',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: visual.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        for (final place in mine)
          ListTile(
            contentPadding: EdgeInsets.zero,
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
            trailing: IconButton(
              tooltip: 'Rename',
              onPressed: () async {
                final updated = await promptRenamePlace(context, ref, place);
                if (!mounted || updated == null) return;
                setState(() {});
              },
              icon: Icon(Icons.edit_outlined, color: visual.textSecondary),
            ),
            onTap: () => Navigator.of(context).pop((apply: true, place: place)),
          ),
        if (showMap) ...[
          Padding(
            padding: const EdgeInsets.only(top: Sizes.md, bottom: Sizes.xs),
            child: Text(
              'OpenStreetMap',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: visual.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: !_saving,
                title: Text(
                  hit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: visual.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: hit.address == null
                    ? null
                    : Text(
                        hit.address!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: visual.textSecondary),
                      ),
                onTap: () => _choose(hit),
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
          const SizedBox(height: Sizes.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _search,
            style: TextStyle(color: visual.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Your places, or a new OpenStreetMap search',
              hintStyle: TextStyle(color: visual.textSecondary),
              prefixIcon: Icon(
                Icons.place_outlined,
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
          if (widget.canClear) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pop((apply: true, place: null)),
                child: const Text('Remove place'),
              ),
            ),
          ],
          SizedBox(height: 320, child: _results(visual)),
          Text(
            'Places from OpenStreetMap',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: visual.textSecondary),
          ),
        ],
      ),
    );
  }
}
