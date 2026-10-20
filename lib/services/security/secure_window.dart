import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Android-only protections for screens showing secrets; no-ops elsewhere.
class SecureWindow {
  SecureWindow._();

  static const _channel = MethodChannel('sossoldi/security');
  static Timer? _clipboardTimer;

  /// Hides the app from screenshots, recordings and the recents preview.
  static Future<void> setSecure(bool secure) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setSecure', secure);
    } catch (_) {}
  }

  /// Copies [text] flagged as sensitive and wipes the clipboard after
  /// [clearAfter].
  static Future<void> copySecret(
    String text, {
    Duration clearAfter = const Duration(seconds: 30),
  }) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('copySensitive', text);
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: text));
      }
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(clearAfter, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text != text) return;
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('clearClipboard');
          return;
        } catch (_) {}
      }
      await Clipboard.setData(const ClipboardData(text: ''));
    });
  }
}
