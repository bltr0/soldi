import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../model/place.dart';
import '../../../../services/database/repositories/place_repository.dart';
import '../../../../services/places/photon_search.dart';
import '../../../../ui/device.dart';
import '../../../../ui/theme/dashboard_visual_theme.dart';

typedef PlaceSearchChoice = ({bool apply, Place? place});

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
              hintText: 'Search a cafe, shop, or address',
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
          SizedBox(
            height: 280,
            child: _loading
                ? Center(child: CircularProgressIndicator(color: visual.accent))
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: visual.textSecondary),
                    ),
                  )
                : _hits.isEmpty
                ? Center(
                    child: Text(
                      'Type at least two letters.',
                      style: TextStyle(color: visual.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: _hits.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: visual.hairline),
                    itemBuilder: (context, index) {
                      final hit = _hits[index];
                      return ListTile(
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
                      );
                    },
                  ),
          ),
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
