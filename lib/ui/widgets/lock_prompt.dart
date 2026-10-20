import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../providers/authentication_provider.dart';
import '../../services/app_log.dart';
import '../../services/security/app_lock.dart';
import '../device.dart';
import '../theme/dashboard_visual_theme.dart';
import 'atmospheric_background.dart';
import 'pattern_pad.dart';
import 'pin_pad.dart';

/// Asks for the app's PIN or pattern (whichever [AppLock.mode] is) and calls
/// [onUnlocked] once it is right. With [allowBiometrics], a fingerprint or
/// face unlock is offered too when the phone has one.
class LockPrompt extends ConsumerStatefulWidget {
  const LockPrompt({
    required this.title,
    required this.onUnlocked,
    this.subtitle,
    this.allowBiometrics = false,
    this.biometricReason = 'Unlock Sossoldi',
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onUnlocked;
  final bool allowBiometrics;
  final String biometricReason;

  @override
  ConsumerState<LockPrompt> createState() => _LockPromptState();
}

class _LockPromptState extends ConsumerState<LockPrompt> {
  bool _biometrics = false;

  @override
  void initState() {
    super.initState();
    if (widget.allowBiometrics) {
      hasBiometrics().then((value) {
        if (!mounted || !value) return;
        setState(() => _biometrics = true);
        _useBiometrics();
      });
    }
  }

  Future<void> _useBiometrics() async {
    if (await authenticateBiometric(widget.biometricReason) && mounted) {
      widget.onUnlocked();
    }
  }

  String _lockoutMessage(Duration left) =>
      'Too many tries, wait ${left.inSeconds + 1} s';

  Future<String?> _check(Future<bool> Function(AppLock) verify) async {
    final lock = ref.read(appLockProvider);
    if (lock.lockedFor > Duration.zero) return _lockoutMessage(lock.lockedFor);
    if (await verify(lock)) {
      widget.onUnlocked();
      return null;
    }
    final left = lock.lockedFor;
    return left > Duration.zero ? _lockoutMessage(left) : 'Wrong, try again';
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.read(appLockProvider);
    final pad = lock.mode == AppLockMode.pattern
        ? PatternPad(
            title: widget.title,
            subtitle: widget.subtitle,
            onSubmit: (dots) => _check((l) => l.verifyPattern(dots)),
          )
        : PinPad(
            title: widget.title,
            subtitle: widget.subtitle,
            length: lock.pinLength,
            onSubmit: (pin) => _check((l) => l.verifyPin(pin)),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pad,
        if (_biometrics) ...[
          const SizedBox(height: Sizes.lg),
          TextButton.icon(
            onPressed: _useBiometrics,
            icon: Icon(
              Icons.fingerprint_rounded,
              color: context.dashboardTheme.accent,
            ),
            label: const Text('Use fingerprint or face'),
          ),
        ],
      ],
    );
  }
}

bool get _localAuthSupported =>
    Platform.isAndroid ||
    Platform.isIOS ||
    Platform.isMacOS ||
    Platform.isWindows;

/// Whether a fingerprint or face is enrolled on this device.
Future<bool> hasBiometrics() async {
  if (!_localAuthSupported) return false;
  try {
    final auth = LocalAuthentication();
    return await auth.canCheckBiometrics &&
        (await auth.getAvailableBiometrics()).isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Fingerprint or face only, never the phone's screen lock code.
Future<bool> authenticateBiometric(String reason) async {
  if (!_localAuthSupported) return false;
  try {
    return await LocalAuthentication().authenticate(
      localizedReason: reason,
      biometricOnly: true,
    );
  } catch (e) {
    AppLog.warn('auth', 'Biometric check failed: $e');
    return false;
  }
}

/// Fingerprint, face or the phone's own screen lock.
Future<bool> authenticateDevice(String reason) async {
  if (!_localAuthSupported) return false;
  try {
    final auth = LocalAuthentication();
    return await auth.isDeviceSupported() &&
        await auth.authenticate(localizedReason: reason);
  } catch (e) {
    AppLog.warn('auth', 'Device check failed: $e');
    return false;
  }
}

/// A fresh proof that the owner is holding the phone, asked even if the app
/// is already unlocked: the app's PIN or pattern (or a fingerprint/face
/// instead), or the device unlock when the app uses that. Without any app
/// lock it falls back to the device unlock; false if none is set up.
Future<bool> confirmIdentity(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
}) async {
  final mode = ref.read(appLockModeProvider);
  switch (mode) {
    case AppLockMode.pin || AppLockMode.pattern:
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _ConfirmPage(reason: reason),
        ),
      );
      return ok ?? false;
    case AppLockMode.device || AppLockMode.none:
      return authenticateDevice(reason);
  }
}

class _ConfirmPage extends StatelessWidget {
  const _ConfirmPage({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AtmosphericBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: LockPrompt(
                title: reason,
                subtitle: 'Confirm it is you',
                allowBiometrics: true,
                biometricReason: reason,
                onUnlocked: () => Navigator.pop(context, true),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a new pattern twice. Returns its dots, or null when cancelled.
Future<List<int>?> showPatternSetup(BuildContext context) {
  return Navigator.of(context).push<List<int>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _PatternSetupPage(),
    ),
  );
}

class _PatternSetupPage extends StatefulWidget {
  const _PatternSetupPage();

  @override
  State<_PatternSetupPage> createState() => _PatternSetupPageState();
}

class _PatternSetupPageState extends State<_PatternSetupPage> {
  List<int>? _first;

  @override
  Widget build(BuildContext context) {
    final first = _first;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: first == null
                  ? PatternPad(
                      key: const ValueKey('choose'),
                      title: 'Draw a pattern',
                      subtitle:
                          'Join at least ${AppLock.minPatternLength} dots',
                      onSubmit: (dots) async {
                        setState(() => _first = dots);
                        return null;
                      },
                    )
                  : PatternPad(
                      key: const ValueKey('confirm'),
                      title: 'Draw it again',
                      onSubmit: (dots) async {
                        if (dots.join() != first.join()) {
                          return 'Patterns do not match';
                        }
                        Navigator.pop(context, dots);
                        return null;
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
