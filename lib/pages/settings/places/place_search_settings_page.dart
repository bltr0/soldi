import 'package:flutter/material.dart';

import '../../../services/places/place_search.dart';
import '../../../services/places/place_search_provider.dart';
import '../../../services/places/place_search_settings_store.dart';
import '../../../ui/device.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';
import '../../../ui/widgets/accent_button.dart';
import '../../../ui/widgets/place_provider_badge.dart';
import '../../../ui/widgets/settings_tiles.dart';

/// Choose the default place search service and paste API keys.
class PlaceSearchSettingsPage extends StatefulWidget {
  const PlaceSearchSettingsPage({super.key});

  @override
  State<PlaceSearchSettingsPage> createState() =>
      _PlaceSearchSettingsPageState();
}

class _PlaceSearchSettingsPageState extends State<PlaceSearchSettingsPage> {
  final _store = const PlaceSearchSettingsStore();
  final _controllers = <PlaceSearchProvider, List<TextEditingController>>{};
  final _testResults = <PlaceSearchProvider, String>{};
  PlaceSearchSettings? _settings;
  PlaceSearchProvider? _expanded;
  PlaceSearchProvider? _testing;

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
    FocusManager.instance.primaryFocus?.unfocus();
    final settings = _current().copyWith(selected: selected);
    await _store.write(settings);
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _test(PlaceSearchProvider provider) async {
    FocusManager.instance.primaryFocus?.unfocus();
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
    final visual = context.dashboardTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Place search'),
      ),
      body: settings == null
          ? Center(child: CircularProgressIndicator(color: visual.accent))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                Sizes.lg,
                Sizes.lg,
                Sizes.lg,
                MediaQuery.paddingOf(context).bottom + Sizes.xl,
              ),
              physics: const BouncingScrollPhysics(),
              children: [
                SettingsGroup(
                  title: 'Search services',
                  footer:
                      'Only your search text is sent, never amounts. Keys stay '
                      'encrypted on this device. Without a key, OpenStreetMap '
                      'is used.',
                  children: [
                    for (final provider in PlaceSearchProvider.values)
                      _providerTile(context, settings, provider),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _providerTile(
    BuildContext context,
    PlaceSearchSettings settings,
    PlaceSearchProvider provider,
  ) {
    final visual = context.dashboardTheme;
    final isDefault = provider == settings.selected;
    final configured = settings.isConfigured(provider);
    final expanded = _expanded == provider;
    return SettingsTile(
      leading: PlaceProviderBadge(provider: provider, size: 40),
      title: provider.label,
      onTap: () => setState(() => _expanded = expanded ? null : provider),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDefault)
            SettingsValue(configured ? 'Default' : 'Needs key')
          else if (configured && provider.keyFields.isNotEmpty)
            Icon(Icons.check_circle_rounded, size: 20, color: visual.accent),
          Icon(
            expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: visual.textSecondary,
          ),
        ],
      ),
      below: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bullet(provider.freeTier),
          _Bullet(provider.usefulFor),
          if (expanded) ...[
            for (final (i, controller) in _controllers[provider]!.indexed)
              Padding(
                padding: const EdgeInsets.only(top: Sizes.sm),
                child: TextField(
                  controller: controller,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(color: visual.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: provider.keyFields[i],
                    hintStyle: TextStyle(color: visual.textSecondary),
                    filled: true,
                    fillColor: visual.textPrimary.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.all(Sizes.md),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            if (_testResults[provider] case final result?)
              Padding(
                padding: const EdgeInsets.only(top: Sizes.sm),
                child: Text(
                  result,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: visual.textSecondary),
                ),
              ),
            const SizedBox(height: Sizes.md),
            Row(
              children: [
                TogglePill(
                  label: _testing == provider ? 'Testing…' : 'Test',
                  selected: false,
                  onTap: () {
                    if (_testing == null) _test(provider);
                  },
                ),
                const SizedBox(width: Sizes.sm),
                TogglePill(
                  label: isDefault ? 'Default' : 'Use by default',
                  selected: isDefault,
                  onTap: () => _save(selected: provider),
                ),
              ],
            ),
            if (provider.keyFields.isNotEmpty) ...[
              const SizedBox(height: Sizes.md),
              AccentButton(
                label: 'Save keys',
                icon: Icons.check_rounded,
                onPressed: () async {
                  await _save();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${provider.label} keys saved')),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: visual.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: style),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
