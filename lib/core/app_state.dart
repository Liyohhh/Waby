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

  /// Prefetched avatar storage path so HomeScreen's header shows the
  /// current photo immediately and updates live after Profile edits.
  static final avatarPath = ValueNotifier<String?>(null);

  /// The current user's active car id. Set whenever the active car
  /// changes (startup "which car" prompt, or the Home selector) so
  /// every screen showing the active car stays in sync.
  static final activeCarId = ValueNotifier<String?>(null);

  /// Which bottom-nav tab MainScreen shows (0=Home, 1=Family,
  /// 2=Settings). External screens (e.g. ProfileScreen after saving)
  /// can set this before popping back to MainScreen to land the user
  /// on a specific tab.
  static final mainTabIndex = ValueNotifier<int>(0);
}
