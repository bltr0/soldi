import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/authentication_provider.dart';
import '../../services/security/app_lock.dart';
import '../device.dart';
import '../theme/dashboard_visual_theme.dart';
import 'atmospheric_background.dart';

/// Dots and a digit keypad. With [length] the code is submitted as soon as
/// that many digits are typed; otherwise a confirm key appears once the
/// code is long enough.
class PinPad extends StatefulWidget {
  const PinPad({
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.length,
    super.key,
  });

  final String title;
  final String? subtitle;
  final int? length;

  /// Returns an error to show and clear the code, or null when accepted.
  final Future<String?> Function(String pin) onSubmit;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _busy = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  int get _maxLength => widget.length ?? AppLock.maxPinLength;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await widget.onSubmit(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error != null) {
        _error = error;
        _pin = '';
      }
    });
    if (error != null) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
    }
  }

  void _type(String digit) {
    if (_busy || _pin.length >= _maxLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (widget.length != null && _pin.length == widget.length) _submit();
  }

  void _erase() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
    final canConfirm =
        widget.length == null && _pin.length >= AppLock.minPinLength;

    Widget key(Widget child, VoidCallback? onTap, {String? label}) => Semantics(
      button: true,
      label: label,
      child: Material(
        color: onTap == null
            ? Colors.transparent
            : visual.textPrimary.withValues(alpha: 0.06),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 72, height: 72, child: Center(child: child)),
        ),
      ),
    );

    final digitStyle = textTheme.headlineSmall?.copyWith(
      color: visual.textPrimary,
      fontWeight: FontWeight.w700,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_rounded, size: 36, color: visual.accent),
        const SizedBox(height: Sizes.md),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            color: visual.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Sizes.xs),
        SizedBox(
          height: 20,
          child: Text(
            _error ?? widget.subtitle ?? '',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: _error != null ? visual.negative : visual.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: Sizes.lg),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(12 * (1 - _shake.value) * _wave(_shake.value), 0),
            child: child,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < (widget.length ?? AppLock.maxPinLength); i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? visual.accent
                        : visual.textPrimary.withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Sizes.xl),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Sizes.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Sizes.lg,
              children: [
                for (final digit in row)
                  key(Text(digit, style: digitStyle), () => _type(digit)),
              ],
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Sizes.lg,
          children: [
            key(
              Icon(Icons.check_rounded, color: visual.accent),
              canConfirm ? _submit : null,
              label: 'Confirm',
            ).withOpacity(canConfirm ? 1 : 0),
            key(Text('0', style: digitStyle), () => _type('0')),
            key(
              Icon(Icons.backspace_outlined, color: visual.textSecondary),
              _pin.isEmpty ? null : _erase,
              label: 'Erase',
            ),
          ],
        ),
      ],
    );
  }

  static double _wave(double t) {
    const cycles = 3;
    final x = (t * cycles * 2) % 2;
    return x < 1 ? x * 2 - 1 : 3 - x * 2;
  }
}

extension on Widget {
  Widget withOpacity(double opacity) => IgnorePointer(
    ignoring: opacity == 0,
    child: AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 160),
      child: this,
    ),
  );
}

/// Shows [child] once the PIN is entered, when the app is locked by PIN.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  late bool _unlocked = ref.read(appLockModeProvider) != AppLockMode.pin;

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    final lock = ref.read(appLockProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AtmosphericBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: PinPad(
                title: 'Enter your PIN',
                length: lock.pinLength,
                onSubmit: (pin) async {
                  if (await lock.verifyPin(pin)) {
                    setState(() => _unlocked = true);
                    return null;
                  }
                  return 'Wrong PIN';
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a new PIN twice. Returns it, or null when cancelled.
Future<String?> showPinSetup(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _PinSetupPage(),
    ),
  );
}

class _PinSetupPage extends StatefulWidget {
  const _PinSetupPage();

  @override
  State<_PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<_PinSetupPage> {
  String? _first;

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
                  ? PinPad(
                      key: const ValueKey('choose'),
                      title: 'Choose a PIN',
                      subtitle:
                          '${AppLock.minPinLength} to ${AppLock.maxPinLength} digits',
                      onSubmit: (pin) async {
                        if (!AppLock.isValidPin(pin)) {
                          return 'Use ${AppLock.minPinLength} to ${AppLock.maxPinLength} digits';
                        }
                        setState(() => _first = pin);
                        return null;
                      },
                    )
                  : PinPad(
                      key: const ValueKey('confirm'),
                      title: 'Confirm your PIN',
                      length: first.length,
                      onSubmit: (pin) async {
                        if (pin != first) return 'PINs do not match';
                        Navigator.pop(context, pin);
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
