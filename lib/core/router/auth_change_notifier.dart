import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that GoRouter uses as [refreshListenable].
///
/// Call [notify] whenever auth state changes (sign-in / sign-out) so the
/// router re-evaluates its redirect guard immediately.
class AuthChangeNotifier extends ChangeNotifier {
  /// Trigger a redirect re-evaluation on all GoRouter instances that hold
  /// a reference to this notifier.
  void notify() => notifyListeners();
}
