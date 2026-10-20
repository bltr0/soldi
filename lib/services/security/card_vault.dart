import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

/// Cards live only in the platform keystore-backed secure storage, never
/// in the database, so they are not part of exports, CSV or Drive backups.
/// The page reading them asks for the owner first (see `confirmIdentity`).
class CardVault {
  const CardVault({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _key = 'card_vault_v1';

  Future<List<StoredCard>> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list)
        StoredCard.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  Future<void> write(List<StoredCard> cards) async {
    if (cards.isEmpty) {
      await _storage.delete(key: _key);
      return;
    }
    await _storage.write(
      key: _key,
      value: jsonEncode([for (final card in cards) card.toJson()]),
    );
  }
}
