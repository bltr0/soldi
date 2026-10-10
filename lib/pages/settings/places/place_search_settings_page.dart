import 'package:flutter/material.dart';

import '../../../services/places/place_search.dart';
import '../../../services/places/place_search_provider.dart';
import '../../../services/places/place_search_settings_store.dart';
import '../../../ui/device.dart';

/// Choose the place search service and paste its API keys.
class PlaceSearchSettingsPage extends StatefulWidget {
  const PlaceSearchSettingsPage({super.key});

  @override
  State<PlaceSearchSettingsPage> createState() =>
      _PlaceSearchSettingsPageState();
}

class _PlaceSearchSettingsPageState extends State<PlaceSearchSettingsPage> {
  final _store = const PlaceSearchSettingsStore();
  final _controllers = <PlaceSearchProvider, List<TextEditingController>>{};
  PlaceSearchSettings? _settings;
  PlaceSearchProvider? _testing;
  final _testResults = <PlaceSearchProvider, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _store.read();
    for (final provider in PlaceSearchProvider.values) {
      final keys = settings.keysFor(provider);
      _controllers[provider] = [
        for (var i = 0; i < provider.keyFields.length; i++)
          TextEditingController(text: i < keys.length ? keys[i] : ''),
      ];
    }
    if (mounted) setState(() => _settings = settings);
  }

  @override
  void dispose() {
    for (final list in _controllers.values) {
      for (final c in list) {
        c.dispose();
      }
    }
    super.dispose();
  }

  PlaceSearchSettings _current() => _settings!.copyWith(
    keys: {
      for (final e in _controllers.entries)
        if (e.value.isNotEmpty) e.key: [for (final c in e.value) c.text.trim()],
    },
  );

  Future<void> _save({PlaceSearchProvider? selected}) async {
    final settings = _current().copyWith(selected: selected);
    await _store.write(settings);
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _test(PlaceSearchProvider provider) async {
    setState(() {
      _testing = provider;
      _testResults.remove(provider);
    });
    String result;
    try {
      final hits = await searchPlaces(
        provider == PlaceSearchProvider.amap ? '咖啡' : 'coffee',
        _current(),
        provider: provider,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      result = 'Works: ${hits.length} results';
    } catch (error) {
      result = 'Failed: $error';
    }
    if (!mounted) return;
    setState(() {
      _testing = null;
      _testResults[provider] = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Place search'),
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Sizes.lg),
              children: [
                Text(
                  'Pick the service used to find new places. Only your search '
                  'text is sent to it, never amounts. Keys are stored '
                  'encrypted on this device. If the chosen service has no '
                  'key, OpenStreetMap is used.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Sizes.lg),
                RadioGroup<PlaceSearchProvider>(
                  groupValue: settings.selected,
                  onChanged: (p) => _save(selected: p),
                  child: Column(
                    children: [
                      for (final provider in PlaceSearchProvider.values)
                        _providerCard(context, settings, provider),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _providerCard(
    BuildContext context,
    PlaceSearchSettings settings,
    PlaceSearchProvider provider,
  ) {
    final controllers = _controllers[provider]!;
    final missingKey =
        provider == settings.selected && !settings.isConfigured(provider);
    return Card(
      margin: const EdgeInsets.only(bottom: Sizes.md),
      child: Padding(
        padding: const EdgeInsets.all(Sizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioListTile<PlaceSearchProvider>(
              contentPadding: EdgeInsets.zero,
              value: provider,
              title: Text(provider.label),
              subtitle: Text(
                missingKey
                    ? '${provider.region}. Add a key to use it.'
                    : provider.region,
              ),
            ),
            for (var i = 0; i < controllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Sizes.sm),
                child: TextField(
                  controller: controllers[i],
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: provider.keyFields[i],
                    isDense: true,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _testResults[provider] ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _testing == null ? () => _test(provider) : null,
                  child: _testing == provider
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Test'),
                ),
                if (controllers.isNotEmpty)
                  FilledButton(
                    onPressed: () async {
                      await _save();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${provider.label} keys saved')),
                      );
                    },
                    child: const Text('Save'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
