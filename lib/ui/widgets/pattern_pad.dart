import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/security/app_lock.dart';
import '../device.dart';
import '../theme/dashboard_visual_theme.dart';

/// A 3×3 grid of dots joined by dragging, like Android's pattern lock. Dots
/// are numbered 0 to 8, row by row; passing over a dot between two picked
/// ones picks it too, as Android does.
class PatternPad extends StatefulWidget {
  const PatternPad({
    required this.title,
    required this.onSubmit,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Returns an error to show and clear the pattern, or null when accepted.
  final Future<String?> Function(List<int> dots) onSubmit;

  @override
  State<PatternPad> createState() => _PatternPadState();
}

class _PatternPadState extends State<PatternPad>
    with SingleTickerProviderStateMixin {
  static const _size = 264.0;
  static const _hitRadius = 34.0;

  final _dots = <int>[];
  Offset? _finger;
  String? _error;
  bool _busy = false;
  bool _wrong = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  static Offset _center(int dot) =>
      Offset((dot % 3 + 0.5) * _size / 3, (dot ~/ 3 + 0.5) * _size / 3);

  int? _hit(Offset position) {
    for (var i = 0; i < 9; i++) {
      if ((position - _center(i)).distance <= _hitRadius) return i;
    }
    return null;
  }

  void _add(int dot) {
    if (_dots.contains(dot)) return;
    if (_dots.isNotEmpty) {
      // Crossing the middle of a row, column or diagonal picks it up.
      final last = _dots.last;
      final (r1, c1, r2, c2) = (last ~/ 3, last % 3, dot ~/ 3, dot % 3);
      if ((r1 + r2).isEven && (c1 + c2).isEven) {
        final middle = (r1 + r2) ~/ 2 * 3 + (c1 + c2) ~/ 2;
        if (!_dots.contains(middle)) _dots.add(middle);
      }
    }
    _dots.add(dot);
    HapticFeedback.selectionClick();
  }

  void _start(Offset position) {
    if (_busy) return;
    setState(() {
      _dots.clear();
      _error = null;
      _wrong = false;
      _finger = position;
      final dot = _hit(position);
      if (dot != null) _add(dot);
    });
  }

  void _move(Offset position) {
    if (_busy) return;
    setState(() {
      _finger = position;
      final dot = _hit(position);
      if (dot != null) _add(dot);
    });
  }

  Future<void> _end() async {
    if (_busy) return;
    setState(() => _finger = null);
    if (_dots.isEmpty) return;
    if (_dots.length < AppLock.minPatternLength) {
      _fail('Join at least ${AppLock.minPatternLength} dots');
      return;
    }
    setState(() => _busy = true);
    final error = await widget.onSubmit(List.of(_dots));
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) _fail(error);
  }

  void _fail(String error) {
    setState(() {
      _error = error;
      _wrong = true;
    });
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _wrong) {
        setState(() {
          _dots.clear();
          _wrong = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final textTheme = Theme.of(context).textTheme;
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
        const SizedBox(height: Sizes.xl),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(12 * (1 - _shake.value) * _wave(_shake.value), 0),
            child: child,
          ),
          child: Semantics(
            label: 'Pattern grid',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _start(d.localPosition),
              onPanUpdate: (d) => _move(d.localPosition),
              onPanEnd: (_) => _end(),
              onPanCancel: _end,
              child: CustomPaint(
                size: const Size.square(_size),
                painter: _PatternPainter(
                  dots: List.of(_dots),
                  finger: _finger,
                  center: _center,
                  idle: visual.textPrimary.withValues(alpha: 0.18),
                  line: _wrong ? visual.negative : visual.accent,
                ),
              ),
            ),
          ),
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

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.dots,
    required this.finger,
    required this.center,
    required this.idle,
    required this.line,
  });

  final List<int> dots;
  final Offset? finger;
  final Offset Function(int) center;
  final Color idle;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = line.withValues(alpha: 0.7)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (dots.isNotEmpty) {
      final path = Path()..moveTo(center(dots.first).dx, center(dots.first).dy);
      for (final dot in dots.skip(1)) {
        path.lineTo(center(dot).dx, center(dot).dy);
      }
      if (finger != null) path.lineTo(finger!.dx, finger!.dy);
      canvas.drawPath(path, stroke);
    }
    for (var i = 0; i < 9; i++) {
      final picked = dots.contains(i);
      if (picked) {
        canvas.drawCircle(
          center(i),
          22,
          Paint()..color = line.withValues(alpha: 0.16),
        );
      }
      canvas.drawCircle(
        center(i),
        picked ? 9 : 7,
        Paint()..color = picked ? line : idle,
      );
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.dots.length != dots.length ||
      old.finger != finger ||
      old.line != line ||
      old.idle != idle;
}
