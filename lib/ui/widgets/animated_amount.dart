import 'package:flutter/material.dart';

import '../extensions.dart';

/// Text that counts toward [value] whenever it changes.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount({
    required this.value,
    this.suffix = '',
    this.code,
    this.style,
    this.maxLines = 1,
    this.duration = const Duration(milliseconds: 420),
    super.key,
  });

  final num value;
  final String suffix;

  /// Currency code, for the right number of decimals.
  final String? code;
  final TextStyle? style;
  final int maxLines;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutExpo,
      builder: (context, current, _) => Text(
        '${current.toCurrency(code)}$suffix',
        maxLines: maxLines,
        style: style,
      ),
    );
  }
}
