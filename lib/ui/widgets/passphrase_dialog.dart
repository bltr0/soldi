import 'package:flutter/material.dart';

import '../../services/security/backup_crypto.dart';
import '../device.dart';
import '../theme/dashboard_visual_theme.dart';

/// Asks for an existing passphrase. Null when cancelled.
Future<String?> askPassphrase(
  BuildContext context, {
  required String title,
  String? message,
  String? error,
  String cancelLabel = 'Cancel',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _AskDialog(title, message, error, cancelLabel),
  );
}

class _AskDialog extends StatefulWidget {
  const _AskDialog(this.title, this.message, this.error, this.cancelLabel);

  final String title;
  final String? message;
  final String? error;
  final String cancelLabel;

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  final _controller = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _controller.clear();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isEmpty) return;
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: Sizes.md),
          ],
          _PassphraseField(
            controller: _controller,
            label: 'Passphrase',
            show: _show,
            onToggle: () => setState(() => _show = !_show),
            autofocus: true,
            onSubmitted: _submit,
            error: widget.error,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(onPressed: _submit, child: const Text('Unlock')),
      ],
    );
  }
}

/// Asks for a new passphrase twice, and the current one first when
/// [askCurrent]. Returns (current, new); null when cancelled.
Future<(String?, String)?> choosePassphrase(
  BuildContext context, {
  bool askCurrent = false,
}) {
  return Navigator.of(context).push<(String?, String)>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ChoosePage(askCurrent: askCurrent),
    ),
  );
}

class _ChoosePage extends StatefulWidget {
  const _ChoosePage({required this.askCurrent});

  final bool askCurrent;

  @override
  State<_ChoosePage> createState() => _ChoosePageState();
}

class _ChoosePageState extends State<_ChoosePage> {
  final _current = TextEditingController();
  final _first = TextEditingController();
  final _second = TextEditingController();
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_current, _first, _second]) {
      c.clear();
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final value = _first.text;
    String? error;
    if (widget.askCurrent && _current.text.isEmpty) {
      error = 'Enter your current passphrase';
    } else if (value.length < KeyRing.minPassphraseLength) {
      error = 'Use at least ${KeyRing.minPassphraseLength} characters';
    } else if (value != _second.text) {
      error = 'The two passphrases differ';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, (widget.askCurrent ? _current.text : null, value));
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.askCurrent ? 'Change passphrase' : 'Backup passphrase',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Sizes.lg),
        children: [
          Text(
            'This passphrase encrypts your backups and is the only way to '
            'restore your cards on another phone. It cannot be recovered: '
            'write it down somewhere safe. A few unrelated words make a '
            'strong one, e.g. "violet harbour seven trumpets".',
            style: textTheme.bodyMedium?.copyWith(color: visual.textSecondary),
          ),
          const SizedBox(height: Sizes.xl),
          if (widget.askCurrent) ...[
            _PassphraseField(
              controller: _current,
              label: 'Current passphrase',
              show: _show,
              onToggle: () => setState(() => _show = !_show),
            ),
            const SizedBox(height: Sizes.md),
          ],
          _PassphraseField(
            controller: _first,
            label: 'New passphrase',
            show: _show,
            onToggle: () => setState(() => _show = !_show),
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: Sizes.xs),
          _Strength(_first.text),
          const SizedBox(height: Sizes.md),
          _PassphraseField(
            controller: _second,
            label: 'Repeat it',
            show: _show,
            onToggle: () => setState(() => _show = !_show),
            onSubmitted: _submit,
          ),
          if (_error != null) ...[
            const SizedBox(height: Sizes.md),
            Text(_error!, style: TextStyle(color: visual.negative)),
          ],
          const SizedBox(height: Sizes.xl),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
    );
  }
}

class _PassphraseField extends StatelessWidget {
  const _PassphraseField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.error,
  });

  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final bool autofocus;
  final VoidCallback? onSubmitted;
  final VoidCallback? onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: !show,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      onSubmitted: (_) => onSubmitted?.call(),
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

/// A rough guide, not a guarantee: length and character variety.
class _Strength extends StatelessWidget {
  const _Strength(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    if (value.isEmpty) return const SizedBox(height: 16);
    final kinds = [
      RegExp('[a-z]'),
      RegExp('[A-Z]'),
      RegExp(r'\d'),
      RegExp(r'[^a-zA-Z\d]'),
    ].where((r) => r.hasMatch(value)).length;
    final words = value.trim().split(RegExp(r'\s+')).length;
    final score = value.length >= 20 || (words >= 4 && value.length >= 16)
        ? 3
        : value.length >= 14 && kinds >= 2
        ? 2
        : value.length >= KeyRing.minPassphraseLength
        ? 1
        : 0;
    final (label, color) = switch (score) {
      3 => ('Strong', visual.positive),
      2 => ('Good', visual.positive),
      1 => ('Weak: longer is better', Colors.orange),
      _ => ('Too short', visual.negative),
    };
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
