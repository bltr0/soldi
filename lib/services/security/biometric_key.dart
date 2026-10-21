import 'dart:io';

import 'package:flutter/services.dart';

enum BiometricStatus { ok, none, unavailable }

/// Why a fingerprint/face check gave no key.
enum BiometricError { cancelled, invalidated, failed, unavailable }

class BiometricException implements Exception {
  const BiometricException(this.error, [this.message]);

  final BiometricError error;
  final String? message;

  @override
  String toString() => 'Biometric ${error.name}: ${message ?? ''}';
}

/// Encrypts small secrets with an Android Keystore key that only a strong
/// fingerprint/face check unlocks (see BiometricVault.kt). The key cannot
/// leave the phone and is destroyed when a new fingerprint/face is added.
class BiometricKey {
  BiometricKey._();

  static const _channel = MethodChannel('sossoldi/security');

  static Future<BiometricStatus> status() async {
    if (!Platform.isAndroid) return BiometricStatus.unavailable;
    try {
      return switch (await _channel.invokeMethod<String>('bioStatus')) {
        'ok' => BiometricStatus.ok,
        'none' => BiometricStatus.none,
        _ => BiometricStatus.unavailable,
      };
    } catch (_) {
      return BiometricStatus.unavailable;
    }
  }

  /// Returns the IV and cipher text; asks for a fingerprint/face.
  static Future<({Uint8List iv, Uint8List ct})> encrypt(
    List<int> data, {
    required String reason,
  }) async {
    final result = await _call('bioEncrypt', {
      'data': Uint8List.fromList(data),
      'reason': reason,
    });
    final map = (result as Map).cast<String, Object?>();
    return (iv: map['iv'] as Uint8List, ct: map['ct'] as Uint8List);
  }

  static Future<Uint8List> decrypt(
    List<int> iv,
    List<int> ct, {
    required String reason,
  }) async =>
      await _call('bioDecrypt', {
            'iv': Uint8List.fromList(iv),
            'ct': Uint8List.fromList(ct),
            'reason': reason,
          })
          as Uint8List;

  static Future<void> reset() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('bioReset');
    } catch (_) {}
  }

  static Future<Object?> _call(String method, Map<String, Object> args) async {
    if (!Platform.isAndroid) {
      throw const BiometricException(BiometricError.unavailable);
    }
    try {
      return await _channel.invokeMethod(method, args);
    } on PlatformException catch (e) {
      throw BiometricException(switch (e.code) {
        'cancelled' => BiometricError.cancelled,
        'invalidated' => BiometricError.invalidated,
        _ => BiometricError.failed,
      }, e.message);
    }
  }
}
