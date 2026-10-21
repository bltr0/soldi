import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_log.dart';
import '../database/sossoldi_database.dart';
import 'backup_codec.dart';
import 'drive_backup_service.dart';

const driveLastBackupErrorPref = 'drive_last_backup_error';
const driveLastBackupAttemptMsPref = 'drive_last_backup_attempt_ms';

const _alarmId = 4242;
const _notificationId = 4243;

/// Catch-up when the app opens: only if the midnight run was missed.
const _catchUpAfter = Duration(hours: 26);

bool _running = false;

/// Uploads an (encrypted when set up) backup to Drive when automatic
/// backups are on. Runs at midnight from an alarm, and as a catch-up when
/// the app opens or comes back after a missed night. Shows a notification
/// and logs every attempt.
///
/// This is the only work Sossoldi does in the background: the battery
/// exemption exists so this upload can reach the network while the phone
/// sleeps. Exchange rates and everything else run only while the app is
/// open.
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
  if (!force && age < _catchUpAfter) return;

  _running = true;
  await prefs.setInt(
    driveLastBackupAttemptMsPref,
    DateTime.now().millisecondsSinceEpoch,
  );
  AppLog.info('backup', 'Auto backup ($trigger), last success ${_ago(age)}');
  await _notify('Backing up to Google Drive…', null, ongoing: true);
  try {
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
    await _notify(
      'Backup saved to Google Drive',
      backup.encrypted ? 'Encrypted with your passphrase' : null,
    );
  } catch (e, stack) {
    final message = e is DriveBackupException ? e.message : '$e';
    await prefs.setString(driveLastBackupErrorPref, message);
    AppLog.error('backup', 'Auto backup ($trigger) failed: $e', stack);
    await _notify('Backup failed', message);
  } finally {
    _running = false;
  }
}

String _ago(Duration age) => age.inDays > 1000
    ? 'never'
    : age.inHours >= 48
    ? '${age.inDays} days ago'
    : '${age.inHours} h ago';

final _notifications = FlutterLocalNotificationsPlugin();
bool _notificationsReady = false;

const _channel = AndroidNotificationChannel(
  'sossoldi#backup',
  'Backups',
  description: 'Automatic Google Drive backups',
  importance: Importance.low,
);

AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
    .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();

Future<void> _notify(String title, String? body, {bool ongoing = false}) async {
  if (!Platform.isAndroid) return;
  try {
    if (!_notificationsReady) {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _android?.createNotificationChannel(_channel);
      _notificationsReady = true;
    }
    await _notifications.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: ongoing,
          showProgress: ongoing,
          indeterminate: ongoing,
          onlyAlertOnce: true,
        ),
      ),
    );
  } catch (e) {
    AppLog.warn('backup', 'Notification failed: $e');
  }
}

DateTime _nextMidnight() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1);
}

/// Sets (or clears) the alarm for the next midnight. Exact when Android
/// allows it ("Alarms & reminders"), otherwise Android may shift it.
Future<void> scheduleMidnightBackup(bool enabled) async {
  if (!Platform.isAndroid) return;
  try {
    if (!enabled) {
      await AndroidAlarmManager.cancel(_alarmId);
      return;
    }
    final exact = (await backupPermissions()).exactAlarms;
    final at = _nextMidnight();
    await AndroidAlarmManager.oneShotAt(
      at,
      _alarmId,
      midnightBackupCallback,
      exact: exact,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
    AppLog.info(
      'backup',
      'Next automatic backup ${at.toIso8601String().substring(0, 16)}'
          '${exact ? '' : ' (inexact: alarms not allowed)'}',
    );
  } catch (e) {
    AppLog.warn('backup', 'Scheduling the midnight backup failed: $e');
  }
}

/// At startup: prepares the alarm service and makes sure the next midnight
/// is scheduled (app updates drop pending alarms).
Future<void> initAutoBackup(SharedPreferences prefs) async {
  if (!Platform.isAndroid) return;
  try {
    await AndroidAlarmManager.initialize();
    if (prefs.getBool(driveBackupOnOpenPref) == true) {
      await scheduleMidnightBackup(true);
    }
  } catch (e) {
    AppLog.warn('backup', 'Alarm service unavailable: $e');
  }
}

/// Runs in its own isolate when the alarm fires, app open or not.
@pragma('vm:entry-point')
Future<void> midnightBackupCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLog.init();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  if (prefs.getBool(driveBackupOnOpenPref) != true) return;
  await runAutoBackup(prefs, trigger: 'midnight', force: true);
  await scheduleMidnightBackup(true);
}

class BackupPermissions {
  const BackupPermissions({
    required this.notifications,
    required this.exactAlarms,
    required this.battery,
  });

  final bool notifications;
  final bool exactAlarms;
  final bool battery;

  bool get all => notifications && exactAlarms && battery;
}

Future<BackupPermissions> backupPermissions() async {
  if (!Platform.isAndroid) {
    return const BackupPermissions(
      notifications: true,
      exactAlarms: true,
      battery: true,
    );
  }
  return BackupPermissions(
    notifications: await _android?.areNotificationsEnabled() ?? false,
    exactAlarms: await _android?.canScheduleExactNotifications() ?? false,
    battery: await Permission.ignoreBatteryOptimizations.isGranted,
  );
}

/// Asked only when the user turns automatic backups on: notifications (to
/// show the backup), exact alarms (to run at midnight) and the battery
/// exemption (so the phone's sleep mode lets the upload use the network).
Future<BackupPermissions> requestBackupPermissions() async {
  if (Platform.isAndroid) {
    final android = _android;
    if (!(await android?.areNotificationsEnabled() ?? true)) {
      await android?.requestNotificationsPermission();
    }
    if (!(await android?.canScheduleExactNotifications() ?? true)) {
      await android?.requestExactAlarmsPermission();
    }
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
  return backupPermissions();
}
