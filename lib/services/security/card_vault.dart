import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'backup_crypto.dart';
import 'biometric_key.dart';

/// A payment card kept in the vault. There is deliberately no CVV: it is
/// printed to be read, never stored (PCI DSS forbids keeping it).
class StoredCard {
  const StoredCard({
    required this.id,
    required this.label,
    required this.number,
    this.holder = '',
    this.expiry = '',
    this.pin = '',
    this.note = '',
  });

  final String id;
  final String label;
  final String holder;

  /// Digits only.
  final String number;

  /// `MM/YY`, or empty.
  final String expiry;

  /// The card's PIN code, digits only, or empty.
  final String pin;
  final String note;

  String get last4 =>
      number.length <= 4 ? number : number.substring(number.length - 4);

  /// Number in groups of four (Amex: 4-6-5).
  String get formattedNumber => formatCardNumber(number);

  /// `•••• 1234`.
  String get maskedNumber => '•••• $last4';

  CardNetwork get network => CardNetwork.of(number);

  /// Past the end of its expiry month.
  bool get isExpired {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(expiry);
    if (match == null) return false;
    final month = int.parse(match[1]!);
    final year = 2000 + int.parse(match[2]!);
    return DateTime.now().isAfter(DateTime(year, month + 1));
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'holder': holder,
    'number': number,
    'expiry': expiry,
    'pin': pin,
    'note': note,
  };

  factory StoredCard.fromJson(Map<String, Object?> json) => StoredCard(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    holder: json['holder'] as String? ?? '',
    number: json['number'] as String? ?? '',
    expiry: json['expiry'] as String? ?? '',
    pin: json['pin'] as String? ?? '',
    note: json['note'] as String? ?? '',
  );

  static String newId() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 12; i++) random.nextInt(256).toRadixString(16),
    ].join();
  }
}

enum CardNetwork {
  visa('Visa'),
  mastercard('Mastercard'),
  amex('American Express'),
  unionPay('UnionPay'),
  jcb('JCB'),
  discover('Discover'),
  other('Card');

  const CardNetwork(this.label);

  final String label;

  static CardNetwork of(String number) {
    if (number.startsWith('4')) return visa;
    if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(number)) return mastercard;
    if (RegExp(r'^3[47]').hasMatch(number)) return amex;
    if (number.startsWith('62')) return unionPay;
    if (RegExp(r'^35(2[89]|[3-8])').hasMatch(number)) return jcb;
    if (RegExp(r'^(6011|65|64[4-9])').hasMatch(number)) return discover;
    return other;
  }
}

String formatCardNumber(String digits) {
  final groups = CardNetwork.of(digits) == CardNetwork.amex
      ? const [4, 6, 5]
      : const [4, 4, 4, 4, 4];
  final out = <String>[];
  var i = 0;
  for (final size in groups) {
    if (i >= digits.length) break;
    out.add(digits.substring(i, min(i + size, digits.length)));
    i += size;
  }
  if (i < digits.length) out.add(digits.substring(i));
  return out.join(' ');
}

