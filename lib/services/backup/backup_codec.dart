import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_log.dart';
import '../security/backup_crypto.dart';
import '../security/card_vault.dart';

/// What the passphrase protects in a backup. Cards are encrypted in both.
enum BackupEncryption {
  /// The whole backup: nothing in it is readable without the passphrase.
  full,

  /// Only the cards; transactions, accounts... stay a readable CSV.
  cardsOnly,
}

const backupEncryptionPref = 'backup_encryption';

BackupEncryption backupEncryptionOf(SharedPreferences prefs) =>
    prefs.getString(backupEncryptionPref) == BackupEncryption.cardsOnly.name
    ? BackupEncryption.cardsOnly
    : BackupEncryption.full;

/// An export ready to write: a plain CSV when no passphrase is set up (so
/// no card can exist), otherwise a JSON envelope.
class EncodedBackup {
  const EncodedBackup(this.content, {required this.encrypted});

  final String content;
  final bool encrypted;

  String get extension => encrypted ? 'json' : 'csv';
  String get mimeType => encrypted ? 'application/json' : 'text/csv';
}

class DecodedBackup {
  const DecodedBackup(this.csv, {this.cards});

  final String csv;

  /// Cards restored into the vault, null when the backup had none.
  final int? cards;
}

/// Wraps database exports with the user's backup key ring (see [KeyRing]).
/// Encoding needs no passphrase, so automatic backups stay encrypted;
/// decoding asks for it.
///
/// ```
/// {"format": "sossoldi-backup", "version": 2, "encryption": "full",
///  "keyring": {...}, "sealedData": {...} | "data": "<csv>",
///  "cards": {"vault": {...}, "sealedKey": {...}}}
/// ```
class BackupCodec {
  const BackupCodec({KeyRingStore? rings, CardVault? vault})
    : _rings = rings ?? const KeyRingStore(),
      _vault = vault ?? const CardVault();

  final KeyRingStore _rings;
  final CardVault _vault;

  static const _format = 'sossoldi-backup';

  Future<EncodedBackup> encode(String csv, BackupEncryption mode) async {
    final ring = await _rings.read();
    if (ring == null) return EncodedBackup(csv, encrypted: false);
    final cards = await _vault.exportBundle();
    final envelope = <String, Object?>{
      'format': _format,
      'version': 2,
      'created': DateTime.now().toUtc().toIso8601String(),
      'encryption': mode.name,
      'keyring': ring.toJson(),
      if (mode == BackupEncryption.full)
        'sealedData': (await seal(ring.publicKey, utf8.encode(csv))).toJson()
      else
        'data': csv,
      'cards': ?cards,
    };
    return EncodedBackup(jsonEncode(envelope), encrypted: true);
  }

  /// Whether [content] is an envelope rather than a plain CSV.
  static bool isEnvelope(String content) {
    final start = content.trimLeft();
    if (!start.startsWith('{')) return false;
    try {
      return (jsonDecode(start) as Map)['format'] == _format;
    } catch (_) {
      return false;
    }
  }

  /// Opens [content] (a plain CSV passes through). [askPassphrase] is
  /// called, again after each wrong answer, when the data or cards are
  /// encrypted; returning null skips the cards of a cards-only backup, or
  /// cancels a fully encrypted one (null result).
  Future<DecodedBackup?> decode(
    String content,
    Future<String?> Function({required bool retry, required bool dataLocked})
    askPassphrase,
  ) async {
    if (!isEnvelope(content)) return DecodedBackup(content);
    final json = jsonDecode(content) as Map<String, dynamic>;
    final ring = KeyRing.fromJson(
      (json['keyring'] as Map).cast<String, dynamic>(),
    );
    final sealedData = json['sealedData'] as Map?;
    final cards = (json['cards'] as Map?)?.cast<String, dynamic>();
    final dataLocked = sealedData != null;
    if (!dataLocked && cards == null) {
      return DecodedBackup(json['data'] as String);
    }

    var retry = false;
    while (true) {
      final passphrase = await askPassphrase(
        retry: retry,
        dataLocked: dataLocked,
      );
      if (passphrase == null) {
        return dataLocked ? null : DecodedBackup(json['data'] as String);
      }
      try {
        final String csv;
        if (dataLocked) {
          final seed = await ring.unlock(passphrase);
          csv = utf8.decode(
            await openSealed(
              seed,
              Sealed.fromJson(sealedData.cast<String, dynamic>()),
            ),
          );
        } else {
          csv = json['data'] as String;
        }
        int? restored;
        if (cards != null) {
          restored = await _vault.importBundle(cards, ring, passphrase);
          AppLog.info('backup', 'Restored $restored cards');
        }
        return DecodedBackup(csv, cards: restored);
      } on WrongPassphrase {
        retry = true;
      }
    }
  }
}
