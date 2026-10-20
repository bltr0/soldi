import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/app_log.dart';
import '../../../ui/device.dart';
import '../../../ui/theme/dashboard_visual_theme.dart';

/// Shows the in-app log (see [AppLog]), newest first.
class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: AppLog.dump()));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Logs copied')));
              }
            },
          ),
          const IconButton(
            tooltip: 'Clear',
            icon: Icon(Icons.delete_outline_rounded),
            onPressed: AppLog.clear,
          ),
        ],
      ),
      body: ValueListenableBuilder<List<LogEntry>>(
        valueListenable: AppLog.entries,
        builder: (context, entries, _) {
          if (entries.isEmpty) {
            return Center(
              child: Text(
                'Nothing logged yet',
                style: TextStyle(color: visual.textSecondary),
              ),
            );
          }
          final reversed = entries.reversed.toList();
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
              Sizes.lg,
              Sizes.md,
              Sizes.lg,
              MediaQuery.paddingOf(context).bottom + Sizes.xl,
            ),
            itemCount: reversed.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = reversed[i];
              final color = switch (e.level) {
                LogLevel.error => Colors.redAccent,
                LogLevel.warning => Colors.orange,
                LogLevel.info => visual.textPrimary,
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SelectableText(
                  e.tag == 'prev' ? e.message : e.toString(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: e.tag == 'prev' ? visual.textSecondary : color,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