/// Luhn checksum, which every real card number passes.
bool isValidCardNumber(String digits) {
  if (digits.length < 12 || digits.length > 19) return false;
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var d = digits.codeUnitAt(digits.length - 1 - i) - 48;
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

/// Cards encrypted on the phone and in backups.
///
/// A random vault key encrypts the cards (AES-256-GCM). That key is itself
/// kept twice: wrapped by an Android Keystore key that only a fingerprint
/// or face unlocks (this phone only), and sealed to the backup key ring,
/// whose private half only the user's passphrase opens. Backups carry the
/// encrypted cards and the sealed key, so a new phone restores them with
/// the passphrase. Nothing on the phone can read cards without one of the
/// two.
class CardVault {
  const CardVault({FlutterSecureStorage? storage, KeyRingStore? rings})
    : _storage = storage ?? const FlutterSecureStorage(),
      _rings = rings ?? const KeyRingStore();

  final FlutterSecureStorage _storage;
  final KeyRingStore _rings;

  static const _legacyKey = 'card_vault_v1';
  static const _cardsKey = 'card_vault_v2';
  static const _sealedKey = 'card_vault_v2_sealed';
  static const _bioKey = 'card_vault_v2_bio';

  /// A passphrase was set, so the vault can hold cards.
  Future<bool> get isSetUp async => await _rings.read() != null;

  /// Fingerprint/face unlock is enrolled for the current vault key.
  Future<bool> get hasBiometricUnlock async =>
      await _storage.read(key: _bioKey) != null;

  /// Creates the key ring and an empty vault, moving any cards saved by the
  /// earlier, unencrypted build into it.
  Future<CardVaultSession> setUp(String passphrase) async {
    final ring = await KeyRing.create(passphrase);
    await _rings.write(ring);
    final vaultKey = randomBytes(32);
    await _storage.write(
      key: _sealedKey,
      value: jsonEncode((await seal(ring.publicKey, vaultKey)).toJson()),
    );
    await _storage.delete(key: _bioKey);
    final session = CardVaultSession._(this, vaultKey, await _readLegacy());
    await session.save(session.cards);
    await _storage.delete(key: _legacyKey);
    return session;
  }

  Future<CardVaultSession> unlockWithBiometrics(String reason) async {
    final raw = await _storage.read(key: _bioKey);
    if (raw == null) {
      throw const BiometricException(BiometricError.invalidated);
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    try {
      final vaultKey = await BiometricKey.decrypt(
        base64Decode(json['iv'] as String),
        base64Decode(json['ct'] as String),
        reason: reason,
      );
      return await _open(vaultKey);
    } on BiometricException catch (e) {
      if (e.error == BiometricError.invalidated) {
        await _storage.delete(key: _bioKey);
      }
      rethrow;
    }
  }

  /// Throws [WrongPassphrase].
  Future<CardVaultSession> unlockWithPassphrase(String passphrase) async {
    final ring = await _rings.read();
    if (ring == null) throw const WrongPassphrase();
    final seed = await ring.unlock(passphrase);
    final sealed = await _storage.read(key: _sealedKey);
    if (sealed == null) throw const WrongPassphrase();
    final vaultKey = await openSealed(
      seed,
      Sealed.fromJson(jsonDecode(sealed) as Map<String, dynamic>),
    );
    return _open(vaultKey);
  }

  Future<CardVaultSession> _open(List<int> vaultKey) async {
    final raw = await _storage.read(key: _cardsKey);
    if (raw == null) return CardVaultSession._(this, vaultKey, const []);
    final clear = await aesDecrypt(
      vaultKey,
      Box.fromJson(jsonDecode(raw) as Map<String, dynamic>),
    );
    final list = jsonDecode(utf8.decode(clear)) as List<dynamic>;
    return CardVaultSession._(this, vaultKey, [
      for (final item in list)
        StoredCard.fromJson((item as Map).cast<String, Object?>()),
    ]);
  }

  Future<List<StoredCard>> _readLegacy() async {
    final raw = await _storage.read(key: _legacyKey);
    if (raw == null || raw.isEmpty) return const [];
    return [
      for (final item in jsonDecode(raw) as List<dynamic>)
        StoredCard.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  /// Same key pair under a new passphrase; throws [WrongPassphrase]. Older
  /// backups still open with the passphrase they were made with.
  Future<void> changePassphrase(String current, String next) async {
    final ring = await _rings.read();
    if (ring == null) throw const WrongPassphrase();
    await _rings.write(await ring.rewrap(current, next));
  }

  /// For a forgotten passphrase: a new key ring, the open vault's key
  /// sealed to it. Backups made before only open with the old passphrase.
  Future<void> replacePassphrase(
    CardVaultSession session,
    String passphrase,
  ) async {
    final ring = await KeyRing.create(passphrase);
    await _rings.write(ring);
    await _storage.write(
      key: _sealedKey,
      value: jsonEncode((await seal(ring.publicKey, session._key)).toJson()),
    );
  }

  /// What backups carry: still encrypted, readable only with the
  /// passphrase. Null when there is no card.
  Future<Map<String, Object?>?> exportBundle() async {
    final cards = await _storage.read(key: _cardsKey);
    final sealed = await _storage.read(key: _sealedKey);
    if (cards == null || sealed == null) return null;
    return {'vault': jsonDecode(cards), 'sealedKey': jsonDecode(sealed)};
  }

  /// Replaces the vault with the cards of a backup made under [ring],
  /// opened with [passphrase]. Throws [WrongPassphrase]. Returns how many
  /// cards came back.
  Future<int> importBundle(
    Map<String, dynamic> bundle,
    KeyRing ring,
    String passphrase,
  ) async {
    final seed = await ring.unlock(passphrase);
    final sealed = Sealed.fromJson(
      (bundle['sealedKey'] as Map).cast<String, dynamic>(),
    );
    final vaultKey = await openSealed(seed, sealed);
    final vault = Box.fromJson(
      (bundle['vault'] as Map).cast<String, dynamic>(),
    );
    // Proves the key and cards match before anything is replaced.
    final count =
        (jsonDecode(utf8.decode(await aesDecrypt(vaultKey, vault)))
                as List<dynamic>)
            .length;

    var local = await _rings.read();
    if (local == null) {
      // A new phone: the backup's passphrase becomes this phone's.
      await _rings.write(ring);
      local = ring;
    }
    await _storage.write(key: _cardsKey, value: jsonEncode(vault.toJson()));
    await _storage.write(
      key: _sealedKey,
      value: jsonEncode((await seal(local.publicKey, vaultKey)).toJson()),
    );
    // The fingerprint copy held the replaced key.
    await _storage.delete(key: _bioKey);
    await BiometricKey.reset();
    return count;
  }
}

/// An unlocked vault: the cards and their key, kept only in memory while
/// the vault page is open.
class CardVaultSession {
  CardVaultSession._(this._vault, List<int> key, List<StoredCard> cards)
    : _key = List.of(key),
      cards = List.unmodifiable(cards);

  final CardVault _vault;
  final List<int> _key;
  List<StoredCard> cards;

  Future<void> save(List<StoredCard> next) async {
    final box = await aesEncrypt(
      _key,
      utf8.encode(jsonEncode([for (final c in next) c.toJson()])),
    );
    await _vault._storage.write(
      key: CardVault._cardsKey,
      value: jsonEncode(box.toJson()),
    );
    cards = List.unmodifiable(next);
  }

  /// Wraps the key for fingerprint/face unlock; asks for one now.
  Future<void> enrollBiometrics(String reason) async {
    final wrapped = await BiometricKey.encrypt(_key, reason: reason);
    await _vault._storage.write(
      key: CardVault._bioKey,
      value: jsonEncode({
        'iv': base64Encode(wrapped.iv),
        'ct': base64Encode(wrapped.ct),
      }),
    );
  }

  /// Forgets the key and cards.
  void close() {
    _key.fillRange(0, _key.length, 0);
    cards = const [];
  }
}
