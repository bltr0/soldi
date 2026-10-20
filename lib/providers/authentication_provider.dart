import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/security/app_lock.dart';
import 'settings_provider.dart';

final appLockProvider = Provider<AppLock>(
  (ref) => AppLock(ref.watch(sharedPrefProvider)),
);

class AppLockModeNotifier extends Notifier<AppLockMode> {
  @override
  AppLockMode build() => ref.watch(appLockProvider).mode;

  Future<void> set(AppLockMode mode) async {
    await ref.read(appLockProvider).setMode(mode);
    state = mode;
  }

  Future<void> setPin(String pin) async {
    await ref.read(appLockProvider).savePin(pin);
    state = AppLockMode.pin;
  }

  Future<void> setPattern(List<int> dots) async {
    await ref.read(appLockProvider).savePattern(dots);
    state = AppLockMode.pattern;
  }
}

final appLockModeProvider = NotifierProvider<AppLockModeNotifier, AppLockMode>(
  AppLockModeNotifier.new,
);
