import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';

class BlurWidget extends ConsumerStatefulWidget {
  const BlurWidget({
    required this.child,
    this.ignore = false,
    this.always = false,
    this.replacement,
    this.sigma = 14,
    super.key,
  });

  final bool ignore;

  /// Stays blurred even when amounts are shown.
  final bool always;
  final Widget child;
  final Widget? replacement;
  final double sigma;

  @override
  ConsumerState<BlurWidget> createState() => _BlurWidgetState();
}

class _BlurWidgetState extends ConsumerState<BlurWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.always || !ref.read(visibilityAmountProvider) ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant BlurWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.always != widget.always) {
      _controller.value = widget.always || !ref.read(visibilityAmountProvider)
          ? 1
          : 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ignore) return widget.child;

    ref.listen<bool>(visibilityAmountProvider, (_, visible) {
      final target = visible && !widget.always ? 0.0 : 1.0;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = target;
      } else {
        _controller.animateTo(target, curve: Curves.easeInOutCubic);
      }
    });

    if (widget.replacement != null &&
        (widget.always || !ref.watch(visibilityAmountProvider))) {
      return Semantics(
        label: 'Financial value hidden',
        child: ExcludeSemantics(child: widget.replacement!),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final hidden = t > 0.5;
        Widget content = widget.child;
        if (t > 0) {
          content = ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: widget.sigma * t,
                sigmaY: widget.sigma * t,
                tileMode: TileMode.decal,
              ),
              child: widget.child,
            ),
          );
        }

        return Semantics(
          label: hidden ? 'Financial value hidden' : null,
          excludeSemantics: hidden,
          child: IgnorePointer(ignoring: hidden, child: content),
        );
      },
    );
  }
}
