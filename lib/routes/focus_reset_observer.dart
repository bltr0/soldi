import 'package:flutter/widgets.dart';

/// Drops text focus from the route being covered when a new route opens.
///
/// A route remembers its focused field and focuses it again when it is shown
/// back. Without this, closing a page or sheet reopened the keyboard on the
/// dashboard for a field the user had left (for example after hiding the
/// keyboard with the system back button). Pages that want the keyboard, such
/// as a new transaction, use autofocus, which runs after this.
class FocusResetObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
  }
}
