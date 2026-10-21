import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sossoldi/services/security/backup_crypto.dart';

void main() {
  test('sealed data opens only with the passphrase', () async {
    final ring = await KeyRing.create('violet harbour seven');
    final restored = KeyRing.fromJson(
      jsonDecode(jsonEncode(ring.toJson())) as Map<String, dynamic>,
    );
    final sealed = await seal(restored.publicKey, utf8.encode('csv,data'));
    final copy = Sealed.fromJson(
      jsonDecode(jsonEncode(sealed.toJson())) as Map<String, dynamic>,
    );

    final seed = await restored.unlock('violet harbour seven');
    expect(utf8.decode(await openSealed(seed, copy)), 'csv,data');

    expect(
      () => restored.unlock('violet harbour eight'),
      throwsA(isA<WrongPassphrase>()),
    );
  });

  test('rewrap keeps the key pair', () async {
    final ring = await KeyRing.create('first passphrase');
    final sealed = await seal(ring.publicKey, [1, 2, 3]);
    final next = await ring.rewrap('first passphrase', 'second passphrase');
    expect(next.publicKey, ring.publicKey);
    final seed = await next.unlock('second passphrase');
    expect(await openSealed(seed, sealed), [1, 2, 3]);
  });

  test('tampered box is rejected', () async {
    final key = randomBytes(32);
    final box = await aesEncrypt(key, [9, 9, 9]);
    final bad = Box(box.nonce, [...box.cipherText]..[0] ^= 1, box.mac);
    expect(() => aesDecrypt(key, bad), throwsA(isA<WrongPassphrase>()));
  });
}
