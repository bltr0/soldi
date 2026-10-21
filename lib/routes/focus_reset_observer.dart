import 'dart:async';

import 'package:flutter/widgets.dart';

/// Keeps the keyboard from opening by itself when routes change.
///
/// A route remembers every field focused on it and focuses the last one
/// again when it is shown back, and unfocusing a field only removes that
/// one from the memory: closing a sheet reopened the amount keypad on the
/// new transaction page, for instance. So focus is dropped when a route
/// opens, and again once a closed route has finished animating out. Code
/// that wants a keyboard after a sheet (the transaction entry sequence)
/// waits for [settled] and asks for focus itself.
class FocusResetObserver extends NavigatorObserver {
  static Completer<void>? _settling;

  /// Completes once the last closed route is gone and focus was dropped.
  static Future<void> get settled => _settling?.future ?? Future.value();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dropWhenGone(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _dropWhenGone(route);

  void _dropWhenGone(Route<dynamic> route) {
    final settling = _settling = Completer<void>();
    void drop() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusManager.instance.primaryFocus?.unfocus();
        if (!settling.isCompleted) settling.complete();
      });
    }

    final animation = route is TransitionRoute ? route.animation : null;
    if (animation == null || animation.isDismissed) {
      drop();
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      animation.removeStatusListener(onStatus);
      drop();
    }

    animation.addStatusListener(onStatus);
    // In case the route is disposed before reporting dismissal.
    Timer(const Duration(milliseconds: 600), () {
      try {
        animation.removeStatusListener(onStatus);
      } catch (_) {}
      if (!settling.isCompleted) drop();
    });
  }
}
