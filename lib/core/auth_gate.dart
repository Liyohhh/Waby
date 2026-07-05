import 'package:flutter/material.dart';
import '../services/family_service.dart';
import '../screens/main_screen.dart';
import '../screens/existing_or_new_family_screen.dart';

Future<void> routeAfterAuth(BuildContext context) async {
  final familyId = await FamilyService().myFamilyId();
  if (!context.mounted) return;
  final next = familyId == null
      ? const ExistingOrNewFamilyScreen()
      : const MainScreen();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => next), (_) => false);
}
