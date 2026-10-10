import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_phoenix/flutter_phoenix.dart';

import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/focus_reset_observer.dart';
import 'routes/routes.dart';
import 'services/backup/drive_backup_service.dart';
import 'services/database/repositories/recurring_transactions_repository.dart';
import 'services/database/sossoldi_database.dart';
import 'services/notifications/notifications_service.dart';
import 'services/security/app_lock.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/pin_pad.dart';

void _initDesktopDatabase() {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<void> _authenticateIfRequired(
  SharedPreferences sharedPreferences,
) async {
  // local_auth has no Linux implementation; calling it here throws and
  // leaves the GTK window on a black frame because runApp never runs.
  if (!(Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows)) {
    return;
  }

  try {
    final LocalAuthentication auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return;

    if (AppLock(sharedPreferences).mode != AppLockMode.device) return;

    final bool didAuthenticate = await auth.authenticate(
      localizedReason: 'Please authenticate to use Sossoldi',
      persistAcrossBackgrounding: true,
    );
    if (!didAuthenticate) {
      exit(0);
    }
  } catch (_) {
    // Continue without a lock screen if biometrics are unavailable.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initDesktopDatabase();
  NotificationService().initializeNotifications();
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.local);

  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  final SharedPreferences sharedPreferences =
      await SharedPreferences.getInstance();

  // KV migration from the 'is_first_login' key to 'onboarding_completed'
  // to correctly handle the completion of the onboarding process
  // (To consider to remove in later future)
  final bool? isFirstLoginCachedValue = sharedPreferences.getBool(
    'is_first_login',
  );
  final bool isOnBoardingCompletedKeyNotSaved =
      sharedPreferences.getBool('onboarding_completed') == null;
  if (isFirstLoginCachedValue != null && isOnBoardingCompletedKeyNotSaved) {
    await sharedPreferences.setBool(
      'onboarding_completed',
      !isFirstLoginCachedValue,
    );
  }

  // perform recurring transactions checks
  DateTime? lastCheckGetPref =
      sharedPreferences.getString('last_recurring_transactions_check') != null
      ? DateTime.parse(
          sharedPreferences.getString('last_recurring_transactions_check')!,
        )
      : null;
  DateTime? lastRecurringTransactionsCheck = lastCheckGetPref;

  if (lastRecurringTransactionsCheck == null ||
      DateTime.now().difference(lastRecurringTransactionsCheck).inDays >= 1) {
    RecurringTransactionRepository(
      database: SossoldiDatabase.instance,
    ).checkRecurringTransactions();
    // update last recurring transactions runtime
    await sharedPreferences.setString(
      'last_recurring_transactions_check',
      DateTime.now().toIso8601String(),
    );
  }

  await _authenticateIfRequired(sharedPreferences);

  try {
    await initializeDateFormatting('it_IT');
  } catch (_) {
    // Italian locale data is optional; the app can start without it.
  }

  runApp(
    Phoenix(
      child: ProviderScope(
        overrides: [
          versionProvider.overrideWithValue(packageInfo.version),
          sharedPrefProvider.overrideWithValue(sharedPreferences),
        ],
        child: const Launcher(),
      ),
    ),
  );

  unawaited(_maybeBackupToDrive(sharedPreferences));
}

Future<void> _maybeBackupToDrive(SharedPreferences sharedPreferences) async {
  final drive = DriveBackupService.instance;
  if (!drive.isSupported || !drive.isConfigured) return;
  if (sharedPreferences.getBool(driveBackupOnOpenPref) != true) return;
  final last = sharedPreferences.getInt(driveLastBackupMsPref) ?? 0;
  if (DateTime.now().millisecondsSinceEpoch - last < 24 * 60 * 60 * 1000) {
    return;
  }
  try {
    await drive.restoreSession();
    if (drive.currentUser == null) return;
    final csv = await SossoldiDatabase.instance.exportToCSV();
    await drive.uploadCsv(csv);
    await sharedPreferences.setInt(
      driveLastBackupMsPref,
      DateTime.now().millisecondsSinceEpoch,
    );
  } catch (_) {}
}

class Launcher extends ConsumerWidget {
  const Launcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeState = ref.watch(appThemeStateProvider);
    final bool isOnboardingCompleted = ref.watch(onBoardingCompletedProvider);
    return MaterialApp(
      title: 'Sossoldi',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: appThemeState.isDarkModeEnabled
          ? ThemeMode.dark
          : ThemeMode.light,
      onGenerateRoute: makeRoute,
      navigatorObservers: [FocusResetObserver()],
      builder: (context, child) => AppLockGate(child: child!),
      initialRoute: !isOnboardingCompleted ? '/onboarding' : '/',
    );
  }
}
