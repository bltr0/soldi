import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  const LogEntry(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  @override
  String toString() {
    final t = time.toIso8601String().substring(0, 19).replaceFirst('T', ' ');
    return '$t ${level.name.toUpperCase()} [$tag] $message';
  }
}

/// In-app log, readable from Settings > Logs. Release builds print nothing
/// to logcat, so this is the only way to see what went wrong on a device.
/// Kept in memory and mirrored to a small file so it survives restarts.
class AppLog {
  AppLog._();

  static const _maxEntries = 500;
  static final entries = ValueNotifier<List<LogEntry>>(const []);
  static File? _file;

  static Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/app.log');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        // Keep the previous session's tail as plain text.
        final tail = lines.length > _maxEntries ~/ 2
            ? lines.sublist(lines.length - _maxEntries ~/ 2)
            : lines;
        await file.writeAsString(tail.isEmpty ? '' : '${tail.join('\n')}\n');
        entries.value = [
          for (final line in tail)
            LogEntry(DateTime(0), LogLevel.info, 'prev', line),
        ];
      }
      _file = file;
    } catch (_) {
      // Logging must never break the app.
    }
  }

  static void info(String tag, String message) =>
      _add(LogLevel.info, tag, message);

  static void warn(String tag, String message) =>
      _add(LogLevel.warning, tag, message);

  static void error(String tag, Object error, [StackTrace? stack]) => _add(
    LogLevel.error,
    tag,
    stack == null
        ? '$error'
        : '$error\n${stack.toString().split('\n').take(8).join('\n')}',
  );

  static void _add(LogLevel level, String tag, String message) {
    final entry = LogEntry(DateTime.now(), level, tag, message);
    debugPrint(entry.toString());
    final list = [...entries.value, entry];
    entries.value = list.length > _maxEntries
        ? list.sublist(list.length - _maxEntries)
        : list;
    final file = _file;
    if (file != null) {
      unawaited(
        file
            .writeAsString('$entry\n', mode: FileMode.append)
            .then((_) {}, onError: (_) {}),
      );
    }
  }

  static Future<void> clear() async {
    entries.value = const [];
    try {
      await _file?.writeAsString('');
    } catch (_) {}
  }

  static String dump() => entries.value
      .map((e) => e.tag == 'prev' ? e.message : e.toString())
      .join('\n');
}
