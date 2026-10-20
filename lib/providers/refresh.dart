import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'accounts_provider.dart';
import 'dashboard_provider.dart';
import 'fx_provider.dart';
import 'statistics_provider.dart';

/// Pull-to-refresh on Home and Graphs: fetches exchange rates again (when
/// allowed) and reloads what those pages show.
Future<void> refreshAppData(WidgetRef ref) async {
  await ref.read(fxSyncProvider.notifier).sync(force: true);
  ref.invalidate(fxTableProvider);
  ref.invalidate(accountsProvider);
  ref.invalidate(dashboardProvider);
  ref.invalidate(statisticsProvider);
  await Future.wait([
    ref.read(dashboardProvider.future),
    ref.read(statisticsProvider.future),
  ]).catchError((_) => const <Object>[]);
}
