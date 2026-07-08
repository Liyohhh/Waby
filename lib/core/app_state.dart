import 'package:flutter/foundation.dart';

/// Global app state — lightweight ValueNotifiers instead of a full state manager.
/// All listeners rebuild automatically when values change.
class AppState {
  AppState._();

  /// Whether the current user has admin privileges.
  /// Toggled in Settings for demo purposes.
  static final isAdminMode = ValueNotifier<bool>(false);

  /// Prefetched greeting name so HomeScreen renders correctly on first frame.
  static final greetingName = ValueNotifier<String?>(null);
}
