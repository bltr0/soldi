import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the app is unlocked when it starts.
enum AppLockMode { none, device, pin }

/// Stores the lock mode in preferences and the PIN, salted and hashed, in
/// the platform keystore. The PIN itself is never stored.
class AppLock {
  AppLock(this._prefs, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _storage;

  static const minPinLength = 4;
  static const maxPinLength = 6;

  static const _modeKey = 'app_lock_mode';
  static const _legacyKey = 'user_requires_authentication';
  static const _pinLengthKey = 'app_lock_pin_length';
  static const _hashKey = 'app_lock_pin_hash';
  static const _saltKey = 'app_lock_pin_salt';
  static const _rounds = 20000;

  AppLockMode get mode {
    final stored = _prefs.getString(_modeKey);
    if (stored != null) {
      return AppLockMode.values.asNameMap()[stored] ?? AppLockMode.none;
    }
    return _prefs.getBool(_legacyKey) == true
        ? AppLockMode.device
        : AppLockMode.none;
  }

  /// Digits in the saved PIN, so the pad can unlock without a confirm tap.
  int? get pinLength => _prefs.getInt(_pinLengthKey);

  Future<void> setMode(AppLockMode mode) async {
    await _prefs.setString(_modeKey, mode.name);
    await _prefs.remove(_legacyKey);
    if (mode != AppLockMode.pin) {
      await _storage.delete(key: _hashKey);
      await _storage.delete(key: _saltKey);
      await _prefs.remove(_pinLengthKey);
    }
  }

  Future<void> savePin(String pin) async {
    final random = Random.secure();
    final salt = base64Encode([
      for (var i = 0; i < 16; i++) random.nextInt(256),
    ]);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(pin, salt));
    await _prefs.setInt(_pinLengthKey, pin.length);
    await setMode(AppLockMode.pin);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final hash = await _storage.read(key: _hashKey);
    if (salt == null || hash == null) return false;
    return _hash(pin, salt) == hash;
  }

  static String _hash(String pin, String salt) {
    List<int> digest = utf8.encode('$salt:$pin');
    for (var i = 0; i < _rounds; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Encode(digest);
  }

  static bool isValidPin(String pin) =>
      pin.length >= minPinLength &&
      pin.length <= maxPinLength &&
      RegExp(r'^\d+$').hasMatch(pin);
}
