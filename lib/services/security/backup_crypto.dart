import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown when a passphrase does not open a key ring or data was tampered
/// with.
class WrongPassphrase implements Exception {
  const WrongPassphrase();

  @override
  String toString() => 'Wrong passphrase';
}

/// AES-256-GCM box, as stored in JSON.
class Box {
  const Box(this.nonce, this.cipherText, this.mac);

  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, String> toJson() => {
    'n': base64Encode(nonce),
    'c': base64Encode(cipherText),
    'm': base64Encode(mac),
  };

  factory Box.fromJson(Map<String, dynamic> json) => Box(
    base64Decode(json['n'] as String),
    base64Decode(json['c'] as String),
    base64Decode(json['m'] as String),
  );
}

final _aes = AesGcm.with256bits();
final _x25519 = X25519();

Future<Box> aesEncrypt(List<int> key, List<int> clear) async {
  final box = await _aes.encrypt(clear, secretKey: SecretKey(key));
  return Box(box.nonce, box.cipherText, box.mac.bytes);
}

/// Throws [WrongPassphrase] when the key is wrong or the box was altered.
Future<List<int>> aesDecrypt(List<int> key, Box box) async {
  try {
    return await _aes.decrypt(
      SecretBox(box.cipherText, nonce: box.nonce, mac: Mac(box.mac)),
      secretKey: SecretKey(key),
    );
  } on SecretBoxAuthenticationError {
    throw const WrongPassphrase();
  }
}

List<int> randomBytes(int length) => SecretKeyData.random(length: length).bytes;

/// Data sealed to a public key: an ephemeral X25519 exchange, HKDF-SHA256
/// and AES-256-GCM. Only the matching private key opens it.
class Sealed {
  const Sealed(this.ephemeralPublic, this.box);

  final List<int> ephemeralPublic;
  final Box box;

  Map<String, Object> toJson() => {
    'e': base64Encode(ephemeralPublic),
    'b': box.toJson(),
  };

  factory Sealed.fromJson(Map<String, dynamic> json) => Sealed(
    base64Decode(json['e'] as String),
    Box.fromJson((json['b'] as Map).cast<String, dynamic>()),
  );
}

Future<List<int>> _sealKey(
  KeyPair ours,
  List<int> theirPublic,
  List<int> ephemeral,
  List<int> recipient,
) async {
  final shared = await _x25519.sharedSecretKey(
    keyPair: ours,
    remotePublicKey: SimplePublicKey(theirPublic, type: KeyPairType.x25519),
  );
  final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: shared,
    nonce: [...ephemeral, ...recipient],
    info: utf8.encode('sossoldi-seal-v1'),
  );
  return key.extractBytes();
}

Future<Sealed> seal(List<int> recipientPublic, List<int> clear) async {
  final ephemeral = await _x25519.newKeyPair();
  final ephemeralPublic = (await ephemeral.extractPublicKey()).bytes;
  final key = await _sealKey(
    ephemeral,
    recipientPublic,
    ephemeralPublic,
    recipientPublic,
  );
  return Sealed(ephemeralPublic, await aesEncrypt(key, clear));
}

Future<List<int>> openSealed(List<int> privateSeed, Sealed sealed) async {
  final pair = await _x25519.newKeyPairFromSeed(privateSeed);
  final public = (await pair.extractPublicKey()).bytes;
  final key = await _sealKey(
    pair,
    sealed.ephemeralPublic,
    sealed.ephemeralPublic,
    public,
  );
  return aesDecrypt(key, sealed.box);
}

/// The backup key pair. The public half encrypts backups and card keys
/// without any secret (so automatic backups need no one present); the
/// private half is kept only encrypted with a key stretched from the user's
/// passphrase by Argon2id, here and inside every encrypted backup.
class KeyRing {
  const KeyRing({
    required this.publicKey,
    required this.salt,
    required this.wrappedPrivate,
    this.memoryKib = defaultMemoryKib,
    this.iterations = defaultIterations,
  });

  final List<int> publicKey;
  final List<int> salt;
  final Box wrappedPrivate;
  final int memoryKib;
  final int iterations;

  // OWASP's minimum for Argon2id: 19 MiB, 2 passes.
  static const defaultMemoryKib = 19456;
  static const defaultIterations = 2;
  static const minPassphraseLength = 10;

  static Future<KeyRing> create(String passphrase) async {
    final pair = await _x25519.newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    final public = (await pair.extractPublicKey()).bytes;
    return _wrap(passphrase, seed, public);
  }

  static Future<KeyRing> _wrap(
    String passphrase,
    List<int> seed,
    List<int> public,
  ) async {
    final salt = randomBytes(16);
    final key = await _stretch(
      passphrase,
      salt,
      defaultMemoryKib,
      defaultIterations,
    );
    return KeyRing(
      publicKey: public,
      salt: salt,
      wrappedPrivate: await aesEncrypt(key, seed),
    );
  }

  /// The private seed; throws [WrongPassphrase].
  Future<List<int>> unlock(String passphrase) async {
    final key = await _stretch(passphrase, salt, memoryKib, iterations);
    return aesDecrypt(key, wrappedPrivate);
  }

  /// Same key pair under a new passphrase; throws [WrongPassphrase].
  Future<KeyRing> rewrap(String oldPassphrase, String newPassphrase) async =>
      _wrap(newPassphrase, await unlock(oldPassphrase), publicKey);

  /// Argon2id in a background isolate: it takes a second or two on a phone.
  static Future<List<int>> _stretch(
    String passphrase,
    List<int> salt,
    int memoryKib,
    int iterations,
  ) => Isolate.run(() async {
    final key = await Argon2id(
      parallelism: 1,
      memory: memoryKib,
      iterations: iterations,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  });

  Map<String, Object> toJson() => {
    'kdf': 'argon2id',
    'mem': memoryKib,
    'it': iterations,
    'salt': base64Encode(salt),
    'pub': base64Encode(publicKey),
    'priv': wrappedPrivate.toJson(),
  };

  factory KeyRing.fromJson(Map<String, dynamic> json) => KeyRing(
    publicKey: base64Decode(json['pub'] as String),
    salt: base64Decode(json['salt'] as String),
    wrappedPrivate: Box.fromJson((json['priv'] as Map).cast<String, dynamic>()),
    memoryKib: json['mem'] as int,
    iterations: json['it'] as int,
  );
}

/// Where the key ring and the backup settings live.
class KeyRingStore {
  const KeyRingStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'backup_keyring_v1';

  Future<KeyRing?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return KeyRing.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> write(KeyRing ring) =>
      _storage.write(key: _key, value: jsonEncode(ring.toJson()));
}
