import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../app_log.dart';
import '../database/sossoldi_database.dart';
import 'backup_codec.dart';
import 'drive_backup_service.dart';

const driveLastBackupErrorPref = 'drive_last_backup_error';
const driveLastBackupAttemptMsPref = 'drive_last_backup_attempt_ms';

const _taskName = 'sossoldi-drive-backup';
const _minInterval = Duration(hours: 24);

bool _running = false;

/// Uploads an (encrypted when set up) backup to Drive when the user turned
/// automatic backups on and the last success is a day old. Called when the
/// app starts, when it comes back to the foreground, and by a daily
/// background job; every attempt and failure goes to the in-app log.
Future<void> runAutoBackup(
  SharedPreferences prefs, {
  required String trigger,
  bool force = false,
}) async {
  if (_running) return;
  final drive = DriveBackupService.instance;
  if (!drive.isSupported || !drive.isConfigured) return;
  if (prefs.getBool(driveBackupOnOpenPref) != true) return;
  final last = prefs.getInt(driveLastBackupMsPref) ?? 0;
  final age = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(last),
  );
  if (!force && age < _minInterval) return;

  _running = true;
  await prefs.setInt(
    driveLastBackupAttemptMsPref,
    DateTime.now().millisecondsSinceEpoch,
  );
  AppLog.info('backup', 'Auto backup ($trigger), last success ${_ago(age)}');
  try {
    await drive.restoreSession();
    if (drive.currentUser == null) {
      throw DriveBackupException(
        'Google session expired, open Backup and sign in again',
      );
    }
    final csv = await SossoldiDatabase.instance.exportToCSV();
    final backup = await const BackupCodec().encode(
      csv,
      backupEncryptionOf(prefs),
    );
    await drive.uploadBackup(backup);
    await prefs.setInt(
      driveLastBackupMsPref,
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.remove(driveLastBackupErrorPref);
    AppLog.info(
      'backup',
      'Auto backup uploaded (${backup.encrypted ? 'encrypted' : 'plain CSV'})',
    );
  } catch (e, stack) {
    await prefs.setString(driveLastBackupErrorPref, '$e');
    AppLog.error('backup', 'Auto backup ($trigger) failed: $e', stack);
  } finally {
    _running = false;
  }
}

String _ago(Duration age) => age.inDays > 1000
    ? 'never'
    : age.inHours >= 48
    ? '${age.inDays} days ago'
    : '${age.inHours} h ago';

/// Daily background run, even when the app is not opened. Android decides
/// the exact time (it waits for a network and may batch it).
Future<void> scheduleBackgroundBackup(bool enabled) async {
  if (!Platform.isAndroid) return;
  try {
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: const Duration(hours: 24),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      await Workmanager().cancelByUniqueName(_taskName);
    }
  } catch (e) {
    AppLog.warn('backup', 'Scheduling background backup failed: $e');
  }
}

Future<void> initBackgroundBackup(SharedPreferences prefs) async {
  if (!Platform.isAndroid) return;
  try {
    await Workmanager().initialize(backupCallbackDispatcher);
    await scheduleBackgroundBackup(
      prefs.getBool(driveBackupOnOpenPref) == true,
    );
  } catch (e) {
    AppLog.warn('backup', 'Background backup unavailable: $e');
  }
}

@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppLog.init();
    final prefs = await SharedPreferences.getInstance();
    await runAutoBackup(prefs, trigger: 'background');
    // Failures are logged and retried tomorrow, not by WorkManager's
    // backoff, so a lost Google session does not spin.
    return true;
  });
}
