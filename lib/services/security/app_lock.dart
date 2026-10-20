import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the app is unlocked when it starts.
enum AppLockMode { none, device, pin, pattern }

/// Stores the lock mode in preferences and the PIN or pattern, salted and
/// hashed, in the platform keystore. The code itself is never stored.
/// Repeated wrong codes lock it out for a growing delay.
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
  static const _failuresKey = 'app_lock_failures';
  static const _lockedUntilKey = 'app_lock_locked_until';

  /// Dots a pattern must join, on a 3×3 grid numbered 0 to 8.
  static const minPatternLength = 4;

  /// Wrong codes allowed before each lockout.
  static const _freeAttempts = 5;

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
    if (mode != AppLockMode.pin && mode != AppLockMode.pattern) {
      await _storage.delete(key: _hashKey);
      await _storage.delete(key: _saltKey);
      await _prefs.remove(_pinLengthKey);
    }
  }

  Future<void> savePin(String pin) async {
    await _saveSecret(pin);
    await _prefs.setInt(_pinLengthKey, pin.length);
    await setMode(AppLockMode.pin);
  }

  Future<void> savePattern(List<int> dots) async {
    await _saveSecret(_patternSecret(dots));
    await _prefs.remove(_pinLengthKey);
    await setMode(AppLockMode.pattern);
  }

  Future<void> _saveSecret(String secret) async {
    final random = Random.secure();
    final salt = base64Encode([
      for (var i = 0; i < 16; i++) random.nextInt(256),
    ]);
    await _storage.write(key: _saltKey, value: salt);
    await _storage.write(key: _hashKey, value: _hash(secret, salt));
  }

  /// False while locked out (see [lockedFor]) or when [pin] is wrong.
  Future<bool> verifyPin(String pin) => _verify(pin);

  Future<bool> verifyPattern(List<int> dots) => _verify(_patternSecret(dots));

  /// Time left before another code may be tried, zero when not locked out.
  Duration get lockedFor {
    final until = _prefs.getInt(_lockedUntilKey);
    if (until == null) return Duration.zero;
    final left = DateTime.fromMillisecondsSinceEpoch(
      until,
    ).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<bool> _verify(String secret) async {
    if (lockedFor > Duration.zero) return false;
    final salt = await _storage.read(key: _saltKey);
    final hash = await _storage.read(key: _hashKey);
    if (salt == null || hash == null) return false;
    if (_hash(secret, salt) == hash) {
      await _prefs.remove(_failuresKey);
      await _prefs.remove(_lockedUntilKey);
      return true;
    }
    final failures = (_prefs.getInt(_failuresKey) ?? 0) + 1;
    await _prefs.setInt(_failuresKey, failures);
    if (failures >= _freeAttempts) {
      // 30 s, then doubling for each further miss, at most 15 minutes.
      final extra = failures - _freeAttempts;
      final seconds = min(30 * (1 << min(extra, 5)), 15 * 60);
      await _prefs.setInt(
        _lockedUntilKey,
        DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch,
      );
    }
    return false;
  }

  static String _patternSecret(List<int> dots) => 'pattern:${dots.join('-')}';

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
