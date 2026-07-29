import 'package:flutter/material.dart';
import 'app_state.dart';
import '../services/family_service.dart';
import '../services/auth_service.dart';
import '../screens/main_screen.dart';
import '../screens/login_screen.dart';
import '../screens/existing_or_new_family_screen.dart';
import '../screens/admin_main_screen.dart';

/// Routes a signed-in user to their correct home screen.
///
/// A clean `null` from [myFamilyId] means "valid session, no family yet" and
/// sends the user to the family picker. An *error* (expired/invalid session,
/// RLS denial, network failure) is NOT the same thing — we clear the unusable
/// session and send the user back to login rather than dropping them on the
/// family picker.
Future<void> routeAfterAuth(BuildContext context) async {
  Widget next;
  try {
    try {
      final name = await AuthService().getGreetingName();
      AppState.greetingName.value = name;
      final profile = await AuthService().getProfile();
      AppState.avatarPath.value = profile?['avatar_path'] as String?;
    } catch (_) {
      // Non-fatal — HomeScreen falls back to its own fetch if this is null.
    }

    final role = await AuthService().getUserRole();
    if (role == 'admin') {
      next = const AdminMainScreen();
    } else {
      final familyId = await FamilyService()
          .myFamilyId()
          .timeout(const Duration(seconds: 8));
      next = familyId == null
          ? const ExistingOrNewFamilyScreen()
          : const MainScreen();
    }
  } catch (_) {
    await AuthService().signOut();
    next = const LoginScreen();
  }
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => next),
    (_) => false,
  );
}
