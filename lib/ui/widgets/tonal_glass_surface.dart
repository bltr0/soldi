import 'package:flutter/material.dart';

import '../theme/dashboard_visual_theme.dart';

enum GlassTone { panel, hero, chrome }

/// Frosted panel painted with a translucent fill and a top highlight.
///
/// The highlight is a gradient, not a live blur, so scrolling does not
/// re-sample the backdrop on every frame.
class TonalGlassSurface extends StatelessWidget {
  const TonalGlassSurface({
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.radius = 24,
    this.tone = GlassTone.panel,
    this.color,
    this.gradient,
    this.borderColor,
    this.boxShadow,
    this.semanticLabel,
    this.pressScale = 0.985,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final GlassTone tone;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final String? semanticLabel;

  /// Scale applied while the surface is pressed. Use 1 to disable.
  final double pressScale;

  @override
  Widget build(BuildContext context) {
    final visual = context.dashboardTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);
    final fill = gradient ?? _fill(visual, isDark);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: fill == null ? _baseColor(visual, isDark) : null,
        gradient: fill,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? _border(visual, isDark)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: _sheen(isDark)),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                Widget body = Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                );
                if (onTap != null) {
                  body = InkWell(
                    onTap: onTap,
                    borderRadius: borderRadius,
                    child: body,
                  );
                }
                // A tight parent (an account tile) sizes the glass to the
                // box, while the ink used to hug the text. Fill the box.
                if (!constraints.hasBoundedWidth ||
                    !constraints.hasBoundedHeight) {
                  return body;
                }
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: body,
                );
              },
            ),
          ),
        ],
      ),
    );

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: visual.shadow.withValues(alpha: visual.shadow.a * 0.45),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: content),
    );

    if (onTap != null && pressScale != 1) {
      surface = _PressScale(scale: pressScale, child: surface);
    }

    if (semanticLabel != null) {
      surface = Semantics(
        container: true,
        label: semanticLabel,
        button: onTap != null,
        child: surface,
      );
    }

    return RepaintBoundary(
      child: Padding(padding: margin ?? EdgeInsets.zero, child: surface),
    );
  }

  Gradient? _fill(DashboardVisualTheme visual, bool isDark) {
    if (tone != GlassTone.hero) return null;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(
          Colors.white.withValues(alpha: isDark ? 0.06 : 0.28),
          visual.heroStart,
        ),
        visual.heroEnd,
      ],
    );
  }

  Color _baseColor(DashboardVisualTheme visual, bool isDark) {
    if (color != null) return color!;
    if (tone == GlassTone.chrome) {
      // Controls sit over scrolling content. A live blur would hide that
      // content, but it also repaints on every frame, so the bar stays
      // opaque and the glass read comes from the highlight and the edge.
      return Color.alphaBlend(
        Colors.white.withValues(alpha: isDark ? 0.06 : 0.2),
        isDark ? visual.solidSurface : visual.navigationFill,
      );
    }
    final frost = isDark
        ? visual.solidSurface.withValues(alpha: 0.74)
        : visual.glassFill;
    return Color.alphaBlend(
      Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
      frost,
    );
  }

  Color _border(DashboardVisualTheme visual, bool isDark) {
    if (tone == GlassTone.hero) {
      return Colors.white.withValues(alpha: isDark ? 0.20 : 0.72);
    }
    return visual.glassBorder;
  }

  double _sheen(bool isDark) => switch (tone) {
    GlassTone.hero => isDark ? 0.16 : 0.42,
    GlassTone.chrome => isDark ? 0.10 : 0.34,
    GlassTone.panel => isDark ? 0.12 : 0.36,
  };
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: Duration(milliseconds: _pressed ? 80 : 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
