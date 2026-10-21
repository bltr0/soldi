import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_provider.dart';
import '../../../services/app_log.dart';
import '../../../services/backup/backup_codec.dart';
import '../../../services/security/backup_crypto.dart';
import '../../../services/security/biometric_key.dart';
import '../../../services/security/card_vault.dart';
import '../../../ui/device.dart';
import '../../../ui/snack_bars/snack_bar.dart';
import '../../../ui/widgets/passphrase_dialog.dart';
import '../../../ui/widgets/segmented_pill.dart';
import '../../../ui/widgets/settings_tiles.dart';

/// Backup passphrase and what it encrypts.
class BackupEncryptionSection extends ConsumerStatefulWidget {
  const BackupEncryptionSection({super.key});

  @override
  ConsumerState<BackupEncryptionSection> createState() =>
      _BackupEncryptionSectionState();
}

class _BackupEncryptionSectionState
    extends ConsumerState<BackupEncryptionSection> {
  final _vault = const CardVault();
  bool? _setUp;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final setUp = await _vault.isSetUp;
    if (mounted) setState(() => _setUp = setUp);
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showSnackBar(context, message: label);
    } on WrongPassphrase {
      if (mounted) showSnackBar(context, message: 'Wrong current passphrase');
    } catch (e, stack) {
      AppLog.error('backup', 'Passphrase change failed: $e', stack);
      if (mounted) showSnackBar(context, message: 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  Future<void> _create() async {
    final chosen = await choosePassphrase(context);
    if (chosen == null) return;
    await _run('Backups are now encrypted', () async {
      final session = await _vault.setUp(chosen.$2);
      session.close();
    });
  }

  Future<void> _change() async {
    final chosen = await choosePassphrase(context, askCurrent: true);
    if (chosen == null) return;
    await _run(
      'Passphrase changed',
      () => _vault.changePassphrase(chosen.$1!, chosen.$2),
    );
  }

  /// A new key ring, reachable only by unlocking the cards with a
  /// fingerprint: the passphrase is the other way in.
  Future<void> _forgot() async {
    if (!await _vault.hasBiometricUnlock ||
        await BiometricKey.status() != BiometricStatus.ok) {
      if (mounted) {
        showSnackBar(
          context,
          message:
              'Without the passphrase or a fingerprint enrolled in Cards, '
              'the cards cannot be recovered',
        );
      }
      return;
    }
    final CardVaultSession session;
    try {
      session = await _vault.unlockWithBiometrics('Reset backup passphrase');
    } on BiometricException {
      return;
    }
    if (!mounted) return session.close();
    final chosen = await choosePassphrase(context);
    if (chosen == null) return session.close();
    await _run('New passphrase set', () async {
      await _vault.replacePassphrase(session, chosen.$2);
      session.close();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(sharedPrefProvider);
    final mode = backupEncryptionOf(prefs);
    final setUp = _setUp;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sizes.lg, Sizes.xxl, Sizes.lg, 0),
      child: SettingsGroup(
        title: 'Encryption',
        footer: setUp == true
            ? 'Encryption runs on this phone before anything is saved or '
                  'uploaded, automatic backups included. Restoring asks for '
                  'the passphrase. Older backups open with the passphrase '
                  'they were made with.'
            : 'Needed to keep cards. Without it, exports are a plain CSV.',
        children: [
          if (setUp == null)
            const SettingsTile(title: 'Loading…')
          else if (!setUp)
            SettingsTile(
              icon: Icons.key_rounded,
              title: 'Set a backup passphrase',
              subtitle: 'Encrypts backups and lets cards move to a new phone',
              onTap: _busy ? null : _create,
            )
          else ...[
            SettingsTile(
              icon: Icons.enhanced_encryption_rounded,
              title: 'Encrypt',
              subtitle: switch (mode) {
                BackupEncryption.full =>
                  'The whole backup: unreadable without the passphrase',
                BackupEncryption.cardsOnly =>
                  'Cards only: the rest stays a readable CSV',
              },
              below: SegmentedPill<BackupEncryption>(
                options: const {
                  BackupEncryption.full: 'Whole backup',
                  BackupEncryption.cardsOnly: 'Cards only',
                },
                selected: mode,
                onChanged: (value) async {
                  await prefs.setString(backupEncryptionPref, value.name);
                  setState(() {});
                },
              ),
            ),
            SettingsTile(
              icon: Icons.password_rounded,
              title: 'Change passphrase',
              onTap: _busy ? null : _change,
            ),
            SettingsTile(
              icon: Icons.help_outline_rounded,
              title: 'Forgot passphrase',
              subtitle: 'Set a new one with your fingerprint',
              onTap: _busy ? null : _forgot,
            ),
          ],
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
